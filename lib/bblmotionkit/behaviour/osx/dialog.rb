module DialogPresenter

  def show_dialog( details )
    pe_trace

    self.show_sheet details[:message] do
      pe_trace
      details[:confirm_handler].call
    end
  end

  def presenter_window
    self.view.window
  end
  

  def show_sheet( message, &confirm_handler )
    sheet_window_controller ||= DialogSheetController.alloc.init 
    sheet_window_controller.message = message
    sheet_window_controller.on_confirm = confirm_handler

    @sheet_state = { handler: confirm_handler, controller: sheet_window_controller }
    # NSApp.beginSheet(sheet_window_controller.window, modalForWindow:self.window, modalDelegate:sheet_window_controller, didEndSelector:nil, contextInfo:nil)
    self.presenter_window.beginSheet(sheet_window_controller.window, completionHandler:-> {

    })

  end

end



class DialogSheetController < NSWindowController
  include Reactive

  attr_accessor :message

  attr_accessor :message_field

  def init
    initWithWindowNibName('DialogSheet')

    react_to :message , :message_field do
      @message_field.stringValue = @message if @message_field
    end

    self
  end


#= ui ops.

  attr_accessor :on_confirm

  def handle_modal_confirm( sender )
    dismiss_sheet
    
    NSApp.delegate.deactivate_viewer_window
    
    on_confirm.call 
  end

  def handle_modal_cancel( sender )
    dismiss_sheet
  end

  def dismiss_sheet
    self.window.orderOut(self)
  end
  
end


