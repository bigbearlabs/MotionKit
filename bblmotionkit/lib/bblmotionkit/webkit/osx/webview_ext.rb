class WebView
  def self.new(args = {})
    frame = args[:frame] || NSZeroRect
    frame_name = args[:frame_name]
    group_name = args[:group_name]
    view = self.alloc.initWithFrame frame, frameName:frame_name, groupName:group_name

    if url = args[:url]
      view.mainFrameURL = url
    end

    view
  end

  def url
    self.mainFrameURL.copy
  end

  def delegate
    # TODO ensure all delegates point to same instance

    self.frameLoadDelegate
  end

  def bf_list
    backForwardList
  end
  
  def make_first_responder
    self.views_where {|e| e.is_a? WebHTMLView}.flatten.first.make_first_responder
  end
  
end

class WebBackForwardList
  def index(url)
    bf_list_size = self.forwardListCount + self.backListCount
    (bf_list_size + 1).times do |i|
      index = self.forwardListCount - i
      history_item = self.itemAtIndex index
      if history_item.originalURLString.isEqual url.absoluteString
        pe_log  "returning index #{index} for url #{url.description}"
        return index
      end
    end

    nil
  end

  def head
    return "current: #{currentItem.description}, back: #{backItem.description}"
  end

  def current_page
    currentItem
  end

  def back_page
    backItem
  end
  
  def forward_page
    forwardItem
  end
end

class WebHistoryItem
  attr_accessor :thumbnail
end


