
#= menus

# osx
PlatformMenu = NSMenu

class PlatformMenu
  def initialize( data )
    menu = self.initWithTitle('')
    data.each do |item_data|
      item = new_menu_item item_data[:title], item_data[:proc]
      item.representedObject = item_data[:value]
      item.representedObject ||= item_data

      if item_data.key? :icon
        item.setImage(item_data[:icon])
      end

      menu.addItem(item)

      # recursive call for submenu
      if item_data[:children]
        submenu = new_menu item_data[:children]
        menu.setSubmenu(submenu, forItem:item)
      end
    end

    menu
  end

  # creates a menu item that invokes selection_handler with itself as the proc param when selected.
  def new_menu_item( title = 'stub-title', selection_handler)
    action = 
      if selection_handler
        'handle_menu_item_select:'
      else
        nil
      end

    item = NSMenuItem.alloc.initWithTitle(title, action:action, keyEquivalent:'')

    # work around kvo
    if selection_handler
      def item.selection_handler(handler)
        @selection_handler = handler
      end
      def item.handle_menu_item_select(sender)
        @selection_handler.call item
      end

      item.target = item
    end

    item
  end

  #= test

  def stub_menu_data
    [
      { title: 'item1', proc: -> { pe_log 'item1 clicked' } },
      { 
        title: 'submenu1', 
        children: [
          {
            title: 'item1.1',
            proc: -> { pe_log 'item1.1 clicked' }
          }
        ]
      }
    ]
  end

  def stub_selection_handler item
    p "stub menu item #{item} selected."
  end
  
end