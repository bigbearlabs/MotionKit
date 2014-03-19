class Popover
  def initialize( view_controller )
    @popover = NSPopover.new
    @popover.contentViewController = view_controller
  end

  def show(args)
    anchor_view = args[:anchor]
    @popover.showRelativeToRect(NSZeroRect, ofView:anchor_view, preferredEdge:NSMinYEdge)
  end
  
end   



#= 
# a facade to all popover concerns. the view outlet should be assigned the window's content view.
class PopoverController < PEViewController
  include KVOMixin

  attr_accessor :popover  # wire to the NSPopover whose contentViewController is me.
  attr_accessor :anchor_view

  # other properties for convenient popup access to go here.

  def awakeFromNib
    super

    # we found out during the modkey held workflow that the window may not show properly. perform some fail-safe ops.
    # REFACTOR change to reactive
    # on_main_async do

    # MOTION-MIGRATION
    # observe_kvo self, "popover.shown" do |k,c,ctx|
    #   #     self.view.window.visible = true
    #   #     self.view.window.makeKeyAndOrderFront(self)

    #   self.view.window.recalculateKeyViewLoop
    # end
  end
  
  def show_popover(anchor_view = self.anchor_view)
    @popover.showRelativeToRect(anchor_view.bounds, ofView:anchor_view, preferredEdge:NSMinYEdge)

    # @popover.contentViewController.layout_vertical

    # trigger the setup that depends on the view and window relationships having been set up.
    # @popover.contentViewController.setup_hit_view_updating
  end

  def hide_popover
    @popover.performClose(self)
    # self.view.window.visible = false if self.view.window

    yield if block_given?
  end


  def size_vertical_to_window
    frame = NSApp.delegate.main_window_controller.window.frame

    @popover.contentSize = NSMakeSize(@popover.contentViewController.view.width, frame.height - 50)
  end


  def shown?
    @popover.isShown
  end
end

