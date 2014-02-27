module JsEval

  # TODO generalise
  def load_js_lib( lib )
    case lib
    when :jquery
      file_name = "plugins/js/jquery-1.7.1.min.js"
      condition_js = 'return (window.jQuery == null)'
    else
      raise "js lib #{lib} unimplemented"
    end

    if eval_js condition_js
      eval_js_file file_name
    else
      pe_log "'#{condition_js}' returned false, not loading #{lib}"
    end
  end
  
  def eval_js_file file_name
    js_content = js_content file_name
    result = self.eval_js js_content, "contents of #{file_name}"
    pe_log "#{file_name} loaded."
    result
  end
  

  # FIXME depends on json2/cycle.js
  def eval_expr( single_line_expr, description = 'anonymous expression' )
    result = eval_js %(
      return JSON.stringify(
        JSON.decycle(
          #{single_line_expr}
        )
      );
    ), description
    result = nil if result.starts_with "#<WebUndefined:"

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
    
      raise result.description + " for #{script_description}" if result.description.starts_with? 'JS Exception: '

      result
    end
  end

  # handler defines methods called back from js.
  def register_callback_handler property, handler       
    objc_interface_obj = DOMToObjcInterface.alloc.initWithCallbackHandler handler
    
    set_window_property property, objc_interface_obj
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
    # docroot = default server.docroot  # TODO move 
    docroot = "#{NSApp.app_support_path}/docroot"

    File.read "#{docroot}/#{file_name}"
  end
  

  #= module boilerplate

  module ClassMethods
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
  end
end