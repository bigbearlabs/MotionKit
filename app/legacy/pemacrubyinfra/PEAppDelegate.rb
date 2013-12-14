# require 'CocoaHelper'
# require 'appkit_additions'
# require 'defaults'
# require 'osx_process'
# require 'get_url_handler'

# require 'rubygems'
# require 'benchmark'
# require 'application_delegate'  # interactive-macruby

class PEAppDelegate
	include DefaultsAccess
	include ExceptionHandling

	# MOTION-MIGRATION
	# include InteractiveApplication if ENV['INTERACTIVE']


	attr_accessor :defaults_hash

	# outlets	
	attr_accessor :status_bar_menu


	def setup
		# TODO report critical exception and quit.

		# exception handling
		self.handle_exceptions

		trace_time __callee__.to_s, true do

			# collaborators
			@spaces_manager ||= SpacesManager.new
			@screens_manager ||= ScreensManager.instance

			# defaults
			self.setup_defaults
			
			@tags_by_description = default(:tags_by_description)


			# ready to do some business now

		end

		on_main_async do
			try {
				self.setup_part2
			}
		end

	end

	# consider performing this concurrently.
	def setup_part2
		trace_time 'setup_part2', true do
			begin
				# talk to the system
				self.setup_services
			
				# app-global UI
				self.setup_status_menu

				# app notifications
				watch_notification :Preference_updated_notification

				# system notifications
				watch_notification NSWindowWillExitFullScreenNotification
				watch_notification NSWindowWillEnterFullScreenNotification
				# watch_notification NSWindowDidChangeScreenProfileNotification  # MOTION-MIGRATION
				# need to replace usage of define_*_method
				## (main)> <RBAnonymous68 0x7fa53a44deb0> method `handle_NSWindowDidChangeScreenProfileNotification:' created by attr_reader/writer or define_method cannot be called from Objective-C. Please manually define the method instead (using the `def' keyword).

				watch_workspace_notification NSWorkspaceActiveSpaceDidChangeNotification
				# # use these notifications to handle app-specific content or windows 'parasitically'.
				watch_workspace_notification NSWorkspaceDidActivateApplicationNotification
				watch_workspace_notification NSWorkspaceDidDeactivateApplicationNotification

			rescue Exception => e
				pe_report e
				raise e
			end
		end
		
		on_main_async do
			# quick, the dev console!
			# MOTION-MIGRATION
			# new_debug_window if Environment.instance.isDebugBuild
		end
	end

#==
	
	def setup_defaults
		self.defaults_hash = NSBundle.mainBundle.dictionary_from_plist 'data/defaults'
		defaults_register( self.defaults_hash )
	end
	
	def setup_services
		NSApp.setServicesProvider(self)
		# doc: 'It is only necessary to call this function if your program adds dynamic services to the system.''
		# NSUpdateDynamicServices()	# PERF potentially expensive?
	end

#==

	def setup_status_menu
		@status_item = NSStatusBar.systemStatusBar.statusItemWithLength(NSVariableStatusItemLength)
		
		# @status_item.setTitle('WebBuddy')
		@status_item.setImage(self.status_item_image)
		@status_item.highlightMode = true
		
		# this results in the menu appearing on a mouse up - minor, but non-standard.
		@status_item.target = self
		@status_item.action = 'handle_status_menu_click:'

		# this will set the outlet for the menu. not neat
		NSBundle.loadNibNamed(:StatusBarMenu, owner:self)
	end

	def handle_status_menu_click( sender )

		# hide the dev items unless menu activated with modifier.
		dev_menu_items.each do |dev_item|
			should_show = NSEvent.modifiers_down? NSAlternateKeyMask
			dev_item.hidden = ! should_show
		end

		@status_item.popUpStatusItemMenu(@status_bar_menu)
	end

	def handle_activate(sender)
		NSApp.activateIgnoringOtherApps(true)
	end
	
	def dev_menu_items
		@status_bar_menu.itemArray.select do |item|
			@tags_by_description.select{|k,v| k =~ /_DEV/}.values.include? item.tag
		end
	end

#= services
	
	def handle_service_invocation(pboard, userData:userData, error:error)
		pe_log "service invoked."
		self.toggle_main_window self
	end
	
#=

	def handle_new_debug_window(sender)
		new_debug_window sender
	end

	def new_debug_window(sender = nil)
		self.newTopLevelObjectSession(sender) # imrb
	end
	
#==

	# returns a hash containing:
	#		process_name: frontmost process
	#		selected_string: selection on frontmost responder
	def parse_activation_parameters_enabled

		# selection handling
		begin 
			focused_element = QCUIElement.focusedElement
			source_app_element = focused_element.application

			process_name = source_app_element.processName

			params = {
				source_app_element: source_app_element 
			}
			selection_str = execute_policy :process_selection, params
			
		rescue nil
			selection_str = process_name = nil
		end
			
		# EDGE edges where reading string doesn't make sense
			
		results = {
			selection: selection_str,
			process_name: process_name
		}
		pe_debug "parsed activation params. #{results}"

		results
	end

	def process_selection_grab( params )
		params[:source_app_element].readString
	end

#=

	def handle_show_app_actions(sender)
		# TODO show a semi-transparent overlay with content parameterised from sender.

		puts 'bam'
	end

#= properties

	def visible_windows
		visible_windows = NSApp.windows.select { |w| 
			w.isVisible && 
			! w.kind_of?(NSStatusBarWindow) && 
			! w.kind_of?(MaskingWindow) && 
			w.parentWindow == nil && # no child windows
			! w.title.eql?('AnchorWindow') && # no anchor windows
			! (w.class.name =~ /^_|OverlayWindow/) # no overlay windows
		}

		# reject the irb windows too
		[].concat(visible_windows).reject do |w|
			Module.const_defined?(:IRBWindowController) && w.windowController.is_a?(IRBWindowController)
		end
	end
	

#= app / system-level event handling

	def handle_NSWorkspaceDidActivateApplicationNotification(notification)
		@current_app = notification.userInfo['NSWorkspaceApplicationKey'].localizedName
		pe_debug "updating current_app to #{@current_app}"
	end

	def handle_NSWorkspaceDidDeactivateApplicationNotification(notification)
		@previous_app = notification.userInfo['NSWorkspaceApplicationKey'].localizedName
		pe_debug "updating previous_app to #{@previous_app}"
	end

	def handle_NSWorkspaceActiveSpaceDidChangeNotification(notification)
		self.on_space_change notification
	end
	
	
	def applicationDidFinishLaunching(notification)
		self.setup
	end
	
	def applicationWillTerminate(notification)
		self.on_terminate
	end

	def applicationWillBecomeActive(notification)
		self.on_will_become_active	
	end

	def applicationDidBecomeActive( notification )
		self.on_active
	end

	def applicationWillResignActive( notification )
		on_will_resign
	end

	def applicationDidChangeScreenParameters( notification )
		# how to best distinguish between new screen and res change?
		pe_log "screen params change: #{notification.desc}"
		on_screen_change( notification )
	end

end

## in order to get activation right, we need to comply to the system's general rules on windowing.
# this is challenging because:
# the hud window is normally non-activating, due to full-screen considerations
# slide animation being made with a window rather than a view, also can have edge cases

# propose the following:
# find a reliable way to determine whether full-screen or not.
# conditional to that result, make all non-activating panel be based on an anchor window.
# ensure the anchor window is taken off screen where nessary, and synchronise panel behaviour.
# review all app activation points and isolate to routines which are activated only when needed
# (full screen)
