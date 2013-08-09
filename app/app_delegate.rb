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

    def show
      showWindow(self)
    end

    #=

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

    def add_webviews to_view
      content_bounds = to_view.bounds

      top_half_frame = CGRectMake( content_bounds.origin.x, content_bounds.origin.y, 
        content_bounds.size.width, content_bounds.size.height / 2 )
      bottom_half_frame = CGRectMake( content_bounds.origin.x, content_bounds.origin.y + content_bounds.size.height / 2, 
        content_bounds.size.width, content_bounds.size.height / 2 )

      webview_1 = new_webview frame: top_half_frame
      webview_2 = new_webview frame: bottom_half_frame

      to_view.addSubview webview_1
      to_view.addSubview webview_2

      webview_1.mainFrameURL = 'http://google.com'
      webview_2.mainFrameURL = 'http://stackoverflow.com'
    end

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


class WebView
end
