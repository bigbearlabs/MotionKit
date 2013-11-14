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

# BUG wrong result when no network connection.
def network_connection?( timeout = 3 )
	test_uri = "http://www.w3c.org"

	group = Dispatch::Group.new
	
	@network_test_result = nil

	Dispatch::Queue.main.async(group) do
		begin
			@network_test_result = Net::HTTP.get_response URI(test_uri)
		rescue Exception => e
			pe_log "#{e} while testing network"
		end
	end
	
	group.wait timeout

	@network_test_result != nil
end



class NSObject
	include LoggerMixin
end


class Class
	def name
		super ? super : self.ancestors[1].name
	end
end

class NSObject
	alias_method :desc, :description

	def to_s
	#   if ! self.class.name
			class_name = self.class.name
			return "#{class_name}:#{self.object_id}>"
	#   else
	#     super
	#   end
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
			String.new(self).to_base_url
	end

	def is_valid_url?
		String.new(self).is_valid_url?
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
	
end
	
class NSDictionary

	def self.dictionary_from( path_string )
		path_string = NSApp.app_support_dir + "/" + path_string
		if File.exist? path_string
			instance = YAML::load_file path_string
		end

		instance ? instance : {}
	end

	def save_to( path_string )
		path_string = NSApp.app_support_dir + "/" + path_string
		File.open(path_string, "w") do |file|
			bytes = file.write self.to_yaml

			pe_log "#{self.object_id} saved to #{path_string}: #{bytes} bytes"

			return bytes
		end
	rescue Exception => e
		pe_report e, "saving to #{path_string}"
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
		if subdirectory
			self.URLForResource(resource_name, withExtension:nil, subdirectory:subdirectory, localization:nil)
		else
			self.URLForResource(resource_name, withExtension:nil)
		end
	end
	
	def content( resource_name, subdirectory = nil )
		file_path = "#{NSBundle.mainBundle.resourcePath}#{subdirectory ? '/' + subdirectory : ''}/#{resource_name}"
		content = File.open(file_path).read
	end
	
	def dictionary_from_plist( plist_name, subdirectory = nil )
		NSDictionary.alloc.initWithContentsOfURL(self.url("#{plist_name}.plist", subdirectory))
	end
end

def load_plist( url_string )
	NSDictionary.alloc.initWithContentsOfURL( url_string.to_url )
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
      pe_log "#{self}: interval reached, yielding to block"
      action.call
    }

    timer = self.scheduledTimerWithTimeInterval(interval, target:action_holder, selector: 'perform_proc', userInfo:nil, repeats:false)

    NSRunLoop.currentRunLoop.addTimer(timer, forMode:NSDefaultRunLoopMode)

    timer
  end
end


