# mix into a view.
module ScrollTracking
  attr_reader :scroll_event

  def scrollWheel( event )
    pe_log event.description
    
    # just set the property.
    kvo_change :scroll_event, event

    super
  end

  protected

  attr_writer :scroll_event
end