class AppDelegate
  def applicationDidFinishLaunching(notification)
    buildMenu

    @wc = DevWindowController.alloc.init
    @wc.window.orderFrontRegardless

    view_stacker = WebStacksViewController.alloc.init
    @wc.add_vc view_stacker
    view_stacker.setup
  end

  #= 

  def buildWindow
    @mainWindow = NSWindow.alloc.initWithContentRect([[240, 180], [480, 360]],
      styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask,
      backing: NSBackingStoreBuffered,
      defer: false)
    @mainWindow.title = NSBundle.mainBundle.infoDictionary['CFBundleName']
    @mainWindow.orderFrontRegardless

    @mainWindow
  end

end


class ViewStacksViewController < MotionViewController
  extend IB  
  include Reactive

  def setup
    # on hit_view update, bring it to the front.
    react_to :hit_view do
      puts "hit_view updated."

      if @hit_view.is_a? NSButton
        superview = @hit_view.superview
        # @hit_view.removeFromSuperview
        superview.addSubview(@hit_view, positioned:NSWindowAbove, relativeTo:nil)
      end
    end

  end

  #=

  def add_view view
    self.view.addSubview( view )

    # self.trackingAreas.map do |area|
    #   self.removeTrackingArea(area)
    # end

    # on_main_async do
      tracking_area =   NSTrackingArea.alloc.initWithRect(view.bounds, options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInActiveApp|NSTrackingInVisibleRect, owner:self, userInfo:nil)
      view.addTrackingArea( tracking_area )

      puts "tracking areas for #{view}: #{view.trackingAreas.map &:description}"
    # end
  end

  def on_main_async( &block )
    Dispatch::Queue.main.async do
      block.call
    end
  end

#=

  attr_accessor :hit_view

  def mouseEntered event
    puts "entered: #{event}"

    update_hit_view event

  end

  def mouseExited event
    puts "exited: #{event}"
    
    update_hit_view event
  end

  def update_hit_view event
    content_view = self.view.window.contentView
    point = content_view.convertPoint(event.locationInWindow, fromView:nil)
    self.hit_view = content_view.hitTest(point)
    
    puts "hit_view: #{self.hit_view}"
  end

  #=

  def handle_view_click sender
    
    # move 20 sender points to right.
    frame = sender.frame
    new_frame = NSMakeRect( frame.origin.x + 20, frame.origin.y, frame.size.width, frame.size.height)
    sender.frame = new_frame

    # log the tracking areas.
    [ view_1, view_2 ].map do |view|
      puts "#{view}: #{view.trackingAreas.map &:description}"
    end
  end

end


class WebStacksViewController < ViewStacksViewController
  extend IB

  outlet :search_page_view

  def setup
    super

    self.add_view @search_page_view
    @search_page_view.mainFrameURL = 'http://google.com'

    # TEMP
    self.add_page 'http://duckduckgo.com'

    # TODO on webview search result link click, create / select new stack element.
  end

  def add_page url
    parent_frame = self.view.frame
    delta = 30
    frame = NSMakeRect( parent_frame.origin.x + delta, parent_frame.origin.y,
      parent_frame.size.width - delta, parent_frame.size.height)
    web_view = WebView.alloc.init frame:frame, url:url

    self.add_view web_view
  end

end


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



  class WebCollectionWindowController < NSWindowController

    #= webview setup

    def new_webview args
      frameRect = args[:frame]
      frameName = nil
      groupName = nil
      WebView.alloc.initWithFrame(frameRect, frameName:frameName, groupName:groupName)
    end

  end

  class DevWindowController < NSWindowController
  end

end


# experimental logic to horizontally to webviews with sane scrolling behaviour.
class WebCollectionWindowController
  extend IB

  outlet :webview_1
  outlet :webview_2

  def awakeFromNib
    super

    # add_webviews window.contentView

    # make inner scroll view pass all scroll events to outer scroll view.
    [ webview_1, webview_2].map do |webview|
      outer_scroll_view = webview.superview.superview.superview
      inner_scroll_view = webview.subviews[0].subviews[0]
      puts "outer: #{outer_scroll_view}"
      puts "inner: #{inner_scroll_view}"

      class << inner_scroll_view
        attr_writer :outer_scroll_view
        def scrollWheel(event)
          @outer_scroll_view.scrollWheel(event)
        end
      end

      inner_scroll_view.outer_scroll_view = outer_scroll_view
    end

    webview_1.mainFrameURL = 'http://google.com'
    webview_2.mainFrameURL = 'http://stackoverflow.com'
  end
end


class NSView
  def fit_superview
    self.frame = self.superview.bounds
  end
end

class WebView
  def init args = {}
    frame = args[:frame]
    frame_name = args[:frame_name]
    group_name = args[:group_name]
    obj = self.initWithFrame frame, frameName:frame_name, groupName:group_name

    url = args[:url]
    if url
      obj.mainFrameURL = url
    end

    obj
  end
end
