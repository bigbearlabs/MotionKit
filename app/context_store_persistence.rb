module FilePersistence

  def save_stacks
    hash = self.to_hash
    save_report =  hash['stacks'].collect do |stack|
      "#{stack['name']}: #{stack['items'].count} history items"
    end

    hash.save_plist plist_name
    pe_log "saved #{self} - #{save_report}"
  rescue Exception => e
    pe_report e, "error saving #{plist_name}"
  end

  def load_stacks
    begin
      pe_log "loading contexts from #{plist_name}"
      context_store_data  = NSDictionary.from_plist( plist_name).dup
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

  def save_stacks
    # Stack -> CoreDataStack, then save.

    # focus first on clean high-level impl -- there will probably be perf enhancements when data scales to large sizes.
    records_to_save = self.stacks.map do |stack|

      # insert_or_update stack
      if stack.persistence_record
        stack.persistence_record
        # process all relationships in this call.
      else
        new_persistence_record stack
      end
    end

    records_to_save.map(&:save!)   # will throw errors if any
    # FIXME potentially inefficient.

    new_count = records_to_save.select( &:new_record?).size
    persist_count = records_to_save.select( &:persisted?).size

    pe_log "saved stacks. new: #{new_count}, saved: #{persist_count}"
     
    anomaly_count = records_to_save.size - persist_count
    raise "out of #{records_to_save.size} records, only #{persist_count} objects persisted" if anomaly_count != 0
  end
  
  def load_stacks
    # fetch CoreDataStack, then -> Stack.

    CoreDataStack.all.map do |record|
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
    end
  end

  #= TODO revise to commit-worthy.

  def persistable_pages pages
    pages.map do |page|
      p = CoreDataPage.new title:page.title, 
        url:page.url, 
        last_accessed:page.last_accessed_timestamp, 
        first_accessed:page.timestamp
      
      # unfortunate boilerplating for core_data_wrapper.
      ctx = App.delegate.managedObjectContext
      ctx.insertObject(p) # inserted into context, but not yet persisted

      p
    end
  end
  
  def new_persistence_record( stack )
    # assume the stack's pages are mostly new.
    record = CoreDataStack.new name:stack.name

    # unfortunate boilerplating for core_data_wrapper.
    ctx = App.delegate.managedObjectContext
    ctx.insertObject(record) # inserted into context, but not yet persisted

    record.pages = NSSet.setWithArray(persistable_pages(stack.pages)) # FIXME get rid of boilerplate

    stack.persistence_record = record

    pe_log "new persistence record for #{stack}."
    return record
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
