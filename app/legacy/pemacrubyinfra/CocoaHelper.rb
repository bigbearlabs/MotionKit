##
#  CocoaHelper.rb
#  MyMacRubyProject
#
#  Created by Park Andy on 31/08/2011.
#  Copyright 2011 Park Enterprise. All rights reserved.
#

# REFACTOR rename to foundation_additions.rb

### MOTION-MIGRATION
# ## benchmark framework load time.
# def macruby_framework(*args)
# 	trace_time "framework #{args}" do
# 		framework(*args)
# 	end
# end

# macruby_framework 'Foundation'
### END-MOTION-MIGRATION


# environment variables, analogous to ruby ENV.
def env
  NSProcessInfo.processInfo.environment
end


# DEPRECATED prefer FilesystemAccess
def write_file path, content
  # make the dir if necessary.
  dir = File.dirname path
  unless File.exist? dir
    pe_log "making dir #{dir}"
    # FileUtils.mkdir_p dir   
    Dir.mkdir dir  # FIXME do an mkdir -p equivalent
  end

  # write the file.
  File.open(path, "w") do |file|
    bytes = file.write content

    pe_log "#{self.object_id} saved to #{path}: #{bytes} bytes"

    return bytes
  end
rescue Exception => e
  pe_report e, "saving to #{path}"
end



def network_connection?( timeout = 2 )
  result = nil
  begin
  	test_file = nil
    quickly_connect = -> {
      test_file = Net::HTTP.get_response URI("http://www.w3c.org/")
    }

		group = Dispatch::Group.new
		Dispatch::Queue.concurrent.async(group) do
			begin
	      quickly_connect.call
		 	rescue Exception
		 	end
    end

		group.wait timeout

    result = (test_file != nil)
  rescue Exception => e
  	pe_debug "exception: #{e}"
    result = false
  end

  pe_debug "network connectivity: #{result}"
  result
end


# class NSObject
# 	include LoggerMixin
# end


class Class
	def name
		name = super ? super : self.ancestors[1].name
    case name
    when /^NSKVONotifying_(.*)/
      name = $1
    else
      name
    end
	end
end

class NSObject
	alias_method :desc, :description

	def to_s
    debug caller if self.is_a? NSError

    if ! self.class.name
			class_name = self.class.name
			"<#{class_name}:#{self.object_id}>"
	  else
	    super
	  end
	end
	
	def invoke_setter(property_name, value)
		kvo_change property_name do
			begin
				self.send "#{property_name}=", value
			rescue Exception => e
				pe_report e, "failed to set #{property_name} to #{value} on #{self}"
			end
		end
	end

	def all_methods
		methods(true, true)
	end

end


class NSString
	
	def to_url
		# NOTE we need to first check if string needs encoding. if string alrady percent-escape encoded, we shouldn't encode again.
		# test with non-en languages and sites to determine whether redundant.
		# encoded_str = self.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
		encoded_str = self
		url = (
			if encoded_str.starts_with? '~'
				NSURL.fileURLWithPath( self.stringByExpandingTildeInPath )
			elsif encoded_str.starts_with? '/'
				NSURL.fileURLWithPath encoded_str
			else
				NSURL.URLWithString encoded_str
			end
		)

		pe_debug  "#{url.description}, #{url.class}"
		
		return url
	end  

	#= wrappers

	def to_url_string
		String.new(self).to_url_string
	end

	def to_base_url
		url = NSURL.URLWithString(self)
    "#{url.scheme}://#{url.host}"
	end

	def valid_url?
		String.new(self).valid_url?
	end

	def to_search_url_string
		String.new(self).to_search_url_string
	end

	def matches_url?(url)
		String.new(self).matches_url?(url)
	end

	def starts_with?( str )
		String.new(self).starts_with? str
	end
	
end


class NSArray
	
	def to_index_set
		index_set = NSMutableIndexSet.indexSet
		self.each do |e|
			index_set.addIndex(e)
		end
		NSIndexSet.alloc.initWithIndexSet(index_set)
	end
	
	def for_range( range )
		puts "range: #{range.description}"
		range ?
			self.subarrayWithRange( range ) :
			self
	rescue Exception => e
		pe_report e, "array: #{self}, range: #{range.description}"
		[]
	end

	def for_predicate( predicate )
		predicate.nil? ?
			self :
			self.filteredArrayUsingPredicate( predicate )
	end
end
	
class NSDictionary

	def self.dictionary_from( path_string )
		path_string = NSApp.app_support_dir + "/" + path_string
		if File.size? path_string
      content = File.open(path_string).read

      # TODO test if yaml file.
			instance = YAML::load content
		end

		instance ? instance : {}
	end

	def save_to( path_string )
		path_string = NSApp.app_support_dir + "/" + path_string
    content = self.to_yaml
    
    write_file path_string, content
  end

end

#=

#= quick and dirty inspection of generic data structures.
class NSDictionary
	
	def inspect_class
		pair_descriptions = []
		self.each do |k,v|
			if v.kind_of?(NSDictionary) || v.kind_of?(NSArray)
				val_description = v.inspect_class
			else
				val_description = v.class.name
			end

			pair_descriptions << "#{k.class.name} : #{val_description}"
		end

		pair_descriptions
	end
end

class NSArray
	def inspect_class
		element_descriptions = []
		self.each do |e|
			if e.kind_of?(NSDictionary) || e.kind_of?(NSArray)
				val_description = e.inspect_class
			else
				val_description = e.class.name
			end

			element_descriptions << "#{val_description}"
		end

		element_descriptions
	end
end


# backtrace formatting.
class NSArray
	def format_backtrace
		self.collect do |trace_line|
			trace_line.gsub(/^(.*?)(?=\w+\.rb)/, '')
		end
	end
end

#=

class NSData
	def self.data_from_file( file_path )
		return dataWithContentsOfFile( file_path )
	end
end


class NSBundle
	def url( resource_name, subdirectory = nil)
		url = 
      if subdirectory
  			self.URLForResource(resource_name, withExtension:nil, subdirectory:subdirectory, localization:nil)
  		else
  			self.URLForResource(resource_name, withExtension:nil)
  		end

    raise "no resource #{subdirectory.to_s.empty? ? '' : subdirectory + '/'}#{resource_name} in #{path}" if url.nil?

    url
	end
	
	def path
		self.resourcePath
	end

	#=

  # REDUNDANT FilesystemAccess#load
	def content( resource_name, subdirectory = nil )
		file_path = "#{self.path}#{subdirectory ? '/' + subdirectory : ''}/#{resource_name}"
		begin
			content = File.open(file_path).read
			content
		rescue
			pe_warn "failed to load #{file_path}"
		end
	end
	
	# REDUNDANT use Object#load_plist instead.
	def dictionary_from_plist( plist_name )
		pe_debug "plist_name: #{plist_name}"

		dir, filename = plist_name.gsub(/\/(\w+(\.\w+)?)$/, ''), $1.to_s
		pe_debug "dir, filename: #{dir}, #{filename}"
		path = self.pathForResource(filename.gsub(/\.plist$/, ''), ofType:"plist", inDirectory:dir)
		raise "invalid plist path #{path}" if ! path or path.empty?

		pe_debug "make dictionary from #{path}"
		NSDictionary.dictionaryWithContentsOfFile(path)
	end
end

class IntegerToIndexes < NSValueTransformer
	def transformedValue(val)
		return val ? NSIndexSet.indexSetWithIndex(val) : NSIndexSet.indexSetWithIndex(0)
	end
	
	def reverseTransformedValue(val)
		return val ? val.firstIndex : 0
	end
end


# methods which really should be under Hash, but here to work around class anomaly when NSDictionary made from url.
class NSDictionary

	def overwritten_hash( priority_hash = {} )
		hash = {}
		
		self.each do |k, v|
			# do we have a competing entry?
			if priority_hash.key? k
				val = priority_hash[k]

				# should we recursively process?
				if v.is_a? NSDictionary
					val = v.overwritten_hash val
				end
				
			else
				val = v
			end

			# insert the entry.
			hash[k] = val
		end
		
		hash
	end


	def deep_mutable_copy
		instance = NSMutableDictionary.new
		
		self.each do |k,v|
			case v
			when NSDictionary
				new_v = v.deep_mutable_copy
			when Array
				new_v = NSMutableArray.arrayWithArray(v)
			else
				new_v = v
			end
			
			instance[k] = v
		end
		
		instance
	end
	
end


class NSTimer
  def self.new_timer( interval, &action )
    action_holder = ProcRunner.new -> {
      pe_debug "#{self}: interval reached, yielding to block"
      action.call
    }

    timer = self.scheduledTimerWithTimeInterval(interval, target:action_holder, selector: 'perform_proc', userInfo:nil, repeats:false)

    NSRunLoop.currentRunLoop.addTimer(timer, forMode:NSDefaultRunLoopMode)

    timer
  end
end


#= NSPredicate

# FIXME rename / relocate.
def and_predicates(formatted_str, words)
	predicates = words.collect do |word|
		new_predicate formatted_str, word
	end
	NSCompoundPredicate.andPredicateWithSubpredicates(predicates)
end

def new_predicate formatted_str, word
	NSPredicate.predicateWithFormat(formatted_str, word)
end

class NSPredicate
  
  def self.widening_predicates( array_controller, chunk_size = 30, another_predicate = nil)

    ## NOTE as this requires the filter to be present in order to test for membership in the slice, it needs to be instantiated every time the collection mutates. 
    filtered_objects = array_controller.unfiltered_objects.for_predicate another_predicate

    slices = filtered_objects.each_slice(chunk_size).to_a
    
    if slices.empty?
      pe_log "no widening predicates created for #{another_predicate.description} - just returning the original predicate."
        
      return [ another_predicate ]
    end

    selection = []
    slices.map do |slice|
      selection.concat slice

      # a limited predicate includes the object if it's in the slice.
      my_selection = selection.dup
      limited_predicate = NSPredicate.predicateWithBlock(
        -> evaluatedObject, bindings {
          my_selection.include? evaluatedObject
          })
    end
    
  end

  # returns a predicate that matches the first n sorted elements of the array controller.
  def self.limit_predicate array_controller, limit, another_predicate = nil
  	puts "creating predicate with limit #{limit}"
    NSPredicate.predicateWithBlock(
      -> evaluatedObject, bindings {
        unfiltered_objects = array_controller.unfiltered_objects
        if another_predicate
        	unfiltered_objects = unfiltered_objects.for_predicate another_predicate
        end

        index = unfiltered_objects.index(evaluatedObject)

        puts "#{self} limit: #{limit}, index: #{index}"
        index.to_i < limit
      }
    )
  end


  def new_and predicate
    predicate.nil? ?
      self :
      NSCompoundPredicate.andPredicateWithSubpredicates( [ self, predicate ] )
  end

  def new_or predicate
    predicate.nil? ?
      self :
      NSCompoundPredicate.orPredicateWithSubpredicates( [ self, predicate ] )
  end

end
