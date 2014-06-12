motion_require '../legacy/WebBuddyAppDelegate'

# NOTE touching the rough edges of plugin abstraction - independent from plugin_vc, loading scheme different etc.


# integration.
class WebBuddyAppDelegate < MotionKitAppDelegate

  # when input field is first responder, unwanted menu validation early in the responder chain disables the find menu item. work around by adding the find method on appd.
  def performTextFinderAction(sender)
    pe_debug "#{sender} invoked text finder action"
    
    NSApp.key_window.controller.component(FindPlugin).on_TextFinderAction sender  # rename
  end
  # FIXME this doesn't get invoked when find bar is first responder.
end  




class FindPlugin < WebBuddyPlugin
  include FilesystemAccess

#= plugin methods

  # inject the injectee component.
  def load_view
    # disabled: don't need js after cracking NSTextFinder integration.
    # if client.browser_vc.eval_js 'return (window.jQuery == null)'
    #   jquery_content = load "docroot/plugins/js/jquery-1.7.1.min.js", :app_support
    #   client.browser_vc.eval_js jquery_content
    # else
    #   pe_log "jquery already loaded."
    # end

    # find_script = load 'docroot/plugins/injectees/find.js', :app_support
    # client.browser_vc.eval_js find_script
  end
  

  def on_setup
    setup_ns_text_finder
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
  end

  def on_TextFinderAction(sender)
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

      # web_view.accepts_first_responder = false


      @dom_range = nil
      @find_index = 0

    when NSTextFinderActionSetSearchString

    when NSTextFinderActionNextMatch
      pe_log "find: next match"
      @action_type = :next_match 

      # options = NSCaseInsensitiveSearch
      # @dom_range = web_view.DOMRangeOfString(find_input, relativeTo:@dom_range, options:options)
      # update_index 1

      web_view.searchFor(find_input, direction:true, caseSensitive:false, wrap:true, startInSelection:true)

    when NSTextFinderActionPreviousMatch
      pe_log "find: previous match"
      @action_type = :previous_match

      options = NSCaseInsensitiveSearch|NSBackwardsSearch
      @dom_range = web_view.DOMRangeOfString(find_input, relativeTo:@dom_range, options:options)
      update_index -1
      
    when NSTextFinderActionHideFindInterface
      pe_log "find: hide interface"
      @action_type = nil

      clear_highlights

      # NOTE not called.

    end

    # pass on to the text finder.
    @text_finder.performAction(tag)
  end

  def update_index delta
    new_val = @find_index + delta

    case new_val
    when match_ranges.size
      new_val = 0
    when -1
      new_val = match_ranges.size - 1
    end

    @find_index = new_val
  end


#= NSTextFinderClient methods

  def string
    p "string request"

    ## JS
    # search_content = self.client.browser_vc.eval_js 'return document.documentElement.innerText'

    # FIXME not compatible with dynamic content, e.g. google instant: periodically re-request.

    ## NATIVE
    web_view.mainFrame.frameView.documentView.string
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
    @selected_range || NSMakeRange(0, 0)
  end

  def scrollRangeToVisible(range)
    p "TODO scroll to #{range}"
    
    # hold onto the range so firstSelectedRange can use it for next / previous actions.
    @selected_range = range

    # searchFor('the', direction:true, caseSensitive:false, wrap:true) does the scrolling. 

    web_view.scrollDOMRangeToVisible(@dom_range)
  end

  # this is called on incremental search
  def contentViewAtIndex(index, effectiveCharacterRange:range)
    
    p "view request for index  #{index}"
    
    range[0] = NSMakeRange(0, self.string.length)

    self.web_view
  end

  # this delegate method is necesary to display text find indicators.
  def rectsForCharacterRange(range)
    p "rects request for #{range}"

    # range is the current find match.

    (@adapter ||= WebViewAdapter.new).markText(find_input, forWebView:web_view)
    rects = web_view.rectsForTextMatches  # NOTE this only returns rects within viewable area.

    # scrolling / highlighting the 'current' find match:
    # get dom range for current_match. ##
    # ask webview to scroll.

    # i = match_ranges.index NSValue.valueWithRange(range)
    # if i
    #   current_rect = rects[i]
    #   if current_rect
    #     web_view.scrollRectToVisible(current_rect.rectValue)
    #   end
    # end
    # NOTE doesn't work because rectsForTextMatches only returns visible rects.

    rects

    # FIXME to get accurate 'current match' rendering, need to return element corresponding to find index, then offset by number of items not visible. 
  end

  # def visibleCharacterRanges
  #   p "visible char range request"

  #   # stub seems to work fine.
  #   [ NSValue.valueWithRange(NSMakeRange(0,100)) ]
  # end

  def drawCharactersInRange(range, forContentView:view)
    # but this is not useful. we need to solve the nsrange -> domrange conversion.
    # it does seem to draw a yellow gradient fill.
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

  def match_ranges
    @text_finder.incrementalMatchRanges
  end
end



class NSRange
  def to_s
    self.inspect
  end
end
