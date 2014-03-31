#
#  NSWindow_additions.rb
#  WebBuddy
#
#  Created by Park Andy on 02/11/2011.
#  Copyright 2011 TheFunHouseProject. All rights reserved.
#




#== additions to NSWindow
class NSWindow

#= indirected idioms

	def visible
		self.isVisible
	end

	def visible=(new_val)
		self.isVisible = new_val
	end
	
	def window_id
		self.windowNumber
	end

	def controller
	  self.windowController
	end
	
#= delegate events

	def did_become_key(&handler)
		# UH? this looks off -- delegate method being defined on delegator.
		self.def_method_once :'windowDidBecomeKey:' do
			yield
		end
	end


#= content view

	def view
		self.contentView
	end

	def view=(view)
		self.contentView = view
	end

	# the view that contains the contentView as well as the title bar, menu bar etc.
	def frame_view
		self.contentView.superview
	end

	def close_button
	  self.standardWindowButton(NSWindowCloseButton)
	end
	
		
# == image capturing
	
	# a version based on NSBitmapImageRep.
	# works, but is too slow.
	# update: works only sporadically?
	def image_view
		image = NSImage.alloc.initWithSize self.frame.size
		
		self.view.lockFocus
		image_rep = NSBitmapImageRep.alloc.initWithFocusedViewRect self.frame
		image.addRepresentation(image_rep)
		self.view.unlockFocus
		
		image_view = NSImageView.alloc.initWithFrame self.frame
		image_view.image = image
		return image_view
	end
	
	# a version based on CGWindowListCreateImage, cribbed from chromimum
	def image_view
		windowImage = CGWindowListCreateImage(CGRectNull, KCGWindowListOptionIncludingWindow, self.windowNumber, KCGWindowImageBoundsIgnoreFraming)
		viewRep = NSBitmapImageRep.alloc.initWithCGImage(windowImage)
		
		# Create an NSImage and add the bitmap rep to it...
		image = NSImage.alloc.init
		image.addRepresentation(viewRep)
		
		# Set the output view to the new NSImage.
		outputView = NSImageView.alloc.initWithFrame(NSMakeRect(0,0,image.size.width, image.size.height))
		outputView.imageScaling = NSScaleNone
		outputView.setImage(image)
		
		outputView
	end
	
	# captures frame region excluding this window.
	def region_image_view
	  # self.orderFront(self)
	  
	  rect = self.frame
	  windowImage = CGWindowListCreateImage(rect, KCGWindowListOptionAll, KCGNullWindowID, KCGWindowImageBoundsIgnoreFraming)
	  viewRep = NSBitmapImageRep.alloc.initWithCGImage(windowImage)
	  
	  # Create an NSImage and add the bitmap rep to it...
	  image = NSImage.alloc.init
	  image.addRepresentation(viewRep)
	  
	  # Set the output view to the new NSImage.
	  outputView = NSImageView.alloc.initWithFrame(NSMakeRect(0,0,image.size.width, image.size.height))
	  outputView.imageScaling = NSScaleNone
	  outputView.setImage(image)
	  
	  outputView
	end


#== animation

	def animate_fade( direction = :in, completion_handler = nil )
    NSAnimationContext.currentContext.duration = 0.1

		case direction
		when :in
			from_opacity = 0
			to_opacity = 1
		when :out
			from_opacity = 1
			to_opacity = 0
		end

		# self.alphaValue = from_opacity
		
		do_animate -> animator {
			animator.alphaValue = to_opacity
		}, completion_handler
	end

#== transparency

	def make_transparent
		old_view = self.view
		self.view = NSView.alloc.initWithFrame(old_view.frame)

		self.opaque = false
		self.isVisible = true

		# comment this out for easier debugging
		self.styleMask = NSBorderlessWindowMask

		self.set_view_to_transparent
		self.view.addSubview(old_view)

		on_main_async {
			self.invalidateShadow
		}
	end

	def set_view_to_transparent
		self.view = TransparentView.alloc.initWithFrame(self.frame)
	end
	
#== frame manipulation
	
	def frame=(frame)
		self.setFrame(frame, display:true)
	end

	def center_x=(center_x)
		old_center_x = frame.x + (frame.width/2)
		delta = center_x - old_center_x
		new_x = frame.x + delta
		self.frame = NSMakeRect(new_x, frame.y, frame.width, frame.height)
	end

	def top_edge_y=(top_y)
		new_y = top_y - frame.height
		self.frame = NSMakeRect(frame.x, new_y, frame.width, frame.height)
	end

#= hit detection

	def mouse_inside?
		self.frame_view.mouse_inside?
	end

#= properties

	def window_ids_below
		CGWindowListCopyWindowInfo(KCGWindowListOptionOnScreenBelowWindow,self.windowNumber)
	end
	
end


#== NSView masking / transparency

# a transparent view in terms of visuals and event handling.
# must set the window opaque property to 'false', superview alpha to 1.
class TransparentView < NSView
	def drawRect(dirtyRect)
		NSRectFillUsingOperation(dirtyRect, NSCompositeClear)
	end
end

class TransparentWindow < NSWindow
	def init(frame_rect = NSZeroRect)
		self.initWithContentRect(frame_rect, styleMask:NSBorderlessWindowMask, backing:NSBackingStoreBuffered,
															 defer:true)
		
		self.make_transparent
		
		self
	end
end

class MaskingWindow < TransparentWindow
	#@ designated
	def init(frame_rect)
		super
			
		self.setHasShadow(false)
			
		self.isVisible = false

		# set the level high to avoid flickering.
		self.setLevel(NSScreenSaverWindowLevel + 100)
		

		self
	end
	
	def animate_grow( view, to_frame, completion_proc = nil )
		unless view
			pe_warn "nil view given to animate to #{to_frame}. #{caller}"
		end
		
    # NSAnimationContext.currentContext.duration = 0.05

		self.view.addSubview(view)

		# animate window frame change
		
		self.isVisible = true
		# self.orderFrontRegardless

		self.orderFrontRegardless
		
		completion_handler = -> {
			NSDisableScreenUpdates()

			completion_proc.call if completion_proc
			
			self.isVisible = false

			view.removeFromSuperview
			
			NSEnableScreenUpdates()
		}

		do_animate -> animator {
			pe_log "animate #{self} from #{self.frame} to #{to_frame}"
			
			# RM-BUG?
			# self.animator.setFrame(to_frame, display:true)

			# WORKAROUND
			self.setFrame(to_frame, display:true, animate:true)

		}, completion_handler
	end

	#= osx

	def animationResizeTime(newFrame)
	  0.08
	end

end


# mixin on window to monitor and invoke any registered handlers.
module WindowEventHandling

	attr_accessor :on_click

	def sendEvent( event )
		case event.type
		when NSLeftMouseDown
			@last_mouse_down = event

			@on_click.call event if @on_click
		end
		
		# super if @pass_events_to_super

		super
	end
	
end


