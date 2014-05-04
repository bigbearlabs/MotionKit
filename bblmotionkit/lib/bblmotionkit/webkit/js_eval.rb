module JsEval
  
  # FIXME depends on json2/cycle.js
  def eval_expr( single_line_expr, description = 'anonymous expression' )
    result = eval_js %(
      return JSON.stringify(
        JSON.decycle(
          #{single_line_expr}
        )
      );
    ), description
    result = nil if result.start_with? "#<WebUndefined:"

    result
  end
  

  # call with a return statement at the end of the js to ensure a value back.
  def eval_js( script_string, script_description = "'#{script_string[0..80]}...'" )

    # wrap script in a try block to get the error back if any.
    script_string = %(
      var __result = function() {
        try {
          #{script_string}
        } catch (e) {
          // return the exception in a compatible way.
          return "JS Exception: " + e.toString();
        }
      }();

      __result;
    )
    # NOTE by inlining the script string, we lose the ability to retrieve the result of the last expression as with #evaluateWebScript.
 
    pe_debug "script: #{script_string}"

    on_main do
      dom_window = @web_view.windowScriptObject
      result = dom_window.evaluateWebScript(script_string)
    
      if result.is_a? WebUndefined
        pe_log "js returned undefined"
        result = result.to_s
      end

      pe_debug "completed eval_js: #{script_description}"
      pe_debug "eval_results: #{result.description}"
    
      raise result.description + " for #{script_description}" if result.description.start_with? 'JS Exception: '

      result
    end
  end

  #= registering callback handler to dom window

  # handler defines methods called back from js.
  def register_objc_interface handler       
    set_window_property 'objc_interface', handler
  end

  def set_window_property property, obj
    # if obj.is_a? NSDictionary
    #   obj = obj.dup.to_stringified
    # end

    window_obj = @web_view.windowScriptObject
    window_obj.setValue(obj, forKey:property)
    pe_log "set #{property} on DOM window to #{obj}. url: #{self.url}"
  end
  
  #= bookmarklets

  def eval_bookmarklet(content = nil, opts = {})
    if content.nil?
      path = opts[:path]
      pe_log "loading bookmark from #{path}"
      content = js_content path
    end

    content = content.gsub /^javascript:/, ''
    unescaped = content.to_url_decoded
    
    pe_log "ready to eval #{content}"
    eval_js unescaped
  end

  def js_content(file_name)
    File.read file_name
  rescue => e
    pe_report e, "loading file #{file_name}"
  end
  

  #= module boilerplate

  module ClassMethods
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
  end
end