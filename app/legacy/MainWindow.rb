# motion_require 'pemacrubyinfra/NSWindow_additions'

##
# the main window.
# restoring main window ui state is unreliable without 'anchoring' the app active status to a particularly crafted window, hence the anchor window.
##
class MainWindow < NSPanel
  include WindowEventHandling

  include DefaultsAccess

	#= kvo props
	attr_accessor :active

	attr_accessor :space_anchor_window
	

  def awakeFromNib
    super
  end

  def setup
    # mask_window does the slide in/out activation.
    if default(:animation_style) == "slide"
      setup_mask_window
    end
  end
  
  def setup_mask_window
    @mask_window ||= WBMaskingWindow.alloc.init self.frame
  
    @mask_window.setCollectionBehavior(NSWindowCollectionBehaviorCanJoinAllSpaces)
  
    @mask_window.did_become_key do
      pe_log "mask window became key. app.active:#{NSApp.isActive}, mainwindow.shown:#{self.shown?}"
      if NSApp.isActive && block_self.shown?
        # was put in focus from 'fronting' mode - hand over control to the main window.
        # block_self.makeMainWindow
        #block_self.makeKeyAndOrderFront(self)
        #@mask_window.orderOut(self)
        # block_self.performSelector( 'makeKeyAndOrderFront:', withObject:self, afterDelay:0.1 )
      end
    end
  end

  def show
    self.orderFront(self)
  end
  
  def hide
    # as if it wasn't here.
    self.orderOut(self)
  end
  
  def close
    @mask_window.close if @mask_window
    super
  end

  def do_activate( completion_proc = nil )
    if $DEBUG
      window_info = NSApp.windows.collect { |w| dump_attrs w, :title, :windowNumber, :isVisible }
      pe_log "windows pre-activate: #{window_info}"
    end
    
    # workaround attempt #1 at killing the 'invisible-but-visible window after spaces'.
    self.nudge_frame
    
    if self.shown?
      if self.active?
        # nothing to do here, already active.
      else
        # window is visible and out of focus - just bring to front.
        pe_debug "just bringing main window forward."

        completion_proc.call if completion_proc

        self.really_fucking_focus
      end
    else
      # animate the activation.
      
      completion_handler = -> { 
        on_main do
          window_info = NSApp.windows.collect { |w| dump_attrs w, :title, :windowNumber, :isVisible }
          pe_debug "windows post-activate: #{window_info}"

          completion_proc.call if completion_proc
          
        end
      }

      case default(:animation_style)
      when 'slide'
        self.animate_slide :in, completion_handler
      when 'fade'
        self.animate_fade :in, completion_handler

        # self.orderFrontRegardless
        # self.visible = true
        # completion_handler.call
      else
        raise "unsupported animation style '#{default(:animation_style)}'"
      end

      # post-animation state
      self.really_fucking_focus

    end
  end
  
  def do_deactivate( completion_proc = -> {} )
    pe_trace
    
    if self.shown?
      # hide all child windows to avoid kCGErrorIllegalArgument
      self.childWindows.each {|w| w.orderOut(self) } if self.childWindows # FIXME restore later
    
			animation_style = default :animation_style
			case animation_style
      when 'slide'
        self.animate_slide :out, completion_proc
      when 'fade'
        self.animate_fade :out, -> {
          self.hide
          completion_proc.call
        }
      else
        raise "unsupported animation style #{animation_style}"
			end
    end
  end

  def animate_slide direction, completion_proc

    case direction
    when :in
      # animation prep
      @window_image ||= self.image_view
      @mask_window.frame = self.deactivated_frame

      to_frame = self.frame
      set_to_state = -> {
        # post-animation state
        self.really_fucking_focus
      }
    when :out
      @window_image = self.image_view
      to_frame = self.deactivated_frame
  		set_to_state = -> {
	      self.hide
  		}
  	else
  		raise "direction #{direction} inimplemented."
  	end

    if direction == :out
      set_to_state.call
    end

    # instruct masking window to animate to a 0-width frame
    @mask_window.animate_grow @window_image, to_frame, completion_proc

    if direction == :in
      set_to_state.call
    end
    
  end
      
  # deadlock likely if invoked from non-main thread.
  def nudge_frame
    old_frame = self.frame
    self.frame = self.frame.modified_frame(self.frame.size.height - 1, :Top)
    self.frame = old_frame
  end
  
  def really_fucking_focus
    # avoid multiple changes of the visible property by first calling orderFront.
    self.orderFront(self)

    self.makeKeyAndOrderFront(self)
    self.makeMainWindow

    # key the anchor window to ensure correct focusing on space switch.
    #@space_anchor_window.makeKeyAndOrderFront(self)
  end

  #==
  
  # space state is scattered around many classes - should the responsibility really be split up to each class?
  def restore_state_for_space( space )
    # IMPL
  end
  
  #=
  
  def resize_mask_window
    @mask_window.frame = self.frame if @mask_window
  end
  
  def default_frame
    screen_frame = self.the_screen.visibleFrame
    
    # width = self.size.width
    width = screen_frame.width / 2
    
    if ScreensManager.instance.current_screen_browser_position == 0
      x = screen.frame.origin.x
    else
      x = screen_frame.origin.x + screen_frame.size.width - width
    end
    
    y = screen_frame.origin.y
    
    NSMakeRect(x, y, width, screen_frame.size.height)
  end
  
  def deactivated_frame
    animation_style = default :animation_style

    # a frame with width == 0.
    if ScreensManager.instance.current_screen_browser_position == 0 # left side
      x = 
        case animation_style
        when 'slide'
          self.frame.origin.x - self.frame.size.width
        when 'reveal'
          self.frame.origin.x
        when 'fade'
          raise "deactivated frame not needed with the 'fade' animation style."
        end
    else
      x = 
        case animation_style
        when 'slide'
          self.frame.origin.x + self.frame.size.width
        when 'reveal'
          self.frame.origin.x
        when 'fade'
          raise "deactivated frame not needed with the 'fade' animation style."
        end
      
    end
    
    NSMakeRect(x, self.frame.origin.y, 0, self.frame.size.height)
  end
  
  def the_screen
    screen_id = ScreensManager.instance.current_display_set_browser_screen
    screens = NSScreen.screens
    the_screen = screens.select do |screen|
      screen.unique_id == screen_id
    end.first
    
    if ! the_screen
      pe_warn "couldn't find screen #{screen_id} from #{screens}, updating screen configuration"
      ScreensManager.instance.update_display_sets

      # dupe
      screen_id = ScreensManager.instance.current_display_set_browser_screen
      screens = NSScreen.screens
      the_screen = screens.select do |screen|
        screen.unique_id == screen_id
      end.first
    end
    
    unless the_screen
      pe_warn "still can't find screen #{screen_id} from #{screens}, returning first screen."
      the_screen = screens[0]
    end
    
    the_screen
  end
  
  def shown?
    self.isVisible
  end
  
  def active?
    NSApp.isActive && self.shown? && self.isKeyWindow
  end
  
  #==
  
  def isMovable
    true
  end
  
  def canBecomeMainWindow
    true
  end

  def canBecomeKeyWindow
    true
  end
end


class WBMaskingWindow < MaskingWindow
  def canBecomeMainWindow
    false
  end
  def canBecomeKeyWindow
    false
  end
end