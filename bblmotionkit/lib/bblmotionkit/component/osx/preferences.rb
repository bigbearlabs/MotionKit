# TODO reconcile postflight proc, calls to on_setup, another call to on_update.

module Preferences

#= app-specific

  # TODO sizing
  def preference_pane_controllers
    [ 
      GeneralPrefPaneController.alloc.initWithViewFactory(self),
      PreviewPrefPaneController.alloc.initWithViewFactory(self)
    ]
  end
  
#=

  def new_pref_window(sender)
    flavour = case sender.tag
      when @tags_by_description['menu_item_prefs_DEV']
        :dev
      else
        :standard
      end

    @prefs_window_controller ||= PreferencesWindowController.new (
      self.preference_pane_controllers
    )

    @prefs_window_controller.showWindow(self)
    @prefs_window_controller.window.makeKeyAndOrderFront(self)

    pe_log "pref window activated. frame: #{@prefs_window_controller.window.frame.inspect}"
    # we need this in order to avoid the window opening up but failing to catch the user's attention.
    NSApp.activate
  end

  def new_pref_view( component_class )
    try do
      component = self.component component_class

      defaults_spec = component.defaults_spec

      views = defaults_spec.map do |default, val|
        pref_spec = val[:preference_spec]
        if pref_spec
          view = 
            case pref_spec[:view_type]
            when :boolean
              new_boolean_preference_view default, pref_spec, component
            when :list
              new_list_preference_view default, pref_spec, component
            end
        end
      end

      pref_view = new_view.add_view *views      
      pref_view.size_to_fit
      # reposition the subviews after the resize.
      pref_view.add_view *views
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
      component.update_default default, (checkbox.state == NSOnState)
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
      popup_button.select_value component.default(default), -> a,b { a.downcase == b.downcase }
      # set handler
      popup_button.on_select do |selected_item|
        # set the default.
        component.update_default default, selected_item.value
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


class PreferencesWindowController < MASPreferencesWindowController
  def initialize( controllers )
    self.initWithViewControllers(controllers)

    self
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


# a view controller that works with a client-instantiated view.
class GenericViewController < PEViewController
  def initWithView( view )
    self.initWithNibName(nil, bundle:nil)
    self.view = view

    pe_log "set #{self}'s view #{view}: #{view.tree}"
    self
  end
end

class PreferencePaneViewController < GenericViewController
  def initWithViewFactory(factory)
    @factory = factory

    pane = new_view
    pane.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable
    pane.add_view *self.preference_views
    pane.arrange_single_column
    pane.size_to_fit
    
    self.initWithView pane
  end

  def toolbarItemImage
    p = Pointer.new '@'
    p[0] = NSImage.imageNamed(NSImageNamePreferencesGeneral)
  end

  # need this to get the views to show up.
  def viewWillAppear
    self.view.arrange_single_column
    pe_log "#{self} resized view: #{self.view.tree}"
  end
  

  # def identifier
  #   "general-preferences"
  # end

  # def toolbarItemLabel
  #   "General"
  # end

  # a way to define properties without def_method so as to allow objc code to call in.
  def def_properties prop_retval_map
    prop_retval_map.map do |prop, retval|
      def_expr = %Q(
        def #{prop}
          pe_trace "#{prop} called, will return #{retval}"
          '#{retval}'
        end
      )
      eval def_expr
    end
  end
  
  # re
  def new_pref_pane_controller( name )
    pane = new_view
    pane.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable
    yield pane

    pe_trace "create pref pane controller for #{name}"

    PreferencePaneViewController.new( pane ).tap do |vc|
      vc.def_properties identifier:name, toolbarItemLabel:name
    end
  end


end

class GeneralPrefPaneController < PreferencePaneViewController
  # MASPreferences interface compliance
  def identifier
    'General'
  end
  def toolbarItemLabel
    'General'
  end

  def preference_views
    [
      @factory.new_pref_view(DefaultBrowserHandler), 
      @factory.new_pref_view(BrowserDispatch)
    ]
  end  
end

class PreviewPrefPaneController < PreferencePaneViewController
  # MASPreferences interface compliance
  def identifier
    'Prerelease'
  end
  def toolbarItemLabel
    'Prerelease'
  end

  def preference_views
    [
      @factory.new_pref_view(HotkeyHandler), 
    ]
  end
end