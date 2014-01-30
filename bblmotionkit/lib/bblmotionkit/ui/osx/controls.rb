class NSButton
  attr_reader :on_click

  def on_click=(handler)
    self.target ||= self
    self.action ||= 'handle_click:'

    kvo_change :on_click, handler    
  end

  def handle_click(sender)
    raise "nil handler" unless @on_click

    pe_log "calling handler #{@on_click}"
    @on_click.call sender
  end

  def on_r_click(&handler)
    class << self
      attr_accessor :r_click_handler
      def rightMouseDown(event)
        r_click_handler.call(self, event)
      end
    end
    self.r_click_handler = handler
  end
end

class NSPopUpButton
  def on_select &handler
    @select_handler = handler
    self.target = self
    self.action = 'handle_popup_select:'
  end
  def handle_popup_select(sender)
    @select_handler.call self.selectedItem
  end

  def items
    self.itemArray
  end
  
  def items=(items)
    self.itemArray = items
  end
  
  def select_value value, comparator = nil

    comparator ||= -> a, b {
      # default to simple comparison.
      a == b
    }
    items = self.items.map do |item|
      if comparator.call item.value, value
        item
      else
        nil
      end
    end

    item = items.compact.first
    self.selectItem(item)
  end
end


class NSMenuItem
  def value
    self.representedObject
  end
end

