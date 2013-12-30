class WebView
  def init args = {}
    frame = args[:frame]
    frame_name = args[:frame_name]
    group_name = args[:group_name]
    obj = self.initWithFrame frame, frameName:frame_name, groupName:group_name

    url = args[:url]
    if url
      obj.mainFrameURL = url
    end

    obj
  end

  def url
    self.mainFrameURL.copy
  end

  def delegate
    # TODO ensure all delegates point to same instance

    self.frameLoadDelegate
  end
end

