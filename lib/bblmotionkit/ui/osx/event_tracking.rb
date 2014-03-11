# extend a view object containing a scroll view to expose the lastest scroll event as a property.
module ScrollTracking

  # clients shouldn't modify.

  def self.extend_object(receiver)
    class << receiver
      attr_accessor :scroll_event
    end

    scroll_view = receiver.views_where{|e| e.is_a? NSScrollView}.flatten.first

    # define the system event handler method and route over to self.
    class << scroll_view
      def scrollWheel( event )
        # just set the property.
        @scroll_tracking_owner.kvc_set :scroll_event, event

        super
      end
    end

    scroll_view.instance_variable_set :@scroll_tracking_owner,receiver

    pe_log "scroll tracking added to #{receiver}"
  end
end
