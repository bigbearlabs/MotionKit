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
  end
  
  def load_stacks
    # fetch CoreDataStack, then -> Stack.
  end
end


class CoreDataPage < MotionDataWrapper::Model
end

class CoreDataStack < MotionDataWrapper::Model
end
