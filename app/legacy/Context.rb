# require 'PERubyUtil'
# require 'KVOMixin'

# require 'monitor'

# FIXME revive 'items' prop (array)
class Context
  include KVOMixin

  attr_accessor :name
  
  attr_reader :history_items
  attr_reader :current_history_item

  attr_accessor :filter_tag # for array controller filtering

  def initialize( name = "Unnamed context #{self.name_suffix_sequence}", history_items = [])
    super

    @name = name

    @history_items = history_items

    @sites ||= {}
  end

#==
  
  def add_access( url, details = {} )  # rename
    raise "nil url!" if url.nil?

    
    # assert this item not loaded.
    if self.item_for_url url
      pe_warn "add requested for an already known item #{url}. investigate"
    end
    
    pe_log "add new history item for #{url}"
    
    item_container = ItemContainer.from_hash( { 
      'url' => url,
      'title' => url,
      'pinned' => false,
      'timestamp' => NSDate.date,
    })
    item_container.filter_tag = item_container.timestamp

    self.add_item item_container

    self.update_detail url, details

    # self.handle_pinning item_container
    
    pe_debug "context.current_item: #{self.current_history_item.description}"
  end
  
  def update_access( url )
    pe_debug "update_access: #{caller}"

    item = item_for_url url
    item.last_accessed_timestamp = NSDate.date
    item.filter_tag = item.timestamp

    self.update_current_history_item item
  end
  
  def update_detail( url, details )
    pe_debug "detail update requested for #{url}"
    
    # set details on the item.
    history_item = self.item_for_url url
    
    # NOTE this seems to happen with shortened url's involving client redirects.
    # https://www.evernote.com/shard/s5/sh/aa05b207-8c98-4b9a-9a7d-9fd5d1d121fe/94d032b0b430fe228820e7347be974a8
    # for now, be a bit generous and watch what happens.
    if history_item.nil?
      pe_warn "#{url} not found on #update_detail."

      # add the access first and check again.
      self.add_access url, details
      history_item = self.item_for_url url
      if history_item.nil?
        raise "#{url} not found in history after falling back and adding to history."
      end
    end
    
    details.each do |k,v|
      history_item.invoke_setter k, v

      # additional actions      
      if k == :thumbnail
        # mark for saving
        history_item.thumbnail_dirty = true
      end
    end
  end
  
  def update_history_item( url, history_item )
    item_container = self.item_for_url url
    unless item_container.history_item.object_id == history_item.object_id
      pe_warn "replacing #{item_container.history_item} with #{history_item}"
      item_container.history_item = history_item
    end
  end
  
  def add_redirect( url, redirect_info )
    item = self.item_for_url(url)
    if ! item.nil?
      item.add_redirect redirect_info
    else
      raise "no item for #{url} **TRACE**  #{caller}"
      
    end
  end
  
#==

  def history_contains_url( url )
    ! self.item_for_url(url).nil?
  end
  
  def current_url_match?( url )
    self.current_history_item && self.current_history_item.matches_url?( url )
  end


  def item_for_url( url )
    items = self.history_items.select do |item|
      item.matches_url? url
    end
    
    case items.count
    when 0 then return nil
    when 1 then return items[0]
    else
      pe_warn "multiple items match #{url} - investigate."
      # items[0..-2].each do |item|
      #   self.remove_history_item item
      # end
      return items[0]
    end
  end  

  ##

  def history_count
    self.history_items.size
  end


  def add_item( history_item )
    if ! history_item
      raise "history_item shouldn't be nil"
    end

    kvo_change_bindable :history_items do
      @history_items << history_item
      self.update_current_history_item
    end
  end
  
  def remove_history_item( history_item )
    kvo_change_bindable :history_items do
      index = @history_items.index(history_item)
      @history_items.delete_at index
    end
  end

  def back_item
    current_item_index = self.index_of_item(@current_history_item)
    if current_item_index && current_item_index > 0
      self.history_items[current_item_index - 1]
    else
      nil
    end
  end

  def forward_item
    current_item_index = self.index_of_item(@current_history_item)
    if current_item_index && current_item_index <= self.history_count - 1
      self.history_items[current_item_index + 1]
    else
      nil
    end
  end

  ##

  def history_data
    items_data = self.history_items.map do |item|
      pe_log "item is nil at index #{i} - what's going on?" unless item

      item.to_hash.dup
    end
    
    pe_debug "history_data for #{self} - #{items_data.count} items"
    items_data
  end

  def history_links
    self.history_items.map do |item|
      item.url
    end
  end
  
  def load_items(items_to_load )
    items_to_load.each do |item|
      self.add_item item
    end

    pe_log "loaded #{items_to_load.count} items to context '#{self.name}'."
  end
  
#= sites

  attr_reader :sites

  def add_site( site )
    self.kvo_change :sites do
      @sites[site.base_url] = site
    
      pe_log "added site: #{site}"
    end
    
    # CASE site already defined
  end
  
  def remove_site( site )
    self.kvo_change :sites do
      @sites.delete site.base_url
      pe_log "removed site: #{site}"
    end
  end

  def update_current_site( site_name, site_base_url, site_search_url )
    @sites[site_base_url] = nil
    self.add_site Site.new(site_name, site_base_url, site_search_url)
  end
  
  def site_for( history_item_or_url )
    case history_item_or_url
    when String
      url = history_item_or_url
    else
      url = history_item_or_url.url
    end
    
    site = @sites[url.to_base_url]
  end
 
  def site_for_base_url( base_url)
    @sites[base_url]
  end
  
  def current_site
    return nil if ! self.current_history_item
    self.site_for self.current_history_item
  end
  
  def current_site_defined
    self.current_site != nil
  end
  
  def new_site
    history_item = self.current_history_item
    site = Site.new(history_item.title, history_item.url.to_base_url, '')
    
    self.add_site site
    
    site
  end
  

  def site_data
    self.sites.values.collect do |site|
      site.to_hash
    end
  end

  def load_sites(sites_data)
    if sites_data
      sites_data.each do |site_data|
        site = Site.from_hash(site_data)
        self.add_site site
      end
    end

  end
  
  def add( url )
    item = self.item_for_url url
    if ! item
      pe_log "nil item for #{url}, creating a provisional item"
      self.add_access url, provisional: true
      item = self.item_for_url url
    end

    add_item item
  end


#==
    
  def name_suffix_sequence
    @sequence ||= 0
    @sequence += 1
  end

#==
  
  # REFACTOR generalise hash serialisation from object attributes.
  def to_hash
    { 
      'name' => self.name, 
      'items' => self.history_items.map(&:to_hash), 
      'sites' => self.site_data,
    }
  end

#==

  def last_accessed_timestamp
    ts = self.history_items.map(&:last_accessed_timestamp).max
    ts or NilTime
  end


  protected

    attr_writer :current_history_item

    def update_current_history_item( history_item = self.history_items.last )
      kvo_change_bindable :current_history_item do
        @current_history_item = history_item
      end
    end
    
end

# FIXME attrs such as url, title aren't kvo-compliant when decorated like this!
# RENAME Page
# SPLIT domain & integration layers
class ItemContainer
  include KVOMixin
  
  attr_accessor :history_item
  
  # other properties
  attr_accessor :thumbnail
  attr_accessor :pinned
  attr_accessor :enquiry
  attr_accessor :timestamp  # first encountered
  attr_accessor :pinned_timestamp
  attr_accessor :last_accessed_timestamp
  
  attr_accessor :redirect_info
  
  attr_accessor :filter_tag
  
  attr_accessor :thumbnail_dirty    # TACTICAL mark a thumbnail as needing to save.
  
  attr_accessor :provisional  # is true if the page hasn't really 'loaded' in domain terms

  def initialize( history_item )
    super()

    # observe_kvo self, :history_item do |obj, change, ctx|
  #     self.title = self.history_item.title
      
  #     new_url = self.history_item.URLString
  #     if ! new_url || new_url.empty?
  #       pe_warn "#{self} has invalid url"
  #     else
  #       pe_debug "history item for #{self} changed"
  #       self.url = new_url
    # end
    
    self.history_item = history_item
  end
  
#=
  
  def matches_url?( url )
    if ! self.url
      # raise "#{self} has a nil url - we must find out why"
      pe_warn "#{self} has a nil url - we must find out why"
      
      return false
    end
    
    url = url.to_s
    
    return self.url.matches_url?(url) || self.originalURLString.matches_url?(url) || ( @redirect_info && @redirect_info.compact.select{|e| e[0].matches_url?(url) }.count > 0 )
  end

  def add_redirect( redirect_info )
    kvo_change :redirect_info do
      @redirect_info ||= []
      @redirect_info << redirect_info
      
      pe_log "added #{redirect_info} to #{self}"
    end
  end

#=

  def method_missing(m, *args, &block) 
    @history_item.send(m, *args, &block)
  end
  
#=

  def detail_string
    str = "#{self.title}\nURL: #{self.url}\nFirst accessed: #{timestamp}\nLast accessed: #{last_accessed_timestamp}"
    if $DEBUG
      str += "\n" + self.debug_info
    end
    
    str
  end
  
  def to_s
    "#{super} (#{self.history_item ? self.url : ''})"
  end
  
  def title
    history_item.title ? history_item.title : self.url
  end

  def ref
    # use the url as the reference.
    self.url
  end

  def inspect
    "#{super}: wrapping #{history_item}"
  end

  def debug_info
    "OriginalURL: #{self.originalURLString}\nEnquiry: #{self.enquiry}\nRedirects: #{@redirect_info}\nId: #{self.object_id}"
  end
  
#=

  def last_accessed_timestamp
    ts = if @last_accessed_timestamp
      @last_accessed_timestamp
    else
      @timestamp  # see, you knew this would get confusing.
    end

    ts or NilTime
  end
  
  def url
    @history_item.URLString
  end

  def title
    @history_item.title
  end

#= 

  def to_hash
    { 
      'url'=> self.url, 
      'title'=> self.title, 
      'timestamp'=> self.timestamp, 
      'last_accessed_timestamp'=> self.last_accessed_timestamp, 
      'pinned'=> (self.pinned ? true : false), 
      'enquiry'=> ( self.enquiry ? self.enquiry : '' ),
      'id' => self.url.hash  # id redundant?
    }
  end
  
  def self.from_hash( item_data )
    o = nil
    on_main {
      o = WebHistoryItem.alloc.initWithURLString(item_data['url'], title:item_data['title'], lastVisitedTimeInterval: 0)
    }
  
    o2 = ItemContainer.new(o)
    o2.pinned = item_data['pinned'] # IMPROVE write some kind of serialisation spec to avoid noddy sets like this one
    o2.timestamp = item_data['timestamp']
    o2.last_accessed_timestamp = item_data['last_accessed_timestamp']
    o2.enquiry = item_data['enquiry']
    
    o2
  end

#=
  
  def self.keyPathsForValuesAffectingValueForKey(key)
    case key
    when 'debug_info', 'detail_string'
      return NSSet.setWithArray( [ 'url', 'originalURLString', 'title', 'enquiry', 'timestamp', 'last_accessed_timestamp', 'redirect_info'  ] + super.allObjects )
    when 'url', 'originalURLString', 'title'
      return NSSet.setWithArray( [ 'history_item' ] + super.allObjects )
    else
      super
    end
  end
end


class HistoryContext < Context
  def initialize
    super 'History'
  end

  # TODO introduce as the store of all item info, change items in Stacks to be references.
end


class Site
  attr_accessor :name
  attr_accessor :base_url
  attr_accessor :search_url
  
  def initialize(name, base_url, search_url = nil)
    @name = name
    @base_url = base_url
    @search_url = search_url
  end
  
  def to_hash
    { 'name' => name, 'base_url' => base_url, 'search_url' => search_url }
  end
  
  def self.from_hash( hash )
    new(hash['name'], hash['base_url'], hash['search_url'])
  end

  def searchable?
    ! @search_url.to_s.empty?
  end
end

class NSString
  def to_query_url(query_text)
    raise "couldn't find query template in #{self}" unless self.include? '%query%'
    query_text = query_text.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
    self.gsub '%query%', query_text
  end
end


# TODO check if this is an appropriate stand-in value.
NilTime = Time.new 0
