#
#  SpaceAnchorWindowManager.rb
#  WebBuddy
#
#  Created by Park Andy on 12/02/2012.
#  Copyright 2012 __MyCompanyName__. All rights reserved.
#


class SpaceAnchorWindowController < NSWindowController
	attr_accessor :new_window
	
	attr_accessor :main_window
	
	def awakeFromNib
		super

		self.setup_anchor_window
	end

	# DEPRECATED after space_id went away in 10.8, this one's not going to be that useful.
	def load_anchor_for_space( space_id, anchor_visible )
		@loaded_windows ||= {}
		
		# set anchor for previous space.
		#		@window_for_space.orderFrontRegardless if @window_for_space
		# @window_for_space.isVisible = true if @window_for_space
		
		@window_for_space = @loaded_windows[space_id]
		if @window_for_space
			pe_debug "retrieved existing anchor window #{@window_for_space} for space #{space_id}"
		else
			pe_log "creating new anchor window for space #{space_id}"
			@new_window = nil
			NSBundle.loadNibNamed('SpaceAnchorWindow', owner:self)
			@window_for_space = @new_window
			@loaded_windows[space_id] = @window_for_space 

			self.setup_anchor_window @window_for_space
		end
		
		@main_window.space_anchor_window = @window_for_space

		@window_for_space.orderOut(self) if ! anchor_visible
	end
	
	def setup_anchor_window
		anchor_window = self.window

		anchor_window.make_transparent

		# TEST make view errors obvious
		anchor_window.frame = new_rect( 0,0,600,600)
		
		# make key status pass onto main window
		anchor_window.did_become_key {
			pe_log "#{self} became key!"
			# @main_window.makeKeyAndOrderFront(self)
		}

		# once created, the anchor window should always stay in order to serve as an anchor for the space.
		anchor_window.canHide = false
	end

end


class AnchorWindow < NSWindow
	
	# need to override these methods to ensure the borderless window works properly as an anchor window.
	def canBecomeMainWindow
		true
	end
	def canBecomeKeyWindow
		true
	end

	def show
		self.visible = true
	end

	def hide
		self.visible = false
	end
end