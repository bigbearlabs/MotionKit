module Preferences

#= app-specific

  def preference_panes
    obj = 
      new_pref_pane :general do |pane|
        pane.add_view new_pref_view( DefaultBrowserHandler), new_pref_view(BrowserDispatch)

        # TODO sizing
      end
    [ obj ]
  end
  
#=

  def new_pref_window(sender)
    flavour = case sender.tag
      when @tags_by_description['menu_item_prefs_DEV']
        :dev
      else
        :standard
      end

    @prefs_window_controller ||= PreferencesWindowController.alloc.init.tap do |wc|
      self.preference_panes.map do |pane|
        wc.add_pane pane
      end
    end

    @prefs_window_controller.showWindow(self)
    @prefs_window_controller.window.makeKeyAndOrderFront(self)

    # we need this in order to avoid the window opening up but failing to catch the user's attention.
    NSApp.activate
  end


  def new_pref_pane( name )
    pane = new_view
    pane.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable
    yield pane
    pane

    # TODO label the pane with the name.
  end

  def new_pref_view( component_class )
    component = self.component component_class

    defaults_spec = component.defaults
    defaults_spec.map do |default, val|
      pref_spec = val[:preference_spec]
      if pref_spec
        view = 
          case pref_spec[:view_type]
          when :boolean
            new_boolean_preference_view default, pref_spec, component
          when :list
            new_list_preference_view default, pref_spec, component
          end

        return view
      end
    end
  end

  def new_boolean_preference_view default, pref_spec, component
    view = NSBundle.load_nib 'BooleanPreference', {
      checkbox: 101
    }
    checkbox = view.subview(:checkbox)
    checkbox.title = pref_spec[:label]
    checkbox.state = component.default(default) ? NSOnState : NSOffState
    checkbox.on_click do
      # set the default.
      component.set_default default, (checkbox.state == NSOnState)
      # setup the component.
      component.setup  # FIXME need to distinguish setup and update
    end
    view
  end
  
  def new_list_preference_view default, pref_spec, component
    view = NSBundle.load_nib 'ListPreference', {
      popup_button: 101,
      label: 102
    }
    
    view.subview :popup_button do |popup_button|
      # set items
      popup_button.menu = component.send pref_spec[:list_items_accessor]
      # set selected item
      popup_button.select_value(component.default default)
      # set handler
      popup_button.on_select do |selected_item|
        # set the default.
        component.set_default default, selected_item.value
        # setup the component.
        component.setup
      end
    end

    view.subview :label do |label|
      label.stringValue = pref_spec[:label]
    end

    view
  end
  

  # FIXME replace this with a mechanism to always display up-to-date defaults with e.g. hotkey.
  def handle_Preference_updated_notification( notification )
    # TODO check if display set changed, process window frame as necessary

    self.update_toggle_menu_item
  end
  

end


# tactical wc.
class PreferencesWindowController < NSWindowController
  def init
    self.initWithWindow buildWindow

    self
  end

  def buildWindow
    @mainWindow = NSWindow.alloc.initWithContentRect([[240, 180], [480, 360]],
      styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask,
      backing: NSBackingStoreBuffered,
      defer: false)
    @mainWindow.title = NSBundle.mainBundle.infoDictionary['CFBundleName']
    @mainWindow.orderFrontRegardless

    @mainWindow
  end

  def add_pane pane
    self.window.view.add_view pane
    pane.fit_to_superview
  end
  
end


class NSBundle

  def self.load_nib nib_name, tag_defs = nil
    temp_vc = NSViewController.alloc.initWithNibName(nib_name, bundle:nil)
    first_tlo = temp_vc.view

    if tag_defs
      first_tlo.tag_defs = tag_defs
    end

    first_tlo
  end
  
end


# subview retrieval based on mapping of tag symbols and tags
class NSView
  attr_accessor :tag_defs

  def subview( tag_symbol )
    tag = tag_defs[tag_symbol]
    raise "no tag defined for #{tag_symbol}" if tag.nil?
    view = self.viewWithTag(tag)
    raise "no subview tagged #{tag_symbol}" if view.nil?

    yield view if block_given?

    view
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
  
  def select_value value
    item = self.items.select { |e| e.value == value } [0]
    self.selectItem(item)
  end
end

class NSMenuItem
  def value
    self.representedObject
  end
end