module JsEval

  # TODO generalise
  def load_js_lib
    file_names = [ "plugin/assets/js/jquery-1.7.1.min.js", "plugin/assets/js/jquery.search.js" ]
    file_names.each do |file_name| 
      eval_js_file file_name
    end

    # TODO check if load really necessary
    # window.jQuery || load_it
    # FIXME somehow optimise the invocation frequency, e.g. once per page
  end
  
  def eval_js_file file_name
    js_src = NSBundle.mainBundle.content( file_name )
    self.eval_js js_src, "contents of #{file_name}"
    pe_log "#{file_name} loaded."
  end
  
  def eval_expr single_line_expr
    eval_js "
      return JSON.stringify(
        JSON.decycle(
          #{single_line_expr}
        )
      );
    "
  end
  
  # call with a return statement at the end of the js to ensure a value back.
  def eval_js( script_string, script_description = "'#{script_string[0..60]}...'" )

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
#   if obj.is_a? NSDictionary
#     obj = obj.dup.to_stringified
#   end

    window_obj = @web_view.windowScriptObject
    window_obj.setValue(obj, forKey:property)
    pe_log "set #{property} on DOM window to #{obj}. url: #{self.url}"
  end
  

  #= module boilerplate

  module ClassMethods
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
  end
end