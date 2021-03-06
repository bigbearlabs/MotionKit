module Accessibility
  def self.trusted
    AXIsProcessTrusted()
  end

  def self.trusted_presenting_dialog
    AXIsProcessTrustedWithOptions( { KAXTrustedCheckOptionPrompt => true})
  end
  
  def self.api_enabled
    AXAPIEnabled()
  end
  
  def self.ask_if_needed
    if trusted
      pe_log "AXIsProcessTrusted() returned true"
    else
      pe_log "AXIsProcessTrusted() returned false; presenting dialog"
      trusted_presenting_dialog
    end
  end
  


  # module ClassMethods
  # end
  
  # module InstanceMethods
  # end
  
  # def self.included(receiver)
  #   receiver.extend         ClassMethods
  #   receiver.send :include, InstanceMethods
  # end
end