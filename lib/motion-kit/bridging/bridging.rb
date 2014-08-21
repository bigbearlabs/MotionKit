def breakpoint(*args)
  ObjcRMBridge.breakpoint(*args)
end


class ObjcRMBridge
  def self.invoke(method, params:params)
    puts "TODOTODO #{method}, #{params}"

    # case: viewDidLoad on action extension's view controller
  end
  
  def self.wire(subject)
    # PoC with action view controller.
    subject.extend ActionViewControllerExtension
  end
end



module ActionViewControllerExtension
  def viewDidLoad
    super

    puts "TODO viewDidLoad!!"

    breakpoint self.extensionContext.inputItems

    # POC set up a motion-kit component inside an action extension vc.
    @web_vc = WebViewController.new
    @web_vc.view.frame = self.imageView.frame
    self.view.addSubview @web_vc.view
    @web_vc.load_url 'http://google.com'


    # attachments[0].loadItemForTypeIdentifier(kUTTypeURL as NSString, options:nil, completionHandler: {
    #     obj, error in
    #     if error {
    #         println("Unable to add as a URL")
    #     }
    #     else if let url = obj as? NSURL {
    #         URLQueue.addURL(url, title:self.textView.text)
    #     }
    #     self.extensionContext.completeRequestReturningItems(nil, completionHandler: nil)
    # })

    self.extensionContext.inputItems.each do |item|
      # item.attachments[0].loadItemForTypeIdentifier(KUTTypeURL, options:nil, completionHandler: lambda {
      #     |obj, error|
      #     if error
      #       println("Unable to add as a URL")
      #     elsif url = obj
      #       puts "!! url: #{url}"
      #     end
      # })

      item.attachments[0].loadItemForTypeIdentifier(KUTTypePropertyList, options:nil, completionHandler: lambda {
          |obj, error|
          if error
            raise "Unable to add as a page"
          else
            puts "got obj: #{obj}"
            puts obj[NSExtensionJavaScriptPreprocessingResultsKey]['document']
          end

          nil
      })    
    end
  end
end
