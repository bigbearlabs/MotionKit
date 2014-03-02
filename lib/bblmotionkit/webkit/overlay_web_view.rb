# REFACTOR decouple from the webview to make a proper decorator.
class OverlayWebViewController < BrowserViewController
  extend IB

  outlet :frame_view


  outlet :overlay_close_button


  def action_overlay_close( sender )
    self.view.hidden = true
  end

  def action_overlay_show( sender )
    self.view.hidden = false
  end


  def load_url_in_overlay( url )
    self.view.hidden = false

    self.load_url url
  end

  def view_shown?
    ! self.view.hidden
  end

  def setup
    # REFACTOR push up
    @frame_view.addSubview self.view
    self.view.fit_superview

    self.data_handler = self
  end
end