# require 'PERubyUtil'
# require 'KVOMixin'

# require 'monitor'

# FIXME revive 'items' prop (array)
class Context
  include KVOMixin

  attr_accessor :name
  
  attr_reader :pages
  # TODO
  attr_reader :highlights
  attr_reader :memos
  attr_reader :suggestions
  
  attr_accessor :filter_tag # for array controller filtering

  def items
    @pages.dup.freeze
  end
  
  # work around RM attr_reader - objc incompatibility.
  def current_page
    @current_page
  end

  def initialize( name = "Unnamed context #{self.name_suffix_sequence}", pages = [])
    super

    @name = name

    @pages = pages

    @sites ||= {}

    update_current_page
  end

#==
  
  # @param provisional(boolean): item is 'in-flight.'
  def update_detail( url, details )
    pe_debug "detail update requested for #{url}"
    
    # set details on the item.
    item = self.item_for_url url
    
    # NOTE this seems to happen with shortened url's involving client redirects.
    # CASE https://www.evernote.com/shard/s5/sh/aa05b207-8c98-4b9a-9a7d-9fd5d1d121fe/94d032b0b430fe228820e7347be974a8
    # for now, be a bit generous and watch what happens.
    if item.nil?
      pe_warn "#{url} not found on #update_detail."

      # add the access first and check again.
      self.add_access url, details
      item = self.item_for_url url
      if item.nil?
        raise "#{url} not found in history after falling back and adding to history."
      end
    end
    
    details.each do |k,v|
      item.invoke_setter k, v

      # additional actions      
      if k == :thumbnail
        # mark for saving
        item.thumbnail_dirty = true

        pe_log "marked #{item} as thumbnail_dirty"
      end
    end
  end
  
  def update_item( url, history_item )
    item_container = self.item_for_url url

    # defensively deal with nil for now.
    if item_container.nil?
      pe_warn "nil item for #{url} -- investigate.", ticket: true
      item_container = ItemContainer.from_hash({})
    end

    unless item_container.history_item.object_id == history_item.object_id
      pe_warn "replacing #{item_container.history_item} with #{history_item}"
      item_container.history_item = history_item
    end
  end
  
  def add_redirect( url, redirect_info )
    if url.nil?
      pe_log "got a nil url for redirect. ignoring"
      return
    end

    item = self.item_for_url(url)
    if ! item.nil?
      item.add_redirect redirect_info
    else
      raise "no item for #{url}"
      
    end
  end
  
#==


  def item_for_url( url )
    items = self.items.select do |item|
      item.match_url? url
    end
    
    case items.count
    when 0 then return nil
    when 1 then return items[0]
    else
      pe_warn "multiple items match #{url} - investigate."
      # items[0..-2].each do |item|
      #   self.remove_item item
      # end
      return items[0]
    end
  end  

  def touch( url, details = {} )
    if self.item_for_url url
      self.update_access url, details
    else
      self.add_access url, details
    end
  end

  ##

#=

  def add_item( history_item )
    raise "nil history_item" if history_item.nil?

    if item_for_url history_item.url
      pe_warn "#{history_item.url} already added to #{self}"
      debug history_item.url, history_item, self
    end

    kvo_change_bindable :pages do
      @pages << history_item
      self.update_current_page
    end
  end
  
  def remove_item( item_or_a )
    item_or_a = [ item_or_a ] unless item_or_a.is_a? Array

    kvo_change_bindable :items do
      item_or_a.map do |item|
        index = @pages.index(item)

        raise "item #{item} not found in #{self}" if index.nil?

        @pages.delete_at index
      end
    end
  end

  # drops duplicate items as tested by #match_url?.
  def compact
    items = self.items
    item_a = items.dup
    items.map do |item|
      if item.url.nil?
        pe_log "remove item with nil url: #{item}"
        self.remove_item item
      end
      
      dups = item_a.select{|e| e.match_url? item}[1..-1].to_a
      dups.map do |dup|
        pe_log "remove dup history items: #{dups.map &:url}"
        self.remove_item matching[1..-1].to_a
      end
    end      
  end
  
#=

  def back_page
    current_page_index = self.pages.index(@current_page)
    if current_page_index && current_page_index > 0
      self.pages[current_page_index - 1]
    else
      nil
    end
  end

  def forward_page
    current_page_index = self.pages.index(@current_page)
    if current_page_index && current_page_index <= self.pages.size - 1
      self.pages[current_page_index + 1]
    else
      nil
    end
  end

  ##

  def history_data
    items_data = self.items.map do |item|
      pe_log "item is nil at index #{i} - what's going on?" unless item

      item.to_hash.dup
    end
    
    pe_debug "history_data for #{self} - #{items_data.count} items"
    items_data
  end

  def load_items(items_to_load )
    items_to_load.each do |item|
      self.add_item item
    end

    pe_log "loaded #{items_to_load.count} items to context '#{self.name}'."

    # conditionally set the current page.
    update_current_page
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
  
  def site_for( item_or_url )
    case item_or_url
    when String
      url = item_or_url
    else
      url = item_or_url.url
    end
    
    @sites[url.to_base_url]
  end
 
  def site_for_base_url( base_url)
    @sites[base_url]
  end
  
  def current_site
    return nil if ! self.current_page
    self.site_for self.current_page
  end
  
  def current_site_defined
    self.current_site != nil
  end
  
  def new_site
    page = self.current_page
    site = Site.new(page.title, page.url.to_base_url, '')
    
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
  

#==
    
  def name_suffix_sequence
    @sequence ||= 0
    @sequence += 1
  end

#==
  
  # REFACTOR generalise hash serialisation from object attributes.
  def to_hash
    # filter out provisional pages for now.
    pages = self.pages.select { |e| ! e.provisional }

    stack_url = pages.empty? ? '' : pages.first.url
    { 
      'name' => self.name, 
      'url' => stack_url,
      # thumbnail_url: 'stub-thumbnail-url',
      'last_accessed_timestamp' => self.last_accessed_timestamp.to_s,
      'pages' => pages.map(&:to_hash), 
      # disabling unused stuff for agile core data modeling.
      # 'sites' => self.site_data,
    }
  end

#==

  def last_accessed_timestamp
    ts = self.items.map(&:last_accessed_timestamp).map do |timestamp|
      if timestamp.nil?
        NilTime
      elsif timestamp.is_a? String
        Time.cached_date_formatter('yyyy-MM-dd HH:mm:ss ZZZZZ').dateFromString(timestamp)
      else
        timestamp
      end
    end.max
    ts or NilTime
  end


protected

    attr_writer :current_page

    def update_current_page( page = self.pages.last )
      kvo_change_bindable :current_page do
        @current_page = page
      end
    end
    
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
      
      pe_debug "context.current_item: #{self.current_page.description}"
    end
    
    def update_access( url, details = {} )
      pe_debug "update_access: #{caller}"

      item = item_for_url url
      item.last_accessed_timestamp = NSDate.date
      item.filter_tag = item.timestamp

      self.update_current_page item

      self.update_detail url, details
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
  attr_accessor :timestamp  # first encountered
  attr_accessor :last_accessed_timestamp
  
  attr_accessor :redirect_info

  # incubating
  attr_accessor :enquiry
  attr_accessor :pinned
  attr_accessor :pinned_timestamp
  
  
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
    
    @history_item = history_item
    
    raise "invalid url for history item #{history_item}" unless self.url
  end
  
#=
  
  def match_url?( url )
    if ! self.url
      raise "#{self} has a nil url - we must find out why"
      # pe_warn "#{self} has a nil url - we must find out why"
      
      return false
    end
    
    url = url.to_s
    
    return self.url.match_url?(url) || 
      self.originalURLString.match_url?(url) || 
      @redirect_info.to_a.include?( url)
  end

  def add_redirect( redirect_info )
    kvo_change :redirect_info do
      @redirect_info ||= []
      @redirect_info << redirect_info unless @redirect_info.include? redirect_info
      
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
    ts = 
      unless @last_accessed_timestamp.to_s.empty?
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
      'name'=> self.title, 
      'last_accessed_timestamp'=> self.last_accessed_timestamp.to_s, 
      'thumbnail_url'=> NSApp.delegate.context_store.thumbnail_url(self).to_url_string,  # HACK

      # leftovers from the file persistence days.
      # 'timestamp'=> self.timestamp, 
      # 'pinned'=> (self.pinned ? true : false), 
      # 'enquiry'=> ( self.enquiry ? self.enquiry : '' ),
      # 'id' => self.url.hash  # id redundant?
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
    self.gsub( '%query%', query_text).escape
  end
end


# TODO check if this is an appropriate stand-in value.
NilTime = Time.new(0)
