class NSView

#= inspection

  def tree
    puts self._subtreeDescription
  end
  
#= subview.access

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


#= subview.arrangement

  # tile (flow layout) the subviews, balancing margins based on the number of views per row.
  def arrange_tiled
    # some simplifying assumptions for constants that may need revisiting for more flexibility
    margin_v = 5
    row_height = 30
    
    rows = self.rows_of_subviews
    row_v_position = 5
    rows.each { |row|
      total_element_width = row.inject(0) {|r, view| r += view.width}
      total_margin_width = self.width - total_element_width
      margin_h = total_margin_width / (row.count + 1) # e.g. if 3 views, there are 4 margins
      
      x_tally = 0
      row.each { |view|
        view.center = CGPointMake(x_tally + margin_h + (view.width / 2), row_v_position + (row_height / 2))
        x_tally += margin_h + view.width
      }
      
      row_v_position += row_height
    }
  end
  
  def arrange_single_row(margin_h = 0)
    view_origin_x = 0
    self.subviews.each do |view|
      view_origin_y = ((self.frame.origin.y + self.height) - view.height ) / 2 # center vertically
      view.origin = NSMakePoint(view_origin_x, view_origin_y)
      view_origin_x += view.width + margin_h
    end 
  end

  def arrange_single_column( opts = {})
    subviews = self.subviews.dup
    self.clear_subviews
    subviews.map do |subview|
      self.add_tiled_vertical subview
      if opts[:centre_horizontal]
        subview.centre_horizontal
      end
    end

    self
  end

  # MOVE
  def centre_horizontal
    self.x = superview.center.x - self.width / 2
  end

  def rows_of_subviews
    rows = []
    
    width_tally = 0
    view_for_row_collector = []
    self.subviews.each { |view|
      if width_tally + view.width > self.width && ! view_for_row_collector.empty?
        # we collected all the views for the row.
        rows << view_for_row_collector
        width_tally = 0
        view_for_row_collector = []
      else
        width_tally += view.width
      end

      view_for_row_collector << view
    }
    rows << view_for_row_collector if ! view_for_row_collector.empty?
    
    rows
  end

  # add a splat of views tiling vertically.
  def add_view( view = new_view(10, 10, self.width - 20, self.height - 20), *views)
    self.addSubview(view)   
    view.snap_to_top

    views.map do |view|
      if view.nil?
        view = NSTextField.new
        view.frame = [[0,0], [80,20]]
        view.stringValue = "nil view!"
      end

      self.add_tiled_vertical view
    end
    
    self
  end

  # equivalent to adding then snap_to_sibling of last subview.
  def add_tiled_vertical( subview )
    # ensure we don't accidentally use the subview as a parameter to the geometry ops.
    subview.removeFromSuperview if self.subviews.include? subview

    last_subview = self.subviews.last

    self.addSubview(subview)
    if last_subview
      subview.snap_to_bottom_of last_subview
    else
      subview.snap_to_top ref_view:self
    end

    # # enlarge vertically if necessary
    # # TODO constrain shrinking, maybe
    # new_height = self.frame_for_subviews.height
    # self.frame = self.frame.modified_frame(new_height, :Top)

    # self.fit_pinning_top
  end

  def clear_subviews
    self.subviews.dup.each do |subview|
      subview.removeFromSuperview
    end
  end

#= general / geometry

  def visible
    ! self.isHidden
  end
  
  def visible=( is_visible )
    self.hidden = ! is_visible
  end
  
  def x
    self.frame.x
  end

  def y
    self.frame.y
  end

  def x=( x )
    self.frame = new_rect x, y, width, height
  end
  
  def y=( y )
    self.frame = new_rect x, y, width, height
  end

  def width
    self.frame.size.width
  end
  
  def height
    self.frame.size.height
  end

  def width=( width )
    self.frame = NSRect.rect_with_center self.center, width, height
  end

  def height=( height )
    self.frame = NSRect.rect_with_center self.center, width, height
  end
    
  def center
    CGPointMake(self.frame.origin.x + (self.width/2), self.frame.origin.y + (self.height/2))
  end
  
  def center=(new_center)
    new_x = new_center.x - (self.width / 2)
    new_y = new_center.y - (self.height / 2)
    self.frame = CGRectMake(new_x, new_y, self.width, self.height)
  end


  def origin=(new_origin)
    self.frameOrigin = new_origin
  end

  #= redundant: x=, x +=

  def move_x offset
    new_frame = NSMakeRect( frame.origin.x + offset, frame.origin.y, frame.size.width, frame.size.height)
    self.frame = new_frame
  end

  def set_x new_x
    new_frame = NSMakeRect( new_x, frame.origin.y, frame.size.width, frame.size.height)
    self.frame = new_frame
  end

#= sizing in relation to subviews
  
  def size_to_fit(opts = { margin: 0 })
    subview_frame = self.frame_for_subviews
    self.frame = subview_frame

    # margin = opts[:margin]
    # self.add_margin margin

    # TODO reference point is unclear.

    self
  end

  # def add_margin margin
  #   self.frame = NSRect.rect_with_center self.center, self.width + margin * 2, self.height + margin * 2
  # end

  def frame_for_subviews
    union = NSZeroRect
    self.subviews.each do |v|
      union = NSUnionRect(union, v.frame)
    end
    
    union
  end

  # get the union rect of the subviews and resize vertically, anchored at top edge.
  def fit_pinning_top
    union_frame = frame_for_subviews
    
    # # balance horizontally - offset x based on diff between old and new widths.
    # width_change = union_frame.width - self.width 
    # new_x = self.x - width_change / 2
    new_x = self.x

    # pin at the top - offset y based on original top location and new height.
    new_y = self.frame.top_y - union_frame.height

    # we need to apply a vertical offset to all subviews later.
    delta_y = (new_y - self.y)

    # set the frame (and pray)
    self.frame = new_rect new_x, new_y, union_frame.width, union_frame.height

    self.subviews.each do |subview|
      if delta_y > 0  # we need to grow - move subview y up.
        subview.y += delta_y
      else  # we need to shrink - move subview y down.
        subview.y -= delta_y
      end
    end
  end

#= querying view hierarchy

  def views_where(&block)
    # traverse view hierarchy and collect views matching condition.
    hits = []
    hits << self if yield self
    self.subviews.each do |subview|
      subview_hits = subview.views_where(&block)
      hits << subview_hits if ! subview_hits.empty?
    end
    
    hits
  end
  
  def superview_where
    superview = self.superview
    while superview
      matched = yield(superview)
      return superview if matched == true
      
      superview = superview.superview
    end
    
    nil
  end

#= positioning / sizing in relation to superview / siblings

  def snap_to_top( opts = { ref_view: self.superview } )
    new_y = opts[:ref_view].height - self.height
    self.frame = CGRectMake(self.frame.origin.x, new_y, self.width, self.height)
  end
  
  # reposition to line up with bottom of sibling view.
  def snap_to_bottom_of( sibling_view )
    new_y = sibling_view.frame.origin.y - self.height
    self.frame = CGRectMake(self.frame.origin.x, new_y, self.width, self.height)
  end

  # resize to line up with bottom of sibling view.
  def fit_to_bottom_of( sibling_view )
    new_height = sibling_view.frame.origin.y - self.frame.origin.y
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.width, new_height)
  end

#= z-order
  
  def position_to_front
    raise "superview nil" if ! self.superview
    
    self.superview.addSubview(self, positioned:NSWindowAbove, relativeTo:nil)
  end
  
  def position_to_back
    raise "superview nil" if ! self.superview
    
    self.superview.addSubview(self, positioned:NSWindowBelow, relativeTo:nil)
  end

#= image

  # http://www.stairways.com/blog/2009-04-21-nsimage-from-nsview
  # some coordinate translation necessary.
  def image( capture_frame = self.bounds, size = self.bounds.size )
    begin
      frame_of_view = CGRectMake(capture_frame.origin.x, self.bounds.size.height - capture_frame.size.height, capture_frame.size.width, capture_frame.size.height)
      image_rep = self.bitmapImageRepForCachingDisplayInRect(frame_of_view)
      image_rep.setSize(frame_of_view.size)
      self.cacheDisplayInRect(frame_of_view, toBitmapImageRep:image_rep)
      image = NSImage.alloc.initWithSize(size)
      image.addRepresentation(image_rep)

      image
    rescue Exception => e
      pe_report e
      nil
    end
  end
  
  def image_view( capture_frame = self.bounds, size = self.bounds.size )
    page_image = self.image capture_frame, size
    image_view = NSImageView.alloc.initWithFrame(capture_frame)
    image_view.image = page_image
    image_view
  end

#= instantiation

  def duplicate
    archived_view = NSKeyedArchiver.archivedDataWithRootObject(self)
    view_copy = NSKeyedUnarchiver.unarchiveObjectWithData(archived_view)
  end

#= context menu

  def display_context_menu( menu )
    if menu.is_a? Array
      # create an nsmenu.
      ns_menu = new_menu menu
      menu = ns_menu
    end

    NSMenu.popUpContextMenu(menu, withEvent:NSApp.currentEvent, forView:self)
  end


#= mouse event handling / tracking.
  
  def mouse_inside?
    mouse_location = self.window.mouseLocationOutsideOfEventStream
    hit_view = self.hitTest(self.convertPoint(mouse_location, fromView:nil))
    
    hit_view != nil
  end

  def track_mouse_move( &handler )
    masks = NSMouseMovedMask
    
    self.window.acceptsMouseMovedEvents = true

    self.track_events masks, handler
  end
  
  # @param handler: block receiving parameters event, hit_view.
  def track_mouse_down( &handler )
    masks = NSLeftMouseDownMask

    self.track_events masks, -> event { event.clickCount == 0 }, &handler
  end

  def track_mouse_up( &handler )
    masks = NSLeftMouseUpMask

    self.track_events masks, &handler
  end

  # TODO decompose masks into pre-OR'ed
  def track_events masks, match_condition = nil, &handler
    the_handler = lambda { |event|
      if event.window == self.window && event.match_mask?(masks) != 0
        # proceed only if match condition met.
        if match_condition
          return event if match_condition.call event
        end

        point = self.convertPoint(event.locationInWindow, fromView:nil)
        hit_view = self.hitTest(point)
        if hit_view
          pe_debug "calling event tracking handler for mask #{masks}"
          handler.call event, hit_view
        end
      end
      
      return event
    }

    NSEvent.addLocalMonitorForEventsMatchingMask(masks, handler:the_handler)
  end

    
  # only 1 tracking area per view, you realise.
  def add_tracking_area(mouse_entered_proc, mouse_exited_proc)
    @handler = { :mouse_entered_proc => mouse_entered_proc, :mouse_exited_proc => mouse_exited_proc, :view => self }
    class << @handler
      def mouseEntered(event)
        self[:mouse_entered_proc].call(self[:view])
      end
      
      def mouseExited(event)
        self[:mouse_exited_proc].call(self[:view])
      end
    end
  
    tracking_area = NSTrackingArea.alloc.initWithRect(self.bounds, options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways, owner:@handler, userInfo:nil)

    self.addTrackingArea(tracking_area)
  end

  def update_tracking_areas
    new_areas = self.trackingAreas.collect do |tracking_area|
      self.removeTrackingArea(tracking_area)
      
      NSTrackingArea.alloc.initWithRect(self.bounds, options:tracking_area.options, owner:tracking_area.owner, userInfo:tracking_area.userInfo)
    end
    
    new_areas.each do |new_area|
      self.addTrackingArea(new_area)
    end
  end

end

