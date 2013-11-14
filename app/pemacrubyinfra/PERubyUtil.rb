#
#  PERubyUtil.rb
#  MyMacRubyProject
#
#  Created by Park Andy on 20/09/2011.
#  Copyright 2011 Park Enterprise. All rights reserved.
#

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

def try( &stuff )
  begin
    yield
  rescue Exception => e
    pe_report e, "while trying #{stuff}"
    e
  end
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

class String

  def starts_with?(prefix)
    prefix = prefix.to_s
    self[0, prefix.length] == prefix
  end

  def is_single_word?
    self =~ /[ \.\/]/ ? false : true
  end

#= url

  # deal with trailing spaces etc.
  def matches_url?(url)
    # just remove trailing slashes and compare.
    self.gsub(/\/+$/,'') == url.gsub(/\/+$/,'')
  end
  
  def to_url_string # PROTO
    if self[0] == '/'
      "file://#{self}"
    elsif self =~ %r{(http|https|file)://}
      self
    else
      "http://#{self}"
    end
  end
  
  def to_base_url
    uri = URI(self)
    "#{uri.scheme}://#{uri.host}"
  end

#= hacks

  def to_search_url_string
    "http://google.com/search?q=#{CGI.escape(self)}"
  end
  
end


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
class Hash
  # @return a new hash with values defined in priority_hash replaced.
  # for an entry that is itself a hash, assume keys in original entry but not in priority entry are new entries rather than deletions.
  def overwritten_hash( priority_hash )
    overwritten_hash = {}
    
    self.each_pair do |k, v|
      if v.is_a? Hash
        new_val = v.overwritten_hash( priority_hash[k] )
      else
        if priority_hash.has_key?(k)
          pe_log "overwriting #{k} with value from priority hash"
          new_val = priority_hash[k]
        else
          new_val = v
        end
      end
      
      overwritten_hash[k] = new_val
    end
    
    overwritten_hash
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
  def flattened_keys(options = {})
    output = {}

    self.each do |key, value|
      key = options[:prefix].nil? ? "#{key}" :
        "#{options[:prefix]}#{options[:delimiter]||"_"}#{key}"
      if value.is_a? Hash
        value = Hash[value.to_a].flattened_keys(:prefix => key, :delimiter => ".")
        value.each do |inner_k, inner_v|
          output[inner_k] = inner_v
        end
      else
        output[key] = value
      end
    end

    output
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
  
  def initialize(name, &proc)
    super(&proc)
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
  if condition
    time = Benchmark.measure {
  		yield
  	}
    puts "##trace_time #{description} took #{time}"
  else
    yield
  end
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
