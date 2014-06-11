motion_require '../legacy/WebBuddyAppDelegate'

# NOTE touching the rough edges of plugin abstraction - independent from plugin_vc, loading scheme different etc.


# integration.
class WebBuddyAppDelegate < MotionKitAppDelegate

  # when input field is first responder, unwanted menu validation early in the responder chain disables the find menu item. work around by adding the find method on appd.
  def performTextFinderAction(sender)
    pe_debug "#{sender} invoked text finder action"
    
    NSApp.key_window.controller.component(FindPlugin).handle_TextFinderAction sender  # rename
  end
end  


class FindPlugin < WebBuddyPlugin
  include FilesystemAccess

  #= plugin methods

  # inject the injectee component.
  def load_view

    if client.browser_vc.eval_js 'return (window.jQuery == null)'
      jquery_content = load "docroot/plugins/js/jquery-1.7.1.min.js", :app_support
      client.browser_vc.eval_js jquery_content
    else
      pe_log "jquery already loaded."
    end

    find_script = load 'docroot/plugins/injectees/find.js', :app_support
    client.browser_vc.eval_js find_script
  end
  
  def view_loaded?
    raise "unimplemented"
  end

  def view_url
    raise "plugin #{self} doesn't have a view url."
  end
  

  def on_setup
    setup_ns_text_finder
    watch_notification :Find_request_notification
  end

  # UNUSED
  def toggle_find
    if find_shown
      pe_log 'TODO hide find field'
    else
      handle_TextFinderAction sender
    end
  end
  
  
=begin

  # js version using window.find
  def find_string( string )
    js = "window.find('#{string}')"
    self.client.browser_vc.eval_js js # TODO how to consolidate all js like this?
  end
=end

  # js version with jquery
  def find_string( string = self.find_input )
    # be a bit paranoid about the content's state, to avoid deviations between js-based matching and NSTextFinder internal matching / counting.
    @text_finder.noteClientStringWillChange

    js = "$.searchText($(), '#{string}', $('body'), null);"
    result = self.client.browser_vc.eval_js js
  end

  def clear_highlights
    self.client.browser_vc.eval_js %Q(
      $.searchText($(), '', $('body'), null)
    )
  end

  def next_match( string = self.find_input )
    puts "TODO find next"
    # the native version takes care of the scrolling of the selection into view.
    # web_view.searchFor(string, direction:true, caseSensitive:false, wrap:true)  # FIXME this snatches first responder from find bar.

  end

  def previous_match( string = self.find_input )
    puts "TODO find previous"
    web_view.searchFor(string, direction:false, caseSensitive:false, wrap:true)
  end


#= system integration: osx text finder

  def setup_ns_text_finder
    @text_finder = NSTextFinder.alloc.init
    @text_finder.client = self
    @text_finder.incrementalSearchingEnabled = true
    @text_finder.incrementalSearchingShouldDimContentView = true

    # wire webview's scroll view as find bar container.
    scroll_view = self.client.browser_vc.view.views_where {|e| e.is_a? NSScrollView}.flatten.first
    @find_bar_container = scroll_view
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
  
  def handle_TextFinderAction(sender)
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
      
    when NSTextFinderActionSetSearchString

    when NSTextFinderActionNextMatch
      pe_log "find: next match"
      @action_type = :next_match
      
      # string = @text_finder.search_field.stringValue
      # self.find_string string
      
      # self.next_match

    when NSTextFinderActionPreviousMatch
      pe_log "find: previous match"
      @action_type = :previous_match
      
      # string = @text_finder.search_field.stringValue
      # self.find_string string
      
      # self.previous_match

    when NSTextFinderActionHideFindInterface
      pe_log "find: hide interface"
      @action_type = nil

      clear_highlights

      # self.refresh_find_bar_container
    end

    # pass on to the text finder.
    @text_finder.performAction(tag)
  end

#= NSTextFinderClient methods

  def string
    pe_log "string request"
    search_content = self.client.browser_vc.eval_js 'return document.documentElement.innerText'
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

  def firstSelectedRange
    # NSMakeRange(0, 0)

    @selected_range || NSMakeRange(0, 0)
  end

  def scrollRangeToVisible(range)
    p "TODO scroll"
    
    @selected_range = range

    # searchFor('the', direction:true, caseSensitive:false, wrap:true) does the scrolling. 
  end

  # this is called on incremental search
  def contentViewAtIndex(index, effectiveCharacterRange:range)
    
    p "view request; #{index}, #{range[0].location}, #{range[0].length}"
    
    # case @action_type
    # when :start_find
    #   #incremental search -
    #   # trigger the find in the webview. 
    #   # FIXME very hacky location 
    #   self.find_string
  
    #   # select the first match.
    #   self.next_match

    # else
    #   # raise "don't know how to handle action_type #{@action_type}"
    #   p "action_type #{@action_type}, not doing anything."
    # end
    
    range[0] = NSMakeRange(0, self.string.length)

    self.web_view
  end

  # TODO golden way to implement incremental find is to supply the rects for the matches. if this turns out to be infeasible due to webview api shortcomings, we should observe incrementalMatchRanges to detect incremental search progress, and eval the js.
  def rectsForCharacterRange(range)
    pe_log "rect request"

    # [ NSValue.valueWithRect(NSZeroRect) ]

    # [ NSValue.valueWithRect(NSMakeRect(100,100,20,10)) ]

    # web_view.markAllMatchesForText(find_input, caseSensitive:false, highlight:false, limit:0)

    # web_view.send 'markAllMatchesForText:caseSensitive:highlight:limit:', find_input, false, false, 0
    
    (@adapter ||= WebViewAdapter.new).markText(find_input, forWebView:web_view)
    
    web_view.rectsForTextMatches
  end

  def visibleCharacterRanges
    # stub
    [ NSValue.valueWithRange(NSMakeRange(0,100)) ]
  end

  def cancelOperation( sender )
    pe_debug "cancel find bar"
    
    @find_bar_container.findBarVisible = false
  end

#= props

  def find_input
    @text_finder_field ||= @text_finder.search_field
    @string = @text_finder_field.stringValue # PVT-API
  end

  def web_view
    # TACTICAL
    client.browser_vc.web_view
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