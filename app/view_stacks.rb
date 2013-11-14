class ViewStacksViewController < MotionViewController
  extend IB  
  include Reactive

  def setup

    # on hit_view update, bring it to the front.
    react_to :hit_view do
      puts "hit_view updated."

      refresh_visible_view @hit_view
    end

    # states for pushing in / pulling out
    @pulled_out_views ||= []
    @pushed_in_views ||= []

  end

  #=

  def add_vc vc
    @vcs ||= []

    @vcs << vc unless @vcs.include? vc
    self.add_view vc.view
  end

  def add_view view
    # push in all the loose views on the stack.
    if @pulled_out_views.size > 1
      @pulled_out_views[1..-1].map do |view|
        push_in view
      end
    end

    # horizontally align next to the last pushed in view.
    width = subview_width
    view.frame = NSMakeRect(self.view.width - width, self.view.y, width, self.view.height)
    view.move_x pushed_in_offset

    last_pushed_in_view = @pushed_in_views.last
    self.view.add_subview view, before:last_pushed_in_view

    # self.trackingAreas.map do |area|
    #   self.removeTrackingArea(area)
    # end

    # on_main_async do
      tracking_area =   NSTrackingArea.alloc.initWithRect(view.bounds, options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInActiveApp|NSTrackingInVisibleRect, owner:self, userInfo:nil)
      view.addTrackingArea( tracking_area )

      puts "tracking areas for #{view}: #{view.trackingAreas.map &:description}"
    # end

    self.hit_view = view
  end

#=

  def refresh_visible_view visible_view
    # pull out all views below visible_view.
    self.view.subviews_below(visible_view).map do |view_below|
      self.pull_out view_below
    end
    self.pull_out visible_view

    # push in all views above visible_view.
    self.view.subviews_above(visible_view).reverse.map do |view_above|
      self.push_in view_above
    end
  end

  def pull_out subview
    if @pulled_out_views.include? subview
    else

      @pulled_out_views << subview
      @pushed_in_views.delete subview

      new_x = self.view.width + pushed_in_offset - subview.width
      subview.set_x new_x
    end
  end

  def push_in subview

    if @pushed_in_views.include? subview
    else      

      subview.set_x self.view.width + pushed_in_offset - subview_offset

      @pushed_in_views << subview
      @pulled_out_views.delete subview
    end
  end

  def pushed_in_offset
    -1 * subview_offset * @pushed_in_views.size 
  end

  def subview_offset
    30
  end

  def subview_width
    self.view.width * 0.8
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
    hit_subview = content_view.hitTest(point)

    # work out the immediate subview that contains the hit.
    if hit_subview
      self.view.subviews.map do |child_view|
        if hit_subview.isDescendantOf(child_view)
          self.hit_view = child_view
        end
      end
    end

    puts "hit_view: #{self.hit_view}"
  end

  #=

  def handle_view_click sender
    
    # move 20 sender points to right.
    sender.move_x 20

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

    @delegate = WebViewDelegate.new
    @delegate.web_view = @search_page_view
    @delegate.matching_nav_handler = -> url {
      self.add_page url
    }
    @delegate.setup

    @search_page_view.frameLoadDelegate = @delegate
    @search_page_view.policyDelegate = @delegate
    @search_page_view.UIDelegate = @delegate
    @search_page_view.downloadDelegate = @delegate

    @search_page_view.mainFrameURL = 'http://google.com'

  end

  def add_page url
    vc = PageViewController.alloc.init
    vc.view.mainFrameURL = url
    self.add_vc vc
  end

end


class PageViewController < MotionViewController

end
