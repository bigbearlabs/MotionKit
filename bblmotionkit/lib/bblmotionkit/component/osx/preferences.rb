module Preferences

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
    yield pane
    pane

    # TODO label the pane with the name.
  end

  def new_pref_view( component_class )
    component = self.component(component_class)

    defaults_spec = component.defaults
    defaults_spec.keys.map do |default|
      pref_spec = defaults_spec[default][:preference_spec]
      if pref_spec
        case pref_spec[:view_type]
        when :boolean
          view = NSBundle.load_nib 'BooleanPreference', {
            checkbox: 101
          }

          # set label
          view.subview(:checkbox).title = pref_spec[:label]
          # set default value
          view.subview(:checkbox).state = component.default default

          return view
          # TODO sizing
        when :list
          raise "view_type:list unimplemented"
        end
      end
    end
  end


  # FIXME replace this with a mechanism to always display up-to-date defaults with e.g. hotkey.
  def handle_Preference_updated_notification( notification )
    # TODO check if display set changed, process window frame as necessary

    self.update_toggle_menu_item
  end
  
  #= app-specific

  def preference_panes
    obj = 
      new_pref_pane :general do |pane|
        pane.add_view( new_pref_view DefaultBrowserHandler)
        # pane.add_view new_pref_view BrowserDispatch
      end
    [ obj ]
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
    @top_level_objs_pointer = Pointer.new '@'
    @top_level_objs_pointer[0] = []
    loaded = NSBundle.mainBundle.loadNibNamed(nib_name, owner:self, topLevelObjects:@top_level_objs_pointer)

    raise "failed to load #{nib_name}" unless loaded

    # the 2nd element of the tlo array is the one we want in the nib.
    first_tlo = @top_level_objs_pointer[0][1]
    @top_level_objs_pointer = nil

    if tag_defs
      first_tlo.tag_defs = tag_defs
    end

    first_tlo
  end
  
end


class NSView
  attr_accessor :tag_defs

  def subview( tag_symbol )
    tag = tag_defs[tag_symbol]
    raise "no tag defined for #{tag_symbol}" if tag.nil?
    view = self.viewWithTag(tag)
    raise "no subview tagged #{tag_symbol}" if view.nil?
    view
  end
end