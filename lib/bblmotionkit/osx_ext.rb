if BubbleWrap::App.osx?

  class NSWindowController

  #= lifecycle

    def init
      # platform-specific init
      if BubbleWrap::App.osx?
        self.initWithWindowNibName(self.class.name.gsub('Controller', ''))
      else
        raise "undefined for this platform #{BubbleWrap::App}"
      end

      self

      # TODO refactor usages
    end

  #= window management

    def show
      showWindow(self)
    end


  #= view management

    def add_vc view_controller, frame_view = self.window.contentView
      unless frame_view.subviews.empty?
        puts "subviews #{frame_view.subviews} will potentially be masked"
      end

      frame_view.addSubview view_controller.view

      view_controller.view.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable
      view_controller.view.translatesAutoresizingMaskIntoConstraints = true

      view_controller.view.fit_superview

      @vcs ||= []
      @vcs << view_controller
    end

    def view
      self.window.contentView
    end


    def title_frame_view
      rect = window.frame_view._titleControlRect

      unless @title_frame_view
        @title_frame_view = new_view rect.x, rect.y, rect.width, rect.height
        window.frame_view.addSubview @title_frame_view
      else
        @title_frame_view.frame = rect
      end
      
      @title_frame_view
    end

  end

  class NSView

    #=

    def subviews_above view
      view_index = self.subviews.index view
      self.subviews[view_index + 1..-1]
    end

    def subviews_below view
      view_index = self.subviews.index view
      self.subviews[0..view_index - 1]
    end

    def add_subview subview, params = {}
      before_view = params[:before]
      if before_view
        self.addSubview(subview, positioned:NSWindowBelow, relativeTo:before_view)
      else
        self.addSubview(subview)
      end
    end
    #=

  end

end

