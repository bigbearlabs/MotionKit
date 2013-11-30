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
	
	def frame=(frame)
		self.setFrame(frame, display:true)
	end
	
	def window_id
		self.windowNumber
	end

	def did_become_key
		self.def_method_once :windowDidBecomeKey do
			yield
		end
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
		self.orderFront(self)
		
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
	
#== animation

	def animate_fade( direction = :in, completion_handler = nil )
		case direction
		when :in
			from_opacity = 0
			to_opacity = 1
		when :out
			from_opacity = 1
			to_opacity = 0
		end

		# self.alphaValue = from_opacity
		
		do_animate -> {
			self.animator.alphaValue = to_opacity
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
		if super
			#      self.setLevel(NSScreenSaverWindowLevel + 100)
			self.setHasShadow(false)
			
			self.isVisible = false
		end

		self
	end
	
	def animate_grow( view, to_frame, completion_proc = nil )
		unless view
			pe_warn "nil view given to animate to #{to_frame}. #{caller}"
		end
		
		self.view.addSubview view if view

		# animate window frame change
		
		self.isVisible = true
		self.orderFrontRegardless
		from_frame = self.frame
		
		completion_handler = -> {
			NSDisableScreenUpdates()
			completion_proc.call if completion_proc
			self.isVisible = false
			view.removeFromSuperview if view
			NSEnableScreenUpdates()
		}

		do_animate -> {
			pe_log "animate #{self} from #{self.frame} to #{to_frame}"
			
			self.animator.setFrame(to_frame, display:true)   
		}, completion_handler
	end

end

# NOTE deprecated over NSViewMouseTracking?
module WindowEventHandling
	# monitor events to this window and invoke any registered handlers.
	# a result of trying to intercept clicks on NSTextField (in summary, some controls don't have mouseDown event handlers invoked due to their implementation)
	# for now, only works with left mouse clicks on an nsbox or its subviews.
	
	attr_accessor :pass_events_to_super
	
	# REFACTOR pull up
	def init_module
		if ! @module_inited
			@click_handlers = {}
			@event_handlers = {}
			
			@module_inited = true
		end
	end
	
	# as a last-resort workaround against the problem of detecting clicks in nested views where the click is snatched by first responder, we override the sendEvent to get the click handled by a handler registered for the appropriate view. this doesn't work with all kinds of windows due to parculiarities with sendEvent.
	def sendEvent( event )
		#pe_debug "debug: event: #{event.description}"
		
		unless @click_handlers
			pe_debug "#{self} not initialised - will just pass through."
			return super if @pass_events_to_super
			return
		end
		
		# find the view that would get this event.
		case event.type
		when NSLeftMouseDown
			location = event.locationInWindow
			hit_view = self.view.superview.hitTest(location)

			pe_debug "hit view:#{hit_view}"

			# grab view of interest (currently a bounding NSBox) and send event to previously regged handler
			# TODO move client-specific logic to the client code
			if hit_view
				view_of_interest = hit_view.superview_where { |v| v.kind_of? NSBox }
				if view_of_interest
					handler = @click_handlers[view_of_interest]
					handler.call(view_of_interest) if handler
				end
			end
		end
		
		super if @pass_events_to_super
	end
	
	def add_handler(view, proc)
		init_module
		@click_handlers[view] = proc
	end
	
	def add_event_handler( event_type, handler )
		init_module
		@event_handlers[event_type] = handler
	end
end


