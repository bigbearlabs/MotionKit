class APIServer < BBLComponent

  attr_reader :new_stack
  attr_reader :new_page

  def on_setup

    @server = NSApp.delegate.component(ServerComponent)

    setup_server

  end

  def setup_server
    @server.on_entity_request :post, '/stacks', self

    @server.on_entity_request :post, '/stacks/:id/pages', self


    # post '/stacks/:id/pages/:id' do |stack_id, page_id, request|
    #   updated_page = request.body

    #   update_page page_id

    #   updated_page.to_json
    # end    
  end
  
  def handle_post_stacks request, response
    payload = request.body.to_s

    new_stack_data = Hash.from_json payload

    new_stack = @context_store.stack_for new_stack_data['name']

    {
      msg: "stack created or retrieved",
      id: new_stack.name,
      pages: new_stack.pages.map(&:to_hash)
    }.to_json
  end

  def handle_post_pages stack_id, request, response
    payload = request.body.to_s

    new_page_data = Hash.from_json payload

    details = {}
    details[:url] = new_page_data['url']

    if thumbnail_data = new_page_data['thumbnail_data']
      details[:thumbnail] = NSImage.from_data_url(thumbnail_data.to_url)
    end

    stack = @context_store.update_stack stack_id, details

    {
      msg: "page added",
      url: details[:url],
      stack: stack.name
    }.to_json
  end

  #= CoreData implementation

  def add_stack data
    record = CoreDataStack.create! data

    kvo_change :new_stack, record
    
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

    kvo_change :new_page, record

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