
# adapted from WebBuddy with tactical modifications.
# FIXME resolve delta from WebViewDelegate.rb since migration.
class BBLWebViewDelegate

  # a running history 
  attr_reader :events
  attr_reader :redirections

  attr_reader :state
  attr_reader :url
  attr_reader :title

  attr_accessor :web_view  

  attr_accessor :success_handler
  attr_accessor :fail_handler

  attr_accessor :policies_by_pattern

  def setup   
    @events = []

    @policy_error_handler = -> url {
    }

    # watch_notification WebHistoryItemChangedNotification
  end

#= event logging

  def push_event( event_name, event_data = {} )
    @url = @web_view.url
    redirection = @url

    # keep track of the events.
    event = {
      url: @url,
      name: event_name,
      data: event_data
    }

        
    pe_debug "webview event: #{event}"
    @events << event

    # optional specific handling of events.
    begin
      case event_name
      when 'decidePolicyForNavigation'

        #         WebNavigationTypeFormSubmitted,
        #         WebNavigationTypeBackForward,
        #         WebNavigationTypeReload,
        #         WebNavigationTypeFormResubmitted,
        #         WebNavigationTypeOther

        action = event_data[:action_info][WebActionNavigationTypeKey]
        pe_debug "decidePolicyForNavigation #{event_data} : action is #{action}."
        case action
        when WebNavigationTypeLinkClicked
          pe_debug "link nav."
          debug( {msg: "link nav", data: event_data})

          send_notification :Link_navigation_notification, event_data[:url]
          # FIXME this doesn't cover all link navs - e.g. google search result links emit WebNavigationTypeOther, probably due to ajax-based loading.
        end
      
      when 'willSendRequestForRedirectResponse'
        kvo_change :url do
          @url = @url  # value is already updated.
        end

        # collect the 'from' url.
        self.add_redirect redirection  # can this be empty?

      when 'didStartProvisionalLoad'
        pe_log "#{@url} started provisional load"
 
        kvo_change :state do
          @state = :loading
        end
        kvo_change :url do
          @url = @url
        end
       
        self.prep_load @url

        send_notification :Load_request_notification, @url

        # TODO integrate with cancels.

      when 'didCommitLoad', 'didChangeLocationWithinPage'
      
      when 'didFinishLoadingResource'

      when 'didReceiveTitle'
        kvo_change :title do
          @title = event_data[:title]
        end

        send_notification :Title_received_notification, { 
          url: @url, title: event_data[:title] 
        }

      when 'didFinishLoadMainFrame'
        kvo_change :state do
          @state = :loaded
        end

        send_notification :Url_load_finished_notification, @url

        @success_handler.call @url if @success_handler
        @success_handler = nil
        @fail_handler = nil  # FIXME this seems to cause thread-unsafe conditions.

        if $DEBUG
          pe_warn "finished loading #{@url}. events: #{@events}"
        end
        
      when 'provisionalLoadFailed', 'loadFailed'
        kvo_change :state do
          @state = :failed
        end

        pe_log event

        if @fail_handler
          @fail_handler.call @url
        else
          pe_warn "no fail handler set for #{@url}"
        end

        @success_handler = nil
        @fail_handler = nil

      end

    rescue Exception => e
      pe_report e, "while handling WebView events."
      pe_log "event log: #{event}"
    end
    
  end
  
  
#=

  def prep_load url
    pe_trace

    # clear the events.
    @events.slice! 1..-1 unless $DEBUG

    @redirections = []
  end

  def add_redirect new_url
    if @redirections.last != new_url
      kvo_change :redirections do
        @redirections << new_url
      end
    end
  end

  # FIXME test this with many cases. what a pain
  def redirect_info
    "#{@url}: #{@redirections}"
  end

#= http lifecycle

  def webView(webView, didStartProvisionalLoadForFrame:frame)
    if frame == webView.mainFrame
      self.push_event 'didStartProvisionalLoad',
        new_url: webView.url
    end
  end
  
  def webView(webView, identifierForInitialRequest:request, fromDataSource:dataSource)
    pe_debug  "initial request: #{request.description}, for mainFrameURL #{webView.url}"
    
    # this method invoked per every http request, not every page request.
    
    request
  end
  
  def webView(webView, resource:identifier, willSendRequest:request, redirectResponse:redirectResponse, fromDataSource:dataSource)
    response_url = 
      unless redirectResponse.nil?
        redirectResponse.URL.absoluteString
      else
        nil
      end

    new_url = request.URL.absoluteString

    # page redirects have response_url equal to url and a different new_url.
    if response_url
      self.push_event 'willSendRequestForRedirectResponse', { new_url: new_url, response_url: response_url }
    end

    request
  end
  
  def webView( webView, didReceiveTitle:title, forFrame:frame )
    pe_debug "received title #{title}"

    if frame == webView.mainFrame
      self.push_event 'didReceiveTitle', { title: title }
      

       # if TitleBlackList.include? title
       # pe_log "skipping title=#{title} as it's blacklisted"
       # return
       # end

    end
  end

  def webView(webView, didCommitLoadForFrame:frame)
    # data started arriving.
    if frame == webView.mainFrame
      self.push_event 'didCommitLoad'
    end
  end
  
  def webView(webView, didClearWindowObject:windowObject, forFrame:frame)
    if frame == webView.mainFrame
      # presumably this is invoked after the page is made available, but before all network traffic has cleared.
      
      # notify this fact so e.g. overlays can be hidden.
      
      self.push_event 'didClearWindowObject'
    end
  end
  
  def webView(webView, resource:resource, didFinishLoadingFromDataSource:dataSource)
    # for ajax requests that update the bflist, i.e. semantically a 'next page'.
    # if back history item matches with current item container, must push another item container.
    # FIXME just pushing won't do, it needs to look for a matching item first.
    # RELOCATE
    # if self.back_forward_list_moved
    #   context.add_access webView.backForwardList.currentItem.URLString, :enquiry => input_field_vc.current_enquiry
    #       context.update_detail webView.url, :thumbnail => webView.image
    # end
    
    self.push_event 'didFinishLoadingResource', 
      resource: resource
  end
  
  def webView(webView, didFinishLoadForFrame:frame)    
    if frame == webView.mainFrame
      self.push_event 'didFinishLoadMainFrame'
      
    end
  end

#= anchor navigation

  def webView(webView, didChangeLocationWithinPageForFrame:frame)
    self.push_event 'didChangeLocationWithinPage'
  end
  
#= redirects
  
  def webView(webView, willPerformClientRedirectToURL:url, delay:seconds, fireDate:date, forFrame:frame)
    # this is a good hook to deal with history cleanup issues on redirect.
    if frame == webView.mainFrame
      self.push_event 'willPerformClientRedirect', { new_url: url.absoluteString }
    end
  end
  
  def webView(webView, didCancelClientRedirectForFrame:frame)
    if frame == webView.mainFrame
      self.push_event 'didCancelClientRedirect'
    end
  end
  
  def webView(webView, didReceiveServerRedirectForProvisionalLoadForFrame:frame)
    # likewise.
    if frame == webView.mainFrame
      self.push_event 'didReceiveServerRedirect'
    end
  end


#= script handling

  def webView(webView, createWebViewWithRequest:request)
    self.push_event 'createWebViewWithRequest', new_request: request
    
    return webView

    # TEMP create a new webview.
    # superview = @browser_vc.view
    # new_web_view = WebView.alloc.initWithFrame(superview.bounds, frameName:"stub_new_web_view", groupName:@web_view.groupName)
    # superview.addSubview new_web_view

    # new_web_view
    # EDGE-CASE BUG gmail creates a new tab with an empty request, that doesn't finish if we return the existing web view.
    # suggested workaround is to load it in a new web view, then re-request the url on the old web view and pray for a cache hit.
  end

  def webViewShow(webView)
    self.push_event "webViewShow"

    # called after webView:createWebViewWithRequest:
    # nothing to do here.
  end

#= policy
  
  def webView(webView, decidePolicyForNewWindowAction:actionInformation, request:request, newFrameName:frameName, decisionListener:listener)    
    self.push_event 'decidePolicyForNewWindow', { action_info: actionInformation }
    
    listener.use
  end
  
  def webView(webView, decidePolicyForNavigationAction:actionInformation, request:request, frame:frame, decisionListener:listener)
    if frame == webView.mainFrame
      self.push_event 'decidePolicyForNavigation', { 
        action_info: actionInformation, 
        url: (actionInformation[WebActionOriginalURLKey] ? 
          actionInformation[WebActionOriginalURLKey].absoluteString :  # hoping this is the destination url
          'no WebActionOriginalURLKey') ,
        request: request
      }
    end
   
    # listener.use

    apply_policy request.URL.absoluteString, listener
  end

  #= nav policy

  def apply_policy( url, decision_listener )
    if @policies_by_pattern
      @policies_by_pattern.keys.map do |pattern|
        if url =~ pattern
          matching_policy = @policies_by_pattern[pattern]
          case matching_policy
          when Proc
            matching_policy.call url, decision_listener
          when :load
            decision_listener.use
          when :ignore
            pe_log "policy for #{url}: ignore"
            decision_listener.ignore
          end

          return
        end
      end
    end

    pe_log "no matching policy for #{url}, using default policy"
    decision_listener.use
  end
  
#=

  # prevents js resizing of window hosting webview 
  def webView(sender, setFrame:frame)
     #ignore
  end

  def webViewClose(sender)
    #ignore
  end


  def webViewIsResizable
    false
  end
  
#= mime type handling

  def webView(webView, decidePolicyForMIMEType:mimeType, request:request, frame:frame, decisionListener:listener)
    self.push_event 'policyForMimeType', { mimeType: mimeType }

    if WebView.canShowMIMEType(mimeType)
      listener.use
    else
      listener.download
    end
    
  end

#= misc

  def webView(webView, unableToImplementPolicyWithError:error, frame:frame)
    pe_warn "unable to implement policy. #{error.description}"

    url = error.userInfo['NSErrorFailingURLStringKey']

    self.push_event 'policyImplError', { error: error, url: url }

    @policy_error_handler.call url
  end

  def webView(webView, didFailProvisionalLoadWithError:err, forFrame:frame)
    self.push_event 'provisionalLoadFailed'
  end

  def webView(webView, didFailLoadWithError:err, forFrame:frame)
    self.push_event 'loadFailed'
  end

end


