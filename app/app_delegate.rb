MOTION_PLATFORM = :osx


class AppDelegate
  def applicationDidFinishLaunching(notification)
    buildMenu

    @wc = WebCollectionWindowController.alloc.init
    @wc.window.orderFrontRegardless
  end

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

case MOTION_PLATFORM
when :osx

  class NSWindowController

  #= lifecycle

    def init
      # platform-specific init
      case MOTION_PLATFORM
      when :osx
        self.initWithWindowNibName(self.class.name.gsub('Controller', ''))
      else
        raise "undefined for platform #{MOTION_PLATFORM}"
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
end


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
