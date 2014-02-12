# TODO reconcile postflight proc, calls to on_setup, another call to on_update.

module Preferences

#= app-specific

  # TODO sizing
  def preference_pane_controllers flavour
    [ 
      GeneralPrefPaneController.alloc.initWithViewFactory(self),
      # DeveloperPrefPaneController.alloc.initWithViewFactory(self),
    ].tap do |a|
      if flavour == :dev || RUBYMOTION_ENV == 'development'
        a << PreviewPrefPaneController.alloc.initWithViewFactory(self)
      end
    end
  end
  
#=

  def new_pref_window(sender)
    flavour =  
      if (sender.respond_to?(:tag) && to_sym(sender.tag) == :menu_item_prefs_DEV) or (default :show_preview_prefs)
        :dev
      else
        :standard
      end

    @prefs_window_controller.close if @prefs_window_controller

    @prefs_window_controller = PreferencesWindowController.new(
      self.preference_pane_controllers flavour
    )

    @prefs_window_controller.showWindow(self)
    @prefs_window_controller.window.makeKeyAndOrderFront(self)

    pe_log "pref window activated. frame: #{@prefs_window_controller.window.frame.inspect}"
    # we need this in order to avoid the window opening up but failing to catch the user's attention.
    NSApp.activate
  end

  def new_pref_section( pref_owner )
    if pref_owner.is_a?(Class) && pref_owner.ancestors.include?(BBLComponent)
      pref_owner = self.component pref_owner
    end

    defaults_spec = pref_owner.defaults_spec

    views = defaults_spec.map do |default, val|
      pref_spec = val[:preference_spec]

      case pref_spec[:view_type]
      when :boolean
        new_boolean_preference_view default, pref_spec, pref_owner
      when :list
        new_list_preference_view default, pref_spec, pref_owner
      end
      .tap do |view|
        # watch for default specified by :depends_on and update state.
        if super_default = val[:depends_on]
          update_visible = -> v, enabled {
            v.views_where {|e| e.is_a? NSControl}.flatten.map do |control|
              control.enabled = enabled
            end
          }
          
          pref_owner.client.watch_default super_default do |key, new_val|
            update_visible.call view, new_val
          end

          update_visible.call view, pref_owner.client.default( super_default)
        end
      end
    end

    pref_section = NSBundle.load_nib 'PreferenceSection'
    pref_section.add_view *views
    pref_section.size_to_fit
    # reposition the subviews after the resize.
    pref_section.add_view *views

    pref_section
  end

  def new_boolean_preference_view default, pref_spec, component
    view = NSBundle.load_nib 'BooleanPreference', {
      checkbox: 101
    }
    checkbox = view.subview(:checkbox)
    checkbox.title = pref_spec[:label]
    checkbox.state = component.default(default) ? NSOnState : NSOffState
    checkbox.on_click = proc do
      new_val = (checkbox.state == NSOnState)

      # set the default.
      component.update_default default, new_val
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


class NSBox
  def size_to_fit
    self.sizeToFit
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

  def subview( tag_symbol_or_number )
    if tag_symbol_or_number.is_a? Numeric
      tag = tag_symbol_or_number
    else
      tag_symbol = tag_symbol_or_number
      tag = tag_defs[tag_symbol]
    end

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
    pane.translatesAutoresizingMaskIntoConstraints = false
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
    self.view.size_to_fit
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
  

end

# work around annoying layout anomaly
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
      @factory.new_pref_section(DefaultBrowserHandler), 
      @factory.new_pref_section(BrowserDispatch)
    ]
  end

  def initWithViewFactory(factory)
    # load with nib
    self.init

    @factory = factory

    self.preference_views.each_with_index do |pref_view, i|
      self.view.subviews[i].add_view pref_view
      pref_view.centre_horizontal
    end

    self
  end

  # override resizing in PreferencePaneViewController
  def viewWillAppear
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
      @factory.new_pref_section(HotkeyHandler), 
      @factory.new_pref_section(WindowPreferenceExposer), 
      @factory.new_pref_section(ContextLoader)
    ]
  end
end

  
class DeveloperPrefPaneController < PreferencePaneViewController
  # MASPreferences interface compliance
  def identifier
    'Developer'
  end
  def toolbarItemLabel
    'Developer'
  end

  def preference_views
    [
      @factory.new_pref_section(WebViewPreferenceExposer.new), 
    ]
  end
end


# expose defaults on BrowserWindowController as preferences and bridge data flow.
class WindowPreferenceExposer < BBLComponent
  def on_setup
    
  end
  
  def defaults_spec
    {
      handle_focus_input_field: {
        postflight: -> val {
          if val
            self.client.wc.handle_focus_input_field self
          else
            self.client.wc.handle_hide_input_field self
          end
        },
        preference_spec: {
          view_type: :boolean,
          label: "Input Field",
        }
        # MAYBE post_register to specify actions after defaults registered.
        # MAYBE initial val
      },

      # migrate to another pref pane.

    }
  end

  # override and insert the segment that maps to wc.
  def full_key key = nil
    full_key = "ViewerWindowController"
    full_key += ".#{key}" if key
    full_key
  end

end


# WIP
class WebViewPreferenceExposer

  def on_setup
  end

  def defaults_spec
    {
      inspector: {
        postflight: -> val {
        },
        preference_spec: {
          view_type: :boolean,
          label: "Web Inspector"
        }
      },
      inspector: {
        postflight: -> val {
        },
        preference_spec: {
          view_type: :text,
          label: "User Agent String"
        }
      }
    } 
  end
      
end