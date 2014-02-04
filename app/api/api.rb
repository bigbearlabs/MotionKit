class APIServer < BBLComponent
  def on_setup

    @server = NSApp.delegate.component(ServerComponent)

    # prototypical api. refactor after settled
    @server.on_entity_request :put, '/stacks', self

    @server.on_entity_request :put, '/stacks/:id/pages', self


    # post '/stacks/:id/pages/:id' do |stack_id, page_id, request|
    #   updated_page = request.body

    #   update_page page_id

    #   updated_page.to_json
    # end
  end

  def handle_put_stacks request, response
    payload = request.body.to_s

    new_stack_data = Hash.from_json payload

    new_stack = add_stack new_stack_data

    new_stack.to_json
  end

  def handle_put_pages stack_id, request, response
    payload = request.body.to_s

    new_page_data = Hash.from_json payload

    new_page = add_page stack_id, new_page_data

    new_page.to_json
  end

  def add_stack data
    record = CoreDataStack.create data
    id = encode_id record.objectID.URIRepresentation.absoluteString

    {
      msg: "added stack",
      id: id,
      name: record.name,
      pages: record.pages.to_a
      # TODO more props.
    }
  end
  
  def add_page stack_id, data
    stack_record = fetch decode_id(stack_id)

    record = CoreDataPage.create! data
    stack_record.pages.addObject(record)
    
    stack_record.save! 

    {
      msg: "added page",
      id: encode_id(record.objectID.URIRepresentation.absoluteString)
    }
  end
  
  def encode_id core_data_id
    core_data_id.gsub('/', '.')
  end

  def decode_id encoded_id
    encoded_id.gsub('.', '/')
  end
      

  def fetch id_uri
    poc = NSApp.delegate.persistentStoreCoordinator
    moc = NSApp.delegate.managedObjectContext
    id = poc.managedObjectIDForURIRepresentation id_uri.to_url

    err = Pointer.new('@')
    record = moc.existingObjectWithID(id, error:err)
    if err[0]
      raise err[0] 
    else
      record
    end
  end
  
end