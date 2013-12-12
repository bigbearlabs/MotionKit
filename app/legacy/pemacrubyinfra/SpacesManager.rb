#
#  SpacesManager.rb
#  WebBuddy
#
#  Created by Park Andy on 08/11/2011.
#  Copyright 2011 TheFunHouseProject. All rights reserved.
#

# @precondition status bar menu item must have been set up.
class SpacesManager

	attr_accessor :anchor_delay

	def initialize
		super

		self.anchor_delay = 0.5

		@states = {}

		self.init_anchor_window
		self.update_space_id
	end
	
	def update_space_id
		@current_space_id = self.current_space_id
	end

	def save_space_state( state_hash )
		if @current_space_id
			@states[@current_space_id] = state_hash
		else
			pe_log  'nil space_id, doing nothing.'
		end
	end
	
	def current_space_state
		@states[@current_space_id]
	end

#==

	def current_space_id 
		# since mountain lion we can't reliably obtain space id's from the window list's kCGWindowWorkspace property.
		# a possible way to work around is to drop an anchor window on every new space, and let the anchor window id stand in for the space id.

		# hacky pre-condition: drop 1 anchor window if none found.
		if self.windows_in_space.select { |w| w.is_a? AnchorWindow }.empty?
			self.space_changed  # will drop the anchor.
		end

		@current_anchor_window.window_id
	end

	#==

	# the window list returned by the Window Services function holds a bunch of untitled windows, things like the menu bar, and windows visible on this space.
	# eg m.report.collect {|w| [ w[:kCGWindowName], w[:kCGWindowOwnerName] ]}
	#
	# sample output:
	# {"kCGWindowLayer"=>2147483629, "kCGWindowName"=>"Focus", "kCGWindowMemoryUsage"=>58652, "kCGWindowIsOnscreen"=>true, "kCGWindowSharingState"=>1, "kCGWindowOwnerPID"=>999, "kCGWindowNumber"=>215, "kCGWindowOwnerName"=>"Focusbar", "kCGWindowStoreType"=>2, "kCGWindowBounds"=>{"Height"=>38.0, "X"=>813.0, "Width"=>294.0, "Y"=>1200.0}, "kCGWindowAlpha"=>1.0}
	def space_window_data
		window_list = CGWindowListCopyWindowInfo(KCGWindowListOptionOnScreenOnly|KCGWindowListExcludeDesktopElements, KCGNullWindowID) 
		# this list is ordered top-bottom according to window stack
	end

	def window_info( app_name )
		self.space_window_data.select { |w| 
			w[:kCGWindowOwnerName].to_s.eql? app_name
		}
	end

	# FIXME this doesn't work as intended because of the status item windows.
	def window_before_me
		windows = self.space_window_data
		my_window_i = windows.index do |w|
			w['kCGWindowOwnerName'] == NSApp.name
		end

		result = windows[my_window_i + 1]
		pe_warn "no window after my first window at #{my_window_i}" unless result

		result
	end

	# FIXME this won't work with pid other than this app's.
	def windows_in_space( criteria = { :pid => NSApp.pid } )
		window_list = [].concat self.space_window_data
		if criteria
			window_list.keep_if do |window_info|
				window_info["kCGWindowOwnerPID"] == criteria[:pid]
			end
		end

		window_numbers = window_list.collect do |window_info|
			window_info["kCGWindowNumber"]
		end

		windows = NSApp.windows.select do |window|
			window_numbers.include? window.windowNumber
		end

		windows
	end

	# FIXME space changes in mission control report multiple anchors - find out the best way to detect mission control activation.
	# TODO clean up anchors and viewer windows if multiple reported.
	def space_changed
		# poor-man's transaction
		@should_drop_anchor = false

		window_data = self.space_window_data
		if $DEBUG
			@debug_window_data ||= []
			@debug_window_data << window_data
		end

		window_report = window_data.collect{ |e| [ e["kCGWindowOwnerName"], e["kCGWindowName"] ] }
		pe_log "all windows: #{ window_report.to_s}"

		delayed_cancelling_previous 0.05, proc {
			on_main do
				@should_drop_anchor = true

				@current_anchor_window.show if @current_anchor_window

				# work out the space case.

				# case: dashboard.
				# case: mission control.
				if ! window_data.select{ |e| e["kCGWindowOwnerName"] == "Dock" && e["kCGWindowName"] =~ /\.wdgt\/+$/ }.empty?
					pe_log "space appears to be dashboard / mission control. no anchor operations."

				# case: a normal space.

				# case: another app in full-screen mode.
				else

					if @should_drop_anchor

						self.update_anchor

						self.update_space_id

						pe_log "space updated to #{current_space_id}"


					else
						pe_log "@should_drop_anchor = false"
						debug [ @current_anchor_window, window_data ]
					end

				end
			end
		}
=begin
		pe_log "space change notification: #{notification.description}"
		
		# first hide the window to prevent flickering
		visible = @main_window_controller.window.isVisible
		@main_window_controller.window.orderOut(self)
		
		# grab all saveable state and store for this space.
		@spaces_manager.save_space_state( { 'app.active' => NSApp.isActive, 'window.isVisible' => visible, 'context.id' => 'stub-context-id' } )
		
		@spaces_manager.update_space_id
    
		state_for_current_space = @spaces_manager.current_space_state
		if ! state_for_current_space
			pe_debug 'no state saved, nothing to restore.'
			app_active = visible = false
		else
			# restore as necessary. TODO how to best implement in a generalised way?
			pe_debug "restoring state: #{state_for_current_space}"
			
			app_active = state_for_current_space['app.active']
			visible = state_for_current_space['window.isVisible']
		end

		# set up the anchor window for this space.
		# @anchor_window_controller.load_anchor_for_space @spaces_manager.current_space_id, visible

		
		# # restore main window state.
		# # disabled until window focus behaviour can be nailed.
		# if visible
		# 	if app_active
		# 		self.activate_main_window({}})
		# 	else
		# 		@main_window_controller.window.show
		# 	end
		# else
		# 	@main_window_controller.window.hide
		# end

		
		if app_active
			# various attempts to restore the app active status properly.
			# most likely redundant. CLEANUP
			
			#			@main_window_controller.window.setLevel( KCGFloatingWindowLevel )
			# NSApp.activateIgnoringOtherApps( true )
			
			# NSApp.performSelector( 'activateIgnoringOtherApps:', withObject:true, afterDelay:0.8 )
			# this results in a fight with the full screen window
			
			# @main_window_controller.window.orderWindow( NSWindowAbove, relativeTo:0 )
		else 
			# @main_window_controller.window.setLevel( KCGNormalWindowLevel )
		end
=end

	end

#= anchor windows.

	def init_anchor_window
		self.update_anchor
	end

	def update_anchor
		windows_in_space = self.windows_in_space
		pe_log "windows in space: #{windows_in_space}"
		controllers = windows_in_space.map {|e| e.windowController}
		pe_log "window controllers in space: #{controllers}"
		anchor_windows_in_space = windows_in_space.select { |w| w.is_a? AnchorWindow }

		case anchor_windows_in_space.size
		when 0
			pe_log "drop new anchor."
			@current_anchor_window = new_anchor_window

		when 1
			@current_anchor_window = anchor_windows_in_space.first

			pe_log "found old anchor #{@current_anchor_window.window_id} - updating current_anchor_window."

		else
			pe_warn "multiple anchor windows found - #{anchor_windows_in_space}"
			debug [ anchor_windows_in_space ]
			
			@current_anchor_window = anchor_windows_in_space.first

			# get rid of all but the first anchor window.
			anchor_windows_in_space[1..-1].map do |w|
				@anchor_window_controllers.delete w.windowController
				w.releasedWhenClosed = true
				w.close
			end
		end

	end


	def new_anchor_window
		controller = SpaceAnchorWindowController.alloc.init
		@anchor_window_controllers ||= []
		@anchor_window_controllers << controller

		controller.window.make_transparent

		controller.window
	end
end
