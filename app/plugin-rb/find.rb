motion_require '../legacy/WebBuddyAppDelegate'

## feature integration.
class WebBuddyAppDelegate < MotionKitAppDelegate

  # when input field is first responder, unwanted menu validation early in the responder chain disables the find menu item. work around by adding the find method on appd.
  def performTextFinderAction(sender)
    pe_debug "#{sender} invoked text finder action"
    
    NSApp.key_window.controller.component(FindPlugin).on_TextFinderAction sender
  end
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

  def perform_find( string, options = {} )
    forward = options[:forward]
    forward = true if forward.nil?

    case_sensitive = self.case_sensitive?
    wrap = true

    # patch field editor to hold onto first responder status so webview's find method can't snatch it.
    if ! @field_editor_patched
      field_editor = @text_finder.search_field.field_editor
      if field_editor
        class << field_editor
          attr_accessor :should_resign
          def resignFirstResponder
            @should_resign.nil? ? super : should_resign
          end
        end

        @field_editor_patched = true
      end
    end

    field_editor_shown = @text_finder.search_field.field_editor
    @text_finder.search_field.field_editor.should_resign = false if field_editor_shown

    (@adapter ||= WebViewAdapter.new).findString(string, forward:forward, caseSensitive:case_sensitive, wrap:wrap, inWebView:web_view)
    # CASE nil selectedDOMRange.

    @text_finder.search_field.field_editor.should_resign = true if field_editor_shown


  end

#= system integration: osx text finder

  def setup_ns_text_finder
    @text_finder = NSTextFinder.alloc.init
    @text_finder.client = self
    @text_finder.incrementalSearchingEnabled = true
    @text_finder.incrementalSearchingShouldDimContentView = true

    # wire webview's scroll view as find bar container.
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

      @dom_range = nil
      @find_index = 0

    when NSTextFinderActionSetSearchString
      p "find: set search string"

    when NSTextFinderActionNextMatch
      pe_log "find: next match"
      @action_type = :next_match 

      perform_find find_input

    when NSTextFinderActionPreviousMatch
      pe_log "TODO find: previous match"
      @action_type = :previous_match

      perform_find find_input, forward: false
      
      
    else
      pe_log "find: got #{tag}"

      @action_type = nil

    end

    # pass on to the text finder.
    @text_finder.performAction(tag)

    # ensure responder chain priority so we received the finder actions.
    on_main_async do
      if scroll_view.isFindBarVisible
        @action_relayer ||= ActionRelayer.new

        scroll_view.window.firstResponder.insert_responder @action_relayer
      end
    end

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

    # use this point to trigger actions on webview when incrementally typing into find field.
    previous_find_input = @find_input
    @find_input = find_input
    if @find_input != previous_find_input
      perform_find @find_input
    else
      # no incremental search to perform.
    end

    # TODO reset state on cancel.
  end

  # this is called on incremental search
  def contentViewAtIndex(index, effectiveCharacterRange:range)
    
    p "view request for index  #{index}"
    
    range[0] = NSMakeRange(0, self.string.length)

    self.web_view
  end

  # this delegate method is necessary to display text find indicators.
  # range: the current find match.
  def rectsForCharacterRange(range)
    p "rects request for #{range}"

    (@adapter ||= WebViewAdapter.new).markText(find_input, forWebView:web_view)
    rects = web_view.rectsForTextMatches  

    rects

  end

  # def visibleCharacterRanges
  #   p "visible char range request"

  #   # stub seems to work fine.
  #   [ NSValue.valueWithRange(NSMakeRange(0,100)) ]
  # end

  # TODO draw the text in this method in order to get platform-provided find indicator.
  # def drawCharactersInRange(range, forContentView:view)
  #   # but this is not useful. we need to solve the nsrange -> domrange conversion.
  #   # it does seem to draw a yellow gradient fill.
  # end

#= props

  def find_input
    find_pboard.stringForType('public.utf8-plain-text')
  end

  def web_view
    # TACTICAL
    client.browser_vc.web_view
  end

  def scroll_view
    client.browser_vc.view.views_where {|e| e.is_a? NSScrollView}.flatten.first
  end

  def match_ranges
    @text_finder.incrementalMatchRanges
  end

  def find_pboard
    NSPasteboard.pasteboardWithName(NSFindPboard)
  end

  def case_sensitive?
    pboard_settings = find_pboard.pasteboardItems[0].propertyListForType('com.apple.cocoa.pasteboard.find-panel-search-options')

    pboard_settings[NSFindPanelCaseInsensitiveSearch] == false
  end
end



class ActionRelayer < NSResponder
  def performTextFinderAction(sender)
    NSApp.delegate.performTextFinderAction(sender)
  end
end




class NSTextFinder
  def search_field
    findBarContainer.findBarView.views_where {|v| v.kind_of? NSFindPatternSearchField }.flatten.first
  end
end




class NSRange
  def to_s
    self.inspect
  end
end
