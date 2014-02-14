# NOTE touching the rough edges of plugin abstraction - independent from plugin_vc, loading scheme different etc.

# NOTE text finder responder behaviour can break when multiple BrowserViewControllers are used in the same window.
# the vc that's set up later will 'win' the text finder.

class FindPlugin < WebBuddyPlugin

  #= plugin methods
  def view_url
    raise "plugin #{self} doesn't have a view url."
  end
  
  def load_view

    client.browser_vc.load_js_lib :jquery

    client.browser_vc.eval_js_file 'plugins/injectees/find.js'
  end
  
  def view_loaded?
    raise "unimplemented"
  end

  def on_setup
    setup_ns_text_finder
    watch_notification :Find_request_notification
    watch_notification :Text_finder_notification, self
  end

  def toggle_find
    if find_shown
      pe_log 'TODO hide find field'
    else
      send_notification :Text_finder_notification, sender
    end
  end
  

  # unused.
  def handle_Find_request_notification(notification)
    input_string = notification.userInfo

    self.find_string input_string
  end

  
=begin
  # API-compliant version of an in-page find.
  # issues: snatches first responder status
  def find_string( string )
    first_responder = self.view.window.firstResponder
    @web_view.searchFor(string, direction:(@find_direction != :back), caseSensitive:false, wrap:true)
    # first_responder.

  end

  # js version using window.find
  def find_string( string )
    js = "window.find('#{string}')"
    self.client.browser_vc.eval_js js # TODO how to consolidate all js like this?
  end
=end

  # js version with jquery
  def find_string( string )
    # be a bit paranoid about the content's state, to avoid deviations between js-based matching and NSTextFinder internal matching / counting.
    @text_finder.noteClientStringWillChange

    js = "jQuery.searchText($(), '#{string}', $('body'), null);"
    result = self.client.browser_vc.eval_js js
  end

  def clear_highlights
    self.client.browser_vc.eval_js %Q(
      $.searchText($(), '', $('body'), null)
    )
  end

#= system integration: osx text finder

  def setup_ns_text_finder
    # wire webview's scroll view as find bar container.
    scroll_view = self.client.browser_vc.view.views_where {|e| e.is_a? NSScrollView}.flatten.first
    @find_bar_container = scroll_view

    @text_finder = NSTextFinder.alloc.init
    @text_finder.client = self
    @text_finder.incrementalSearchingEnabled = true
    @text_finder.findBarContainer = @find_bar_container

    # # observe system property indicating find feature activation. provided by the scroll view.
    # observe_kvo @find_bar_container, :findBarVisible do |obj, change, context|
    #   @action_type = nil # duped, ugh.
      
    #   pe_log "TODO clear search highlights"

    #   self.refresh_find_bar_container
    # end
    
    # self.refresh_find_bar_container
  end

  def refresh_find_bar_container
    # if ! @action_type
    #   @find_bar_container.visible = false
    #   @web_view.frameSize = self.view.frameSize
    # else
    #   @find_bar_container.visible = true
    #   @find_bar_container.frame = @find_bar_container.frame.modified_frame(find_bar_container.findBarView.frameSize.height + 1, :Top )

    #   @web_view.frame = @web_view.frame.modified_frame( self.view.frameSize.height - @find_bar_container.frameSize.height - 1, :Bottom )
    # end
  end
  
  def handle_Text_finder_notification(notification)
    sender = notification.userInfo
    if sender.respond_to? :tag
      tag = sender.tag 
    else
      # default to the show find.
      tag = NSTextFinderActionShowFindInterface
    end
    
    pe_log "tag from #{sender}: #{tag}"
    
    # based on the tag, instruct webview to perform the right kind of search.
    case tag
    when NSTextFinderActionShowFindInterface
      pe_log "find: show interface"
      @action_type = :start_find
      
      self.load_view
      
      self.refresh_find_bar_container

      # # make it the first responder. FIXME on startup, something else snatches back first responder status.
      # if @find_bar_container.isFindBarVisible      
      #   (@responder_change_throttle ||= Object.new).delayed_cancelling_previous 0.5, -> {
      #     @text_finder.search_field.make_first_responder
      #   }
      # end
      
    when NSTextFinderActionNextMatch
      pe_log "find: next match"
      @action_type = :next_match
      
      string = @text_finder.search_field.stringValue
      self.find_string string
      
    when NSTextFinderActionPreviousMatch
      pe_log "find: previous match"
      @action_type = :previous_match
      
      string = @text_finder.search_field.stringValue
      self.find_string string
      
    when NSTextFinderActionHideFindInterface
      pe_log "find: hide interface"
      @action_type = nil

      clear_highlights

      # self.refresh_find_bar_container
    end

    # pass on to the text finder.
    @text_finder.performAction(tag)
  end

  def string
    pe_log "string request"
    search_content = self.client.browser_vc.eval_js 'return document.documentElement.innerText'
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
    
    self.client.browser_vc.view
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
end


#=

class NSTextFinder
  def search_field
    self.findBarContainer.findBarView.views_where {|v| v.kind_of? NSFindPatternSearchField }.flatten.first
  end
end


# special case for making an NSTextField the first responder.
class NSTextField
  def field_editor
    currentEditor
  end
  
  def make_first_responder
    if (field_editor = self.field_editor)
      self.window.makeFirstResponder(field_editor)
    else
      super
    end
  end
end