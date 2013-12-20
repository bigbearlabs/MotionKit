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
	end
	
	#= unused state storage api.

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

		# case: dashboard.
		if ! self.space_window_data.select{ |e| e["kCGWindowOwnerName"] == "Dock" && e["kCGWindowName"] =~ /\.wdgt\/+$/ }.empty?
			pe_log "space appears to be dashboard. no anchor operations."
			return nil
		end

		# TEMP show all windows to confirm if perpertual new window bug is due to hidden status.
		
		update_current_anchor_window

		@current_anchor_window.window_id
	end

	#==

	# the window list returned by the Window Services function holds a bunch of untitled windows, things like the menu bar, and windows visible on this space.
	# eg m.report.map {|w| [ w[:kCGWindowName], w[:kCGWindowOwnerName] ]}
	#
	# sample output:
	# {"kCGWindowLayer"=>2147483629, "kCGWindowName"=>"Focus", "kCGWindowMemoryUsage"=>58652, "kCGWindowIsOnscreen"=>true, "kCGWindowSharingState"=>1, "kCGWindowOwnerPID"=>999, "kCGWindowNumber"=>215, "kCGWindowOwnerName"=>"Focusbar", "kCGWindowStoreType"=>2, "kCGWindowBounds"=>{"Height"=>38.0, "X"=>813.0, "Width"=>294.0, "Y"=>1200.0}, "kCGWindowAlpha"=>1.0}
	def space_window_data
		window_list = CGWindowListCopyWindowInfo(KCGWindowListOptionOnScreenOnly|KCGWindowListExcludeDesktopElements, KCGNullWindowID)
		# this list is ordered top-bottom according to window stack

		window_list.copy
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
		window_numbers = self.space_window_data
			.select {|e| e["kCGWindowOwnerPID"] == criteria[:pid]}
			.map {|e| e["kCGWindowNumber"]}

		windows = NSApp.windows.select do |window|
			window_numbers.include? window.windowNumber
		end

		pe_log "windows for space: #{windows}"
		windows
	end

	# FIXME space changes in mission control report multiple anchors - find out the best way to detect mission control activation.
	# TODO clean up anchors and viewer windows if multiple reported.
	def space_changed
		# drop_anchor
	end


#= anchor windows.

	def find_anchors
		windows_in_space.select { |w| w.is_a? AnchorWindow }
	end
	

	protected 

	def update_current_anchor_window
		anchor_windows_in_space = find_anchors

		if anchor_windows_in_space.empty?
			# EDGECASE sometimes we find the anchor window doesn't show up when we click on the status bar window. 

			# on_main do  # crudely synchronise mutation.
				new_anchor_c = new_anchor_wc

				# check again to see if we still need an anchor.
				if find_anchors.empty?
					pe_log "drop new anchor."
					pe_log caller
					new_anchor_c.showWindow(self)
				end
			# end
		end

		# after this point, there should be at least one.
		anchor_windows = find_anchors
		raise "anchor window unavailable for space!" if anchor_windows.empty?

		if anchor_windows_in_space.size > 1
			pe_warn "multiple anchor windows found - #{anchor_windows_in_space}"
			
			# clean up all but the first.
			anchor_windows_in_space[1..-1].map do |w|
				retire_anchor_wc w.windowController
			end
		end

		# after this point, there should be exactly one.
		anchor_windows = find_anchors
		pe_warn "anchor window count for space invalid! - #{anchor_windows}" if anchor_windows.size != 1

		@current_anchor_window = anchor_windows[0]
		
		pe_log "after #update_current_anchor_window, anchor_window: #{@current_anchor_window.window_id}"
	end

	def new_anchor_wc
		controller = SpaceAnchorWindowController.alloc.init

		(@anchor_cs ||= []) << controller

		controller
	end

	def retire_anchor_wc wc
		wc.close
		@anchor_cs.delete wc
	end
	
end
