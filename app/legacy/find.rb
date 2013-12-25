class BrowserViewController


  # invokes a js snippet that finds the text.
  def handle_Find_request_notification(notification)
    input_string = notification.userInfo

    self.find_string input_string
  end

  
  # API-compliant version of an in-page find.
  # issues: snatches first responder status
  def find_string( string )
    first_responder = self.view.window.firstResponder
    @web_view.searchFor(string, direction:(@find_direction != :back), caseSensitive:false, wrap:true)
    first_responder.make_first_responder
  end

  # js version using window.find
  def find_string( string )
    js = "window.find('#{string}')"
    self.eval_js js # TODO how to consolidate all js like this?
  end

  # js version with jquery
  def find_string( string )
    js = "jQuery.searchText($(), '#{string}', $('body'), null)"
    result = self.eval_js js
  end

#= the 10.7 standard find mechanism

  def setup_text_finder
    @text_finder ||= NSTextFinder.alloc.init
    @text_finder.client = self
    @text_finder.incrementalSearchingEnabled = true
    
    @text_finder.findBarContainer = @find_bar_container
    observe_kvo @find_bar_container, :findBarVisible do |obj, change, context|
      @action_type = nil # duped, ugh.
      
      pe_log "TODO clear search highlights"
      
      self.refresh_find_bar_container
    end
    
    self.refresh_find_bar_container
  end

  def handle_Text_finder_notification(notification)
    sender = notification.userInfo
    tag = sender.tag
    
    pe_log "tag from #{sender}: #{tag}"
    
    @text_finder.performAction(tag)
    
    # based on the tag, instruct webview to perform the right kind of search.
    case tag
    when NSTextFinderActionShowFindInterface
      pe_log "show interface"
      @action_type = :start_find
      
      self.load_js_lib
      
      self.refresh_find_bar_container

    when NSTextFinderActionNextMatch
      pe_log "next match"
      @action_type = :next_match
      
      string = @text_finder.search_field.stringValue
      self.find_string string
      
    when NSTextFinderActionPreviousMatch
      pe_log "previous match"
      @action_type = :previous_match
      
      string = @text_finder.search_field.stringValue
      self.find_string string
      
    when NSTextFinderActionHideFindInterface
      pe_log "hide interface"
      @action_type = nil

      self.refresh_find_bar_container
    end
  end

#= NSTextFinder

  def string
    pe_log "string request"
    search_content = self.eval_js 'document.documentElement.innerText'
  end

  # this is the hook that triggers incremental search
  def contentViewAtIndex(index, effectiveCharacterRange:range)
    
    pe_log "view request; #{index}, #{range[0].location}, #{range[0].length}"
    
    if ! @action_type
      pe_log "TODO clear search highlights"
    else
      #incremental search -
      # trigger the find in the webview. 
      @text_finder_field ||= @text_finder.search_field
      string = @text_finder_field.stringValue # PVT-API
      self.find_string string 
    end
    
    self.view
  end

  def rectsForCharacterRange(range)
    pe_log "rect reqeust"
    [ NSZeroRect ]
  end

=begin # this stuff unnecessary unless frames come in and make things ugly.
  def stringAtIndex(index, effectiveRange:range, endsWithSearchBoundary:outFlag)
    pe_debug "DING"
    
    str = self.string
    range.assign( NSMakeRange(0, str.length) )
    str
  end

  def stringLength
                 pe_debug "length DING"
    self.string.length
  end
=end

# TODO golden way to implement incremental find is to supply the rects for the matches. if this turns out to be infeasible due to webview api shortcomings, we should observe incrementalMatchRanges to detect incremental search progress, and eval the js.

=begin
  def firstSelectedRange
    # docs suggest this is needed for text finder-based 'find next' operation to work.
    # plan to use text finder may go tits up if we can't get the range of the selection in webview.
    pe_log "firstSelectedRange"
  end
=end
  
  def cancelOperation( sender )
    pe_debug "cancel find bar"
    
    @find_bar_container.findBarVisible = false
  end
  
  def refresh_find_bar_container
    if ! @action_type
      @find_bar_container.visible = false
      @web_view.frameSize = self.view.frameSize
    else
      @find_bar_container.visible = true
      @find_bar_container.frame = @find_bar_container.frame.modified_frame(find_bar_container.findBarView.frameSize.height + 1, :Top )

      @web_view.frame = @web_view.frame.modified_frame( self.view.frameSize.height - @find_bar_container.frameSize.height - 1, :Bottom )
    end
  end
  

end



#=

class NSTextFinder
  def search_field
    findBarContainer.findBarView.views_where {|v| v.kind_of? NSFindPatternSearchField }.flatten.first
  end
end

