class ContextLoader < BBLComponent

  def on_setup
    
  end
  
  def defaults_spec
    {
      save_context: {
        postflight: -> val {
        },
        preference_spec: {
          view_type: :boolean,
          label: "Save history data",
        }
      },
      load_context: {
        postflight: -> val {
        },
        preference_spec: {
          view_type: :boolean,
          label: "Load history data",
        }
      },
    }
  end


  def save_context
    @context_store.save
  end

  def load_context
    @context_store.load
  end
end


module ThumbnailPersistence
  include DefaultsAccess

  default :thumbnail_dir
  default :thumbnail_extension

  def save_thumbnails
    Dir.mkdir_p thumbnail_path unless Dir.exists? thumbnail_path
    
    concurrently proc {
      self.stacks
        .map(&:pages)
        .flatten.select(&:thumbnail_dirty).map do |history_item|
          save_thumbnail history_item
        end
    }
  end

  def load_thumbnails    
    self.stacks.each do |stack|
      stack.pages do |history_item|
        if ! history_item.thumbnail
          file_name = thumbnail_path history_item
          image_png_data = NSData.data_from_file file_name  # OPTIMISE change to do this lazily
          if File.exists? file_name
            image = NSImage.alloc.initWithData(image_png_data)
            on_main {
              history_item.thumbnail = image
              pe_debug "loaded #{file_name} to #{image}"
            }
          end
        end
      end
    end
  end

  def save_thumbnail history_item
    file_name = "#{thumbnail_path}/#{history_item.url.hash}.#{thumbnail_extension}"
    thumbnail = history_item.thumbnail
    image_rep = thumbnail.representations[0]
    data = image_rep.representationUsingType(NSPNGFileType, properties:nil)

    result = data.writeToFile("#{file_name}", atomically:false)
    
    if result
      pe_log "saved #{file_name}"
      history_item.thumbnail_dirty = false
    else
      pe_log "failed saving #{file_name}"
    end

  end
  
#=

  def thumbnail_path( item = nil)
    path = "#{NSApp.app_support_path}/#{thumbnail_dir}"
    path += "/#{item.url.hash}.#{thumbnail_extension}" if item
    path
  end

  # MOVE
  def thumbnail_url( item )
    "/data/thumbnails/#{item.url.hash}.#{thumbnail_extension}"
  end
  
end



# class WebBuddyAppDelegate < PEAppDelegate
module StackUpdateReceiver
  attr_accessor :updated_stack  # data clients to observe and react. should be on context_store but but working around the kvo bug.
end


module FilePersistence
  include DefaultsAccess

  default :default_plist_name

  def save_stacks
    hash = self.to_hash
    save_report =  hash['stacks'].collect do |stack|
      "#{stack['name']}: #{stack['items'].count} history items"
    end

    hash.save_plist default :plist_name
    pe_log "saved #{self} - #{save_report}"
  rescue Exception => e
    pe_report e, "error saving #{default :plist_name}"
  end

  def load_stacks
    begin
      pe_log "loading contexts from #{default :plist_name}"
      context_store_data  = NSDictionary.from_plist( default :plist_name).dup
    rescue Exception => e
      pe_report e
      pe_warn "TODO trigger backup restoration workflow"  # IMPL
      
      context_store_data = {}
    end
    
    if ( ! context_store_data || context_store_data.keys.empty? )
      pe_log "initializing empty context store from default template."
      context_store_data = NSBundle.mainBundle.dictionary_from_plist( "data/#{default_plist_name}" )
    end

    
    # load the history context.

    # history_data = context_store_data['stacks'].find do |stack_hash|
    #   stack_hash['name'] == 'History'
    # end
    # history_context = self.stacks.find do |context|
    #   context.name == 'History'
    # end

    # items_data = history_data['items']
    # items_data.each do |item_hash|
    #   item = new_item item_hash
    #   history_context.add_item item
    # end
    # pe_log "loaded #{items_data.count} items in history context."

    # # history_context.load_sites history_data['sites']

    # # self.load_stacks history_data['stacks']


    # initialise or populate the other contexts.
    try { 
      context_store_data['stacks'].to_a.each do |stack_hash|

        name = stack_hash['name']
        matching_stacks = self.stacks.select { |e| e.name == name }
        case matching_stacks.size
        when 0
          stack = stack_for name
        when 1
          # the object already exists.
        else
          pe_warn "multiple stacks named '#{name}' found - using last one."
        end

        stack ||= self.stacks.last

        items = stack_hash['items'].map {|e| new_item e}
        stack.load_items items

        # context.load_sites stack_hash['sites']
      end

    }
    
  end

end


module CoreDataPersistence
  attr_accessor :abort_load  # set to true to abort loading.

  # CASE when data doesn't have an attached persistence record, will create duplicate records.
  def save_stacks( stacks = self.stacks )
    # Stack -> CoreDataStack, then save.

    # focus first on clean high-level impl -- there will probably be perf enhancements required when data scales to large sizes.
    inserts = []
    updates = []
    stacks.map do |stack|
      # insert_or_update stack
      if record = stack.persistence_record
        update_persistence_record stack
        updates << record if record.updated?
      else
        record = new_persistence_record stack
        inserts << record
      end
    end

    (inserts + updates).map(&:save!)   # will throw errors if any
    # FIXME potentially inefficient.

    pe_log "saved stacks. inserted: #{inserts.size}, updated: #{updates.size}"
  rescue Exception => e
    pe_report e, "error saving stacks"
  end
  
  def load_stacks
    # fetch CoreDataStack, then -> Stack.

    # pe_trace

    # stack_records = CoreDataStack.all_prefetching ['name, pages.url, pages.title, pages.last_accessed, pages.first_accessed']
    stack_records = CoreDataStack.all
    
    pe_log "loading #{stack_records.size} stack records."
    stack_records.map do |record|
      if @abort_load
        pe_warn "aborting load_stacks"
        return
      end
      
      stack = to_stack record

      # workaround notif to the stack users.
      NSApp.delegate.updated_stack = stack
    end

    pe_log "finished loading #{stack_records.size} stacks."
  end

  def to_stack( record )
    stack = self.stack_for record.name

    page_hashes = record.pages.to_a.map do |page_record|
      {
        title: page_record.title,
        url: page_record.url,
        last_accessed_timestamp: page_record.last_accessed,
        timestamp: page_record.first_accessed,
      }.to_stringified
    end
    # FIXME reconcile all attribute names.
    
    pages = page_hashes.map{|e| new_item e}  # TODO rename new_item to new_page or Page.from_hash
    stack.load_items pages

    stack.persistence_record = record
    stack
  end
  
  #= TODO revise to commit-worthy.

  def persistable_pages stack
    stack.pages.map do |page|
      p = CoreDataPage.find_by_url(page.url)  # TODO multiple matches

      if ! p
        p = CoreDataPage.new title:page.title, 
          url:page.url, 
          last_accessed:page.last_accessed_timestamp, 
          first_accessed:page.timestamp
        if moc = stack.persistence_record.managedObjectContext
          moc.insertObject(p)
        end
      end

      p
    end
  end
  
  def new_persistence_record( stack )
    # assume the stack's pages are mostly new.
    record = CoreDataStack.new
    stack.persistence_record = record

    # unfortunate boilerplating for core_data_wrapper.
    ctx = App.delegate.managedObjectContext
    ctx.insertObject(record) # inserted into context, but not yet persisted

    stack.persistence_record = record

    update_persistence_record stack

    pe_log "new persistence record for #{stack}."
    return record
  end

  def update_persistence_record( stack )
    record = stack.persistence_record

    # update record properties
    record.kvc_set_if_needed :name, stack.name
    record.kvc_set_if_needed :pages, NSSet.setWithArray(persistable_pages(stack)) # FIXME get rid of boilerplate
    record
  end
  
end


module Persistable
  # FIXME don't call - crashes RM.
  def persistence_id
    if r = self.persistence_record
      r.objectID
    else
      nil
    end
  end
  
  # practically private.
  attr_accessor :persistence_record
end

class Context
  include Persistable
end

class ItemContainer
  include Persistable
end

class CoreDataPage < MotionDataWrapper::Model
end

class CoreDataStack < MotionDataWrapper::Model
end

