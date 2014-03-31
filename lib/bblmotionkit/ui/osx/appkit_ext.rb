module AppBehaviour

  def setup_wc window_controller_class, ivar_name = nil
    instance = window_controller_class.alloc.init

    # hold the wc as an ivar.
    ivar_name ||= "component_#{window_controller_class.name}"
    ivar_name = "@#{ivar_name}"
    instance_variable_set ivar_name, instance

    # prod the window.
    instance.window.visible = true

    instance
  end
  
end


class NSWindowController

#= lifecycle

  def init
    self.initWithWindowNibName(self.class.name.gsub('Controller', ''))

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


