
# TODO should live outside PEMacRubyInfra.

# require 'cgi'
# require 'uri'
# require 'timeout'
# require 'open-uri'

#== simple test class for experiments
# 
$a = [ 'a', 'b', 1 ]
$h = { a: 1, b: 2, c: { aa: 4, bb: 5 } }

class C
  def m1
    puts 'hi'
  end
  def m2(*args)
    puts "args: #{args}"
  end
end


#==  idioms

def try( attempts = 1, &stuff )
  result = nil
  attempts.times do |i|
    begin
      result = yield

      break
    rescue Exception => e
      if i < attempts
        pe_report e, "attempt #{i+1} failed for #{stuff}; retrying"
      else
        pe_report e, "#{stuff} failed #{attempts} attempts"
        result = e
      end
    end
  end

  result
end

class Class
  # allow methods to be defined from externally.
  def def_method( method_name, &def_block )
    self.send :define_method, method_name, def_block
  end
end


class Object

  def ivar( name )
    instance_variable_get "@#{name}"
  end

  # http://robots.thoughtbot.com/post/159806033/irb-script-console-tips
  # Easily print methods local to an object's class
  def local_methods
    (methods - Object.instance_methods).sort
  end
  
  def def_method_once( method_name, &def_block )
    p = -> {
      unless self.local_methods.include? method_name
        self.define_singleton_method method_name, def_block
      end
    }
    
    self.instance_exec( &p )
  end

end


def dump_attrs( obj,  *attr_names )
	attr_names.collect do |attr|
		val = obj.send(attr)
		"#{attr}: #{val}"
	end
end


#= debug

# grab an object with its id; in MacRuby this can either be the ruby object id or the decimal / hex pointer address to the object that you can easily find with NSLog / puts.
def o( id )
  ObjectSpace._id2ref id
end


# grab instances of a particular class
# e.g. i(MyClass)
def i( klass )
  instances = ObjectSpace.each_object(klass).to_a
  instances.length > 1 ? instances : instances.first
end


#=

class MessageSyncWrapper < BasicObject
    
  # Create Proxy to wrap the given +delegate+,
  # optionally specify +group+ and +queue+ for asynchronous callbacks
  def initialize(delegate)
    super()
    @delegate = delegate
    @mutex ||= ::Mutex.new
  end

  # Call methods on the +delegate+ object via a private serial queue
  # Returns asychronously if given a block; else synchronously
  #
  def method_missing(symbol, *args, &block)
    begin
      @mutex.synchronize {
        result = @delegate.send(symbol, *args, &block)
        return result
      }
    end
  end
end


#=

module StringUtil

  def starts_with?(prefix)
    prefix = prefix.to_s
    self[0, prefix.length] == prefix
  end

  def single_word?
    self =~ /[ \.\/]/ ? false : true
  end

#= url

  # deal with trailing spaces etc.
  def match_url?(url)
    # just remove trailing slashes and compare.
    self.gsub(/\/+$/,'') == url.gsub(/\/+$/,'')
  end
  
  def to_url_string # PROTO
    if self[0] == '/'
      "file://#{self.escaped(:simple)}"
    elsif self =~ %r{^(http|https|file)://}
      # FIXME probably has some edge cases
      self
    else
      "http://#{self.escaped}"
    end
  end
  
  # MOTION-MIGRATION
  # def to_base_url
  #   uri = URI(self)
  #   "#{uri.scheme}://#{uri.host}"
  # end

#= hacks

  def to_search_url_string
    "http://google.com/search?q=#{self.escaped}"
  end
  
  def escaped( escape_style = :all )
    case escape_style
    when :simple
      return self.gsub ' ', '%20'
    else
      # CGI.escape self TODO encode only the param string.
      if self.index '?'
        pre_params, param_str = self.split('?', 2)
        return pre_params + "?" + CGI.escape(param_str)
      else
        self
      end
    end
  end
end

class String; include StringUtil; end


class Array
	def summary
		if self.count > 0
			return "#{self.count} items [0:#{self[0]}, #{self.count-1}:#{self[-1]}]"
		else
			return "empty."
		end
	end
  
	def slice_after_position
		self.slice! [@position+1, self.length-1].min..-1 if @position
	end

#= diff / sync

  # generates a spec of added and deleted items.
  # change_spec keys: added, removed, moved
  def diff( array )
    spec = { removed: [], added: [], moved: [] }
    
    self.each_with_index do |element, i|

      if ! array.include? element
        # the element's deleted.
        spec[:removed] << { obj: element, position: i }
      else
        # the element's around. check if the location is the same
        if element == array[i]
          # this is just in place - don't need to mention in spec.
        else
          # this has moved - record
          spec[:moved] << { obj: element, position: array.index(element) }
        end
      end
    end

    # work out the added ones by array - self.
    added = array - self
    added.each_with_index do |element, i|
      spec[:added] << { obj: element, position: array.index(element) }
    end

    return spec
  end 

  
  # TODO consider making immutable.
  def sync_to( array )
    change_spec = self.diff(array)
    
    change_spec[:removed].each do |deleted_spec|
      self.delete_at deleted_spec[:position]
    end
    
    change_spec[:added].each do |added_spec|
      self.insert(added_spec[:position], added_spec[:obj])
    end

    # TODO processed the moved elements.
    # need to think about equality / identity guarantees here.
    
    self
  end
  
end

# ?? can't get this work with the defaults loaded from the cocoa api. clobbering in CocoaHelper.
module HashUtil

  def delete_value( val )
    self.keys.each do |key|
      if self[key] == val
        pe_log "deleting value #{val} from hash #{self.object_id}"
        self.delete key
      end
    end
  end

  # @return a new hash with values in priority_hash overwriting existing values.
  # note that entries in original hash which are mssing in priority do not mean they should be removed, i.e. changes will never 'narrow' the keyset.
  def overwritten_hash( priority_hash )
    raise "nil priority hash" if priority_hash.nil?

    overwritten_hash = {}
    
    self.map do |k, v|
      if priority_hash.has_key? k
        priority_val = priority_hash[k]
        case priority_val
        when Hash
          if v.is_a? Hash
            new_val = v.overwritten_hash priority_val
          else
            # for some reason v is not a hash. assume priority hash has corrupted value.
            new_val = v
          end
        else
          new_val = priority_val
        end
      else
        # key not found in priority val: just use old val.
        new_val = v
      end

      # put in a decent effort to isolate.
      case new_val
      when Array, Hash, String
        new_val = new_val.dup
      end

      overwritten_hash[k] = new_val
    end
    
    # insert new keys
    new_keys = priority_hash.keys - self.keys
    new_keys.map do |key|
      val = priority_hash[key]
      overwritten_hash[key] = val
    end

    overwritten_hash
  end
  
  # create a hash representing the delta between self and hash2.
  # ignores keys in self and absent in hash2. (narrowing hash change)
  # if new_keys:true, includes keys absent in self and present in hash2. (widening hash change)
  # array values are deemed different unless equal; i.e. doesn't look inside arrays.
  def diff_hash(hash2, options = {})
    hash1 = self.dup
    diff = hash1.keys.inject({}) do |acc, key|
      val1 = hash1[key]
      val2 = hash2[key]

      if val1.is_a? Hash
        val2 = Hash[val1].diff_hash Hash[val2.to_a], options
      end

      unless val2.nil? or val2 == val1 or (val2.is_a? Hash and val2.empty?)
        acc[key] = val2
      end

      acc
    end

    if options[:new_keys]
      new_keys = hash2.keys - hash1.keys
      new_keys.map do |new_key|
        diff[new_key] = hash2[new_key]
      end
    end

    diff
  end
  

  # returns a new hash with the keys stringified.
  def to_stringified
    self.inject({}) do |acc, e|
      k, v = e

      if v.is_a? Hash
        v = Hash[v.to_a].to_stringified
      end

      acc[k.to_s] = v

      acc
    end
  end

  # http://www.ruby-forum.com/topic/205691
  def flattened_hash(options = {})
    output = {}

    self.each do |key, value|
      key = options[:prefix].nil? ? "#{key}" :
        "#{options[:prefix]}#{options[:delimiter]||"_"}#{key}"
      if value.is_a? Hash
        value = Hash[value.to_a].flattened_hash(:prefix => key, :delimiter => ".")
        value.each do |inner_k, inner_v|
          output[inner_k] = inner_v
        end
      else
        output[key] = value
      end
    end

    output
  end

  # note: symbol keys will be coerced to strings.
  def unflattened_hash( delim = '.' )
    new_hash = {}

    self.each do |key, val|
      segments = key.split delim

      # create a generic structure as necessary
      last_hash = new_hash
      segments[0..-2].each do |segment|
        last_hash[segment] ||= {}
        last_hash = last_hash[segment]
      end

      # set the leaf value
      last_hash[segments.last] = val
    end
    
    new_hash
  end
  
end


# kvc-like object path handling.
module PathRetrieval
  def get_path( path )
    path_segments = path.split '.'
    
    current = self
    path_segments.each do |segment|
      return nil if ! current
      current = current.fetch( current.class == Array ? segment.to_i : segment )
    end
    
    current
  end
end
class Hash
	include PathRetrieval
end
class Array
	include PathRetrieval
end



class NamedProc < Proc
  attr_accessor :name
  
  def initialize(name, &p)
    super(&p)
    self.name = name.to_s
  end
  
  def to_s
    super + "(#{self.name})"
  end
end


class Time
	def seconds_since_now 
		Time.new - self
	end
end


# profiling
# require 'benchmark'
def trace_time( description = 'anonymous block', condition = $DEBUG )
  # MOTION-MIGRATION
  # if condition
  #   time = Benchmark.measure {
  # 		yield
  # 	}
  #   puts "##trace_time #{description} took #{time}"
  # else
    yield
  # end
end


#= network

# NOTE this deadlocks when used in macruby.
def network_connection?( timeout = 2 )
  result = nil
  begin
    test_file = nil
    Timeout::timeout(timeout) do
      test_file = open("http://www.w3c.org/")
    end

    result = test_file != nil
  rescue Exception 
    result = false
  end

  pe_debug "network connectivity: #{result}"
  result
end

def is_reachable_host?( host )
  system "ping -t 1 -c 1 #{host}"
  $?.exitstatus == 0
end



class DotNavigableHash < Hash
  # @source http://stackoverflow.com/questions/2240535/ruby-hash-keys-as-methods-on-a-class
  # keys should be symbols.
  def method_missing(name, *args, &blk)
    if args.empty? && blk.nil? && self.has_key?(name)
      self[name]
    else
      super
    end
  end
end


# create instances, with a prototype, and messages will be forwarded if not handled by this class.
class ObjectWithPrototype

  def initialize( prototype )
    super
    @prototype = prototype
  end

  def method_missing(name, *args, &block)
    if @prototype.respond_to? name
      @prototype.send(name, *args, &block)
    else
      super
    end
  end

  def respond_to?( msg )
    super || (@prototype.respond_to? msg)
  end

end


module IvarInjection
  def inject_collaborators collaborators
    collaborators.map do |var_name, obj|
      raise "nil obj for #{var_name}" unless obj
      instance_variable_set :"@#{var_name}", obj
      pe_log "#{self}: injected #{obj} as #{var_name}"
    end
  end
end
