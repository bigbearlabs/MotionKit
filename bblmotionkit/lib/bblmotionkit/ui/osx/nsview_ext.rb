if BubbleWrap::App.osx?

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

  def arrange_single_column
    self.add_view *self.subviews
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

#=

end

end

