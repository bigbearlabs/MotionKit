# require 'CocoaHelper'
# require 'NSViewController_additions'
# require 'NSWindow_additions'

# macruby_framework 'AppKit'
# macruby_framework 'ExceptionHandling'

class NSApplication

	def activate
		activateIgnoringOtherApps(true)
	end

	def name
		NSRunningApplication.currentApplication.localizedName
	end
	
	def bundle_id
		NSBundle.mainBundle.bundleIdentifier
	end

	def pid
		NSRunningApplication.currentApplication.processIdentifier
	end
	
	def icon
		applicationIconImage
	end
	
	def app_support_dir
		dir = NSFileManager.defaultManager.applicationSupportDirectory
		FileUtils.mkdir_p dir unless Dir.exists? dir
		dir
	end

	def resource_dir
		NSBundle.mainBundle.resourcePath
	end
	
	#=

	def status_bar_window
		selection = self.windows.select do |w|
			w.is_a? NSStatusBarWindow
		end

		if selection.size != 1
			pe_warn "unexpected results for #status_bar_window: #{selection}"
		end

		selection.first
	end

	#=

	def windows_report
		ws = windows.collect do |w|
			w.to_s + ":" + w.title.to_s
		end
		ws.to_s + ", keyWindow: " + self.keyWindow.to_s + ", mainWindow: " + self.mainWindow.to_s
	end

end


#=


def new_rect( x, y, w, h )
	NSMakeRect(x, y, w, h)
end

def new_view( rect_or_x = NSZeroRect, y = 0, w = 0, h = 0 )
	if rect_or_x.is_a? NSRect
		rect = rect_or_x
	else
		rect = new_rect rect_or_x, y, w, h
	end

	NSView.alloc.initWithFrame( rect )
end

#= dealing with the responder chain
class NSResponder

	# hacky.
	def first_responder?
		self.window.firstResponder == self
	end

	def responder_chain
		next_responder = case self
			when NSWindow
				self.firstResponder
			when NSApp
				self.keyWindow
			else
				self
			end

		responders = []
		while next_responder
			responders << next_responder

			next_responder = next_responder.nextResponder
		end
		responders
	end
	

	# insert responder between receiver and its current nextResponder.
	def insert_responder( responder )
		next_responder = self.nextResponder
		
		if responder == next_responder
			pe_warn "#{self} next responder already #{responder} - doing nothing."
			return
		end
		
		responder.setNextResponder(next_responder)
		self.setNextResponder(responder)
	end
	
	def make_first_responder
		case self
		when NSWindow
			raise "can't make the window the first responder."
		when NSViewController
			the_window = self.view.window
		when NSView, NSWindowController
			the_window = self.window
		else
			raise "unknown NSResponder type #{self.class}"
		end
		
		if the_window
			the_window.makeFirstResponder(self)
		else
			pe_log "window not set, ignoring request to make first responder."
		end
	end

	def send_to_responder( selector, sender )
		if self.is_a? NSApplication
			target = nil
		else
			target = self
		end

		result = NSApp.sendAction(selector, to:target, from:sender)
		
		unless result
			responder_chain = target ? target.responder_chain : self.responder_chain
			pe_warn "no target found for #{selector}. target:#{target} responder_chain:#{responder_chain}"
		end
	end

end

class NSWindowController

	#= idioms

	def init
		self.initWithWindowNibName(self.class.name.gsub('Controller', ''))
		self

		# TODO refactor usages
	end

	def show
		showWindow(self)
	end

	#=

	def view
		self.window.contentView
	end


	def title_frame_view
		rect = window.frame_view._titleControlRect

		unless @title_frame_view
			@title_frame_view = new_view rect.x, rect.y, rect.width, rect.height
			window.frame_view.addSubview @title_frame_view
		else
			@title_frame_view.frame = rect
		end
		
		@title_frame_view
	end

end


class NSView

#= quick testing
	def add_view( view = new_view(10, 10, width - 20, height - 20) )
		self.addSubview( view )
		view
	end

#= general / geometry
	def visible
		! self.isHidden
	end
	
	def visible=( is_visible )
		self.hidden = ! is_visible
	end
	
	def x
		self.frame.x
	end

	def y
		self.frame.y
	end

	def x=( x )
		self.frame = new_rect x, y, width, height
	end
	
	def y=( y )
		self.frame = new_rect x, y, width, height
	end

	def width
		self.frame.size.width
	end
	
	def height
		self.frame.size.height
	end

	def width=( width )
		self.frame = NSRect.rect_with_center self.center, width, height
	end

	def height=( height )
		self.frame = NSRect.rect_with_center self.center, width, height
	end
		
	def center
		CGPointMake(self.frame.origin.x + (self.width/2), self.frame.origin.y + (self.height/2))
	end
	
	def center=(new_center)
		new_x = new_center.x - (self.width / 2)
		new_y = new_center.y - (self.height / 2)
		self.frame = CGRectMake(new_x, new_y, self.width, self.height)
	end


	def origin=(new_origin)
		self.frameOrigin = new_origin
	end

  def move_x offset
    new_frame = NSMakeRect( frame.origin.x + offset, frame.origin.y, frame.size.width, frame.size.height)
    self.frame = new_frame
  end

  def set_x new_x
    new_frame = NSMakeRect( new_x, frame.origin.y, frame.size.width, frame.size.height)
    self.frame = new_frame
  end

#=
	
	def frame_for_subviews
		union = NSZeroRect
		self.subviews.each do |v|
			union = NSUnionRect(union, v.frame)
		end
		
		union
	end

	def clear_subviews
		self.subviews.dup.each do |subview|
			subview.removeFromSuperview
		end
	end

	def add_tiled_vertical( subview )
		last_subview = self.subviews ? self.subviews.last : nil
		if last_subview == subview
			pe_log "view #{subview} is already a subview. ignoring"
			return
		end

		self.addSubview(subview)
		if last_subview
			subview.snap_to_bottom_of last_subview
		else
			subview.snap_to_top
		end

		# # enlarge vertically if necessary
		# # TODO constrain shrinking, maybe
		# new_height = self.frame_for_subviews.height
		# self.frame = self.frame.modified_frame(new_height, :Top)

		# self.fit_pinning_top
	end

	# get the union rect of the subviews and resize vertically, anchored at top edge.
	def fit_pinning_top
		union_frame = frame_for_subviews
		
		# # balance horizontally - offset x based on diff between old and new widths.
		# width_change = union_frame.width - self.width 
		# new_x = self.x - width_change / 2
		new_x = self.x

		# pin at the top - offset y based on original top location and new height.
		new_y = self.frame.top_y - union_frame.height

		# we need to apply a vertical offset to all subviews later.
		delta_y = (new_y - self.y)

		# set the frame (and pray)
		self.frame = new_rect new_x, new_y, union_frame.width, union_frame.height

		self.subviews.each do |subview|
			if delta_y > 0  # we need to grow - move subview y up.
				subview.y += delta_y
			else  # we need to shrink - move subview y down.
				subview.y -= delta_y
			end
		end
	end

#=

	def views_where(&block)
		# traverse view hierarchy and collect views matching condition.
		hits = []
		hits << self if yield self
		self.subviews.each do |subview|
			subview_hits = subview.views_where(&block)
			hits << subview_hits if ! subview_hits.empty?
		end
		
		hits
	end
	
	#= 
	
	def superview_where
		superview = self.superview
		while superview
			matched = yield(superview)
			return superview if matched == true
			
			superview = superview.superview
		end
		
		nil
	end

	def fit_to_superview	# FIXME rename
		if self.superview
			self.frame = self.superview.bounds
		end
	end
	
	def snap_to_top
		new_y = self.superview.height - self.height
		self.frame = CGRectMake(self.frame.origin.x, new_y, self.width, self.height)
	end
	
	def snap_to_bottom_of( sibling_view )
		new_y = sibling_view.frame.origin.y - self.height
		self.frame = CGRectMake(self.frame.origin.x, new_y, self.width, self.height)
	end

	# resize me to match edge of the sibling view that's higher than me.
	def fit_to_bottom_of( sibling_view )
		new_height = sibling_view.frame.origin.y - self.frame.origin.y
		self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.width, new_height)
	end

	#= 
	
	def position_to_front
		raise "superview nil" if ! self.superview
		
		self.superview.addSubview(self, positioned:NSWindowAbove, relativeTo:nil)
	end
	
	def position_to_back
		raise "superview nil" if ! self.superview
		
		self.superview.addSubview(self, positioned:NSWindowBelow, relativeTo:nil)
	end

	#=

	# http://www.stairways.com/blog/2009-04-21-nsimage-from-nsview
	# some coordinate translation necessary.
	def image( capture_frame = self.bounds, size = self.bounds.size )
		begin
			frame_of_view = CGRectMake(capture_frame.origin.x, self.bounds.size.height - capture_frame.size.height, capture_frame.size.width, capture_frame.size.height)
			image_rep = self.bitmapImageRepForCachingDisplayInRect(frame_of_view)
			image_rep.setSize(frame_of_view.size)
			self.cacheDisplayInRect(frame_of_view, toBitmapImageRep:image_rep)
			image = NSImage.alloc.initWithSize(size)
			image.addRepresentation(image_rep)

			image
		rescue Exception => e
			pe_report e
			nil
		end
	end
	
	def image_view( capture_frame = self.bounds, size = self.bounds.size )
		page_image = self.image capture_frame, size
		image_view = NSImageView.alloc.initWithFrame(capture_frame)
		image_view.image = page_image
		image_view
	end

	#=

	def duplicate
		archived_view = NSKeyedArchiver.archivedDataWithRootObject(self)
		view_copy = NSKeyedUnarchiver.unarchiveObjectWithData(archived_view)
	end

	#=

	def display_context_menu( menu )
		if menu.is_a? Array
			# create an nsmenu.
			ns_menu = new_menu menu
			menu = ns_menu
		end

		NSMenu.popUpContextMenu(menu, withEvent:NSApp.currentEvent, forView:self)
	end
end

#= menus

def stub_menu
	new_menu [
		{ title: 'item1', proc: -> { puts 'item1 clicked' } },
		{ 
			title: 'submenu1', 
			children: [
				{
					title: 'item1.1',
					proc: -> { puts 'item1.1 clicked' }
				}
			]
		}
	]
end

def new_menu( data )
	menu = NSMenu.alloc.initWithTitle('')
	data.each do |item_data|
		item = new_menu_item item_data[:title], item_data[:proc]
		item.representedObject = item_data
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
def new_menu_item( title = 'stub-title', selection_handler )
	item = NSMenuItem.alloc.initWithTitle(title, action:'invoke_proc:', keyEquivalent:'')
	item.target = item
	item.def_method_once :'invoke_proc:' do |sender|
		if selection_handler
			selection_handler.call item
		else
			pe_log "no proc given for menu item #{item}"
		end
	end

	item
end

#= animation

class NSResponder
	def animate( animation_subject, animation_block, completion_block = nil )
		if completion_block
			NSAnimationContext.currentContext.setCompletionHandler( completion_block )
		end
		
		animation_block.call(animation_subject.animator)
	end

	def animate_layer( layer_to_animate, duration, animation_block, completion_block = nil )
		self.layer.addSublayer(layer_to_animate)

		# CATransaction.commit
		
		CATransaction.begin
		CATransaction.setAnimationDuration(duration)
		
		CATransaction.setCompletionBlock( -> {
				begin
					completion_block.call(layer_to_animate) if completion_block
				rescue Exception => e
					pe_report e		
				end		
			})
		
		begin
			animation_block.call(layer_to_animate)
		rescue Exception => e
			pe_report e					
		end		

		CATransaction.commit
	end
end

def ca_immediately( &block )
	CATransaction.begin
	CATransaction.disableActions = true
	CATransaction.animationDuration = 0
	
	begin
		block.call
	rescue Exception => e
		pe_report e
	end
		
	CATransaction.commit
end

def do_animate( animation_proc, completion_proc = nil )
	on_main {
		NSAnimationContext.beginGrouping

		NSAnimationContext.currentContext.setCompletionHandler( completion_proc ) if completion_proc
		
		animation_proc.call

		NSAnimationContext.endGrouping
	}
end


#= subview tiling
class NSView
	# tile the subviews, balancing margins based on the number of views per row.
	def arrange_tiled
		# some simplifying assumptions for constants that may need revisiting for more flexibility
		margin_v = 5
		row_height = 30
		
		rows = self.rows_of_subviews
		row_v_position = 5
		rows.each { |row|
			total_element_width = row.inject(0) {|r, view| r += view.width}
			total_margin_width = self.width - total_element_width
			margin_h = total_margin_width / (row.count + 1) # e.g. if 3 views, there are 4 margins
			
			x_tally = 0
			row.each { |view|
				view.center = CGPointMake(x_tally + margin_h + (view.width / 2), row_v_position + (row_height / 2))
				x_tally += margin_h + view.width
			}
			
			row_v_position += row_height
		}
	end
	
	def rows_of_subviews
		rows = []
		
		width_tally = 0
		view_for_row_collector = []
		self.subviews.each { |view|
			if width_tally + view.width > self.width && ! view_for_row_collector.empty?
				# we collected all the views for the row.
				rows << view_for_row_collector
				width_tally = 0
				view_for_row_collector = []
			else
				width_tally += view.width
			end

			view_for_row_collector << view
		}
		rows << view_for_row_collector if ! view_for_row_collector.empty?
		
		rows
	end

	def arrange_single_row(margin_h = 0)
		view_origin_x = 0
		self.subviews.each do |view|
			view_origin_y = ((self.frame.origin.y + self.height) - view.height ) / 2 # center vertically
			view.origin = NSMakePoint(view_origin_x, view_origin_y)
			view_origin_x += view.width + margin_h
		end 
	end
end


# mouse event handling / tracking.
class NSView
	
	def mouse_inside?
		mouse_location = self.window.mouseLocationOutsideOfEventStream
		hit_view = self.hitTest(self.convertPoint(mouse_location, fromView:nil))
		
		hit_view != nil
	end

	def track_mouse_move( &handler )
		masks = NSMouseMovedMask
		
		self.window.acceptsMouseMovedEvents = true

		self.track_events masks, handler
	end
	
	# @param handler: block receiving parameters event, hit_view.
	def track_mouse_down( &handler )
		masks = NSLeftMouseDownMask

		self.track_events masks, -> event { event.clickCount == 0 }, &handler
	end

	def track_mouse_up( &handler )
		masks = NSLeftMouseUpMask

		self.track_events masks, &handler
	end

	# TODO decompose masks into pre-OR'ed
	def track_events masks, match_condition = nil, &handler
		the_handler = lambda { |event|
			if event.window == self.window && event.match_mask?(masks) != 0
				# proceed only if match condition met.
				if match_condition
					return event if match_condition.call event
				end

				point = self.convertPoint(event.locationInWindow, fromView:nil)
				hit_view = self.hitTest(point)
				if hit_view
					pe_debug "calling event tracking handler for mask #{masks}"
					handler.call event, hit_view
				end
			end
			
			return event
		}

		NSEvent.addLocalMonitorForEventsMatchingMask(masks, handler:the_handler)
	end

		
	# only 1 tracking area per view, you realise.
	def add_tracking_area(mouse_entered_proc, mouse_exited_proc)
		@handler = { :mouse_entered_proc => mouse_entered_proc, :mouse_exited_proc => mouse_exited_proc, :view => self }
		class << @handler
			def mouseEntered(event)
				self[:mouse_entered_proc].call(self[:view])
			end
			
			def mouseExited(event)
				self[:mouse_exited_proc].call(self[:view])
			end
		end
	
		tracking_area = NSTrackingArea.alloc.initWithRect(self.bounds, options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways, owner:@handler, userInfo:nil)

		self.addTrackingArea(tracking_area)
	end

	def update_tracking_areas
		new_areas = self.trackingAreas.collect do |tracking_area|
			self.removeTrackingArea(tracking_area)
			
			NSTrackingArea.alloc.initWithRect(self.bounds, options:tracking_area.options, owner:tracking_area.owner, userInfo:tracking_area.userInfo)
		end
		
		new_areas.each do |new_area|
			self.addTrackingArea(new_area)
		end
	end
end

class NSButton
	def on_click(&handler)
		handler_wrapper = Object.new
		class << handler_wrapper
			attr_accessor :click_handler
			def handleClick(sender)
				click_handler.call(sender)
			end
		end
		handler_wrapper.click_handler = handler

		self.target = handler_wrapper
		self.action = 'handleClick:'
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

class NSImage
	def self.stub_image
		self.imageNamed NSImageNameMobileMe
	end

	# resized image which is potentially cropped to fill width of new size.
	def resized_cropped_image(new_size)
		aspect_ratio = new_size.width / new_size.height

		new_height = self.size.width / aspect_ratio
		#crop if needed
		new_height = (new_height < self.size.height) ? new_height : self.size.height
		aspect_compliant_size = NSMakeSize(self.size.width, new_height)

		# make an image that has the right aspect ratio
		new_image = NSImage.alloc.initWithSize(aspect_compliant_size)
		new_image.lockFocus
		target_rect = NSMakeRect(0,0, aspect_compliant_size.width, aspect_compliant_size.height)
		source_rect = NSMakeRect(0, self.size.height - aspect_compliant_size.height, aspect_compliant_size.width, aspect_compliant_size.height)
		op = NSCompositeSourceOver
		self.drawInRect(target_rect, fromRect:source_rect, operation:op, fraction:1)
		new_image.unlockFocus

		# resize image
		new_image.size = new_size
		
		new_image
	end
end


class NSPoint
	def in_rect( rect )
		NSPointInRect( self, rect )
	end
end

class NSSize
	def pretty_description
		"#{self.width.to_i}x#{self.height.to_i}"
	end
	
	def self.from_pretty_description( desc )
		x, y = desc.split('x')
		NSSize.new(x, y)
	end
end

class NSRect
	def self.rect_with_center(center, width, height)
		# center.x = origin.x + mid(width), center.y = origin.y + mid(height)
		x = center.x - (width / 2)
		y = center.y - (height / 2)
		
		NSMakeRect(x, y, width, height)
	end
	
	def center
		NSMakePoint( NSMidX(self), NSMidY(self) )
	end
	
	def top_and_middle
		NSMakePoint( NSMidX(self), NSMaxY(self) )
	end
	
	def x
		self.origin.x
	end

	def y
		self.origin.y
	end

	def width
		self.size.width
	end
	
	def height
		self.size.height
	end

	def right_x
		self.x + self.height
	end

	def top_y
		self.y + self.height
	end

#= resizing

	# e.g. modified_frame(current_length - 10, :Top) will shorten the rect by 10 from the bottom.
	def modified_frame(target_length, anchored_edge)
		# vertical cases
		case anchored_edge
		when :Top
			x = self.origin.x
			y = self.origin.y + (self.size.height - target_length)
			width = self.size.width
			height = target_length

		when :Bottom
			x = self.origin.x
			y = self.origin.y
			width = self.size.width
			height = target_length
		end

		pe_warn "ASSERT FAIL: #{x}, #{y}, #{width}, #{height} not nil" if ( x && y && width && height ) == nil

		NSMakeRect(x, y, width, height)
	end

	def modified_frame_horizontal( new_width )
		width_diff = self.size.width - new_width  # >0 if new width smaller
		new_x = self.origin.x + (width_diff / 2)
		NSMakeRect( new_x, self.origin.y, new_width, self.size.height )
	end
	
#= serialisation to/from arrays

	def to_array
		self.to_a.collect { |e| e.to_a }
	end
	
	def self.from_array( data_array )
		self.new(data_array[0], data_array[1])
	end
	
end


class NSCollectionView
	def selected_items
		items = []
		self.selectionIndexes.enumerateIndexesUsingBlock( -> index, stop_pointer {
			item = self.itemAtIndex(index)
			items << item
		})
		
		items
	end

	def items
		items = []
		self.subviews.size.times do |i|
			items << self.itemAtIndex(i)
		end
		items
	end
end
	
																										 
class NSCollectionViewItem
	def item_index
		self.collectionView.content.index self.representedObject
	end
	
	def item_frame
		self.collectionView.frameForItemAtIndex item_index
	end
end


class NSTextFinder
	def search_field
		findBarContainer.findBarView.views_where {|v| v.kind_of? NSFindPatternSearchField }.flatten.first
	end
end


class NSArrayController
	def empty!
	 range = NSMakeRange(0, self.arrangedObjects.count)
	 self.removeObjectsAtArrangedObjectIndexes(NSIndexSet.indexSetWithIndexesInRange(range))
	end
end


class NSAppleEventDescriptor
	def url_string
		# translated from GTM sample code 
		
		url_string = self.paramDescriptorForKeyword(KeyDirectObject).stringValue
		
		raise "error extracting url from #{self}" unless url_string
		
		url_string
	end
end


# this was written when codebase had wrong call to make input field first responder - check if complicated logic is still necessary.
module NSTextFieldResponderHandling
	attr_accessor :on_responder_handler
	attr_accessor :resign_responder_handler
	
	def becomeFirstResponder
		result = super 
		
		on_main {
			pe_debug "#{self} becomeFirstResponder"
			
			# select all text
			delayed 0, -> {
				@on_responder_handler.call if @on_responder_handler
			}
		}
		
		# add handling to field editor.
		if self.class.method_defined?(:currentEditor) && self.currentEditor

			text_field = self
			text_view = self.currentEditor
			text_view.def_method_once :resignFirstResponder do
				resign_result = super
				
				on_main { 
					if text_field.window
						pe_debug "#{self} resignFirstResponder to #{text_field.window.firstResponder}"
					
						if text_field.window.firstResponder != self && text_field.window.firstResponder != text_field
							pe_debug "#{self} really resigned"
							
							text_field.resign_responder_handler.call if text_field.resign_responder_handler
						end
					else
						pe_warn "#{self} resignedFirstResponder without window."
					end
				}
				
				resign_result
			end
			
		end
		
		result
	end
	
end


#= sheets

# mixin only for NSWindowController
module SheetHandling

	def show_sheet( sheet_window_controller, &confirm_handler )
		@sheet_state = { handler: confirm_handler, controller: sheet_window_controller }
		NSApp.beginSheet(sheet_window_controller.window, modalForWindow:self.window, modalDelegate:self, didEndSelector:'didEndSheet:returnCode:contextInfo:', contextInfo:nil)
	end

	#=

	def didEndSheet(sheet, returnCode:returnCode, contextInfo:contextInfo)
		puts "!! end sheet, #{@sheet_state}"
		sheet_window_controller = @sheet_state[:controller]
		confirm_handler = @sheet_state[:handler]

		if returnCode == NSRunStoppedResponse # FIXME
			confirm_handler.call

			# ?? would we also need a cancel_handler?
		end

		# dismiss the sheet.
		# NSApp.endSheet(sheet_window_controller.window)
		sheet_window_controller.window.close
	end

end


module SheetController
	def handle_modal_confirm( sender )
		puts "!! modal confirm"
		NSApp.endSheet(self.window)
	end

	def handle_modal_cancel( sender )
		puts "!! modal cancel"
		NSApp.endSheet(self.window, returnCode:NSRunAbortedResponse)
	end
end

class DialogSheetController < NSWindowController
	include SheetController

	attr_accessor :message_field

	def init( details )
		initWithWindowNibName('DialogSheet')

		@details = details

		self
	end

	def awakeFromNib
		super

		self.message_field.stringValue = @details[:message]
	end
end


#=

class NSSplitView
	def collapse_view_at( view_index )
		subview = self.subviews[view_index]
		subview.visible = false
		self.adjustSubviews
	end

	def uncollapse_view_at( view_index )
		subview = self.subviews[view_index]
		subview.visible = true
		self.adjustSubviews
	end
end


class NSEvent
	
	# true for both the mod down and mod up events.
	def modifier_down?(modifier_symbol)
		case modifier_symbol.intern
		when :cmd
			key_mask = NSCommandKeyMask
		when :alt
			key_mask = NSAlternateKeyMask
		else
			# TODO finish implementing.

			return false
		end

		return (self.modifierFlags & NSDeviceIndependentModifierFlagsMask) & key_mask == key_mask
	end

	def match_mask?(mask)
		(NSEventMaskFromType(self.type) & mask ) != 0
	end


	def self.modifiers_down?( flags )		
		self.modifiers & flags != 0
	end
	
	def self.modifiers
		self.modifierFlags
	end

end

#== webkit

# macruby_framework 'WebKit'

class WebView
	def url
		self.mainFrameURL.copy
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
end


