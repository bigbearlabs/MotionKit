class BrowserWindowController

	attr_accessor :bar_shown


	def hide_toolbar( delay = 0 )
		delayed_cancelling_previous delay, -> {
			on_main {
				@top_portion_frame.do_animate -> animator {
					animator.alphaValue = 0
				}, -> {
					@top_portion_frame.hidden = true
					@top_portion_frame.alphaValue = 1

					# some resizing / repositioning during the days when the browser view wasn't fixed.
					# @bar_vc.frame_view.snap_to_top
					# @browser_vc.frame_view.fit_to_bottom_of @bar_vc.frame_view
				}
			}
		}
	end

	# TODO there are cases where this doesn't render properly - implement the top-of-scroll-view solution.
	def show_toolbar
		on_main {
			@top_portion_frame.do_animate -> animator {
				animator.hidden = false

				# @bar_vc.frame_view.snap_to_bottom_of @input_field_vc.frame_view
				# @browser_vc.frame_view.fit_to_bottom_of @bar_vc.frame_view
			}

		}

	end
	
	def toolbar_shown?
		@top_portion_frame.visible
	end


end


class BarViewController < PEViewController
	include KVOMixin
	include DefaultsAccess
	
	# model
	attr_accessor :context

	# view
	attr_accessor :button_template
	attr_accessor :context_menu

	Notifications_by_tags = {
		3000 => :Bar_item_edit_notification,
		3001 => :Bar_item_delete_notification
	}


	def setup
		super
			
		# FIXME push down
		self.setup_browsers

		observe_kvo self, 'context.sites' do |obj, change, context|
			self.refresh
		end

		self.refresh
	end
	
	def refresh
		on_main_async {
			self.clear_all

			# add the buttons
			buttons.map do |button|
				add_button button
			end

			# add_folder

		}
	end

	def add_folder  #STUB
		menu_data = [
			{ title: 'item1', proc: -> { puts 'hi' } },
			{ 
				title: 'submenu1', 
				children: [
					{
						title: '1.1',
						proc: -> { puts 'hoho' }
					}
				]
			}
		]
		menu = PlatformMenu.new menu_data

		button = new_button 'stub-folder' do 
			# drop down a menu.
			button.display_context_menu menu
		end

		add_button button
	end

	# xib wires the button to this action
	def handle_menu_item_select(sender)
		site = sender.representedObject
		tag = sender.tag

		notification = Notifications_by_tags[tag]
		if notification
			pe_log "sending notification #{notification} with #{site}"
			send_notification notification, site
		else
			pe_warn "don't know how to handle tag #{tag}"
		end
	end

#= platform integration

	def update_view_model( site )
		@context_menu.itemArray.each do |item|
			item.representedObject = site
		end
	end

	def new_button( title = 'cloned-button', icon = nil, &handler)
		button = @button_template.duplicate
		
		button.title = title
		button.image = icon
		button.sizeToFit

		button.on_click = -> *args {
			handler.call *args
		}

		button
	end

	def add_button( button )
		self.view.addSubview(button)
		self.view.arrange_single_row
	end

	def eval_bookmarklet(path)
		wc = self.view.window.windowController
		browser_vc = wc.browser_vc
		browser_vc.eval_bookmarklet nil, path:path
	end
	
end


# webbuddy-specific
class BarViewController

	# view model
	attr_accessor :browsers_to_add

	def buttons
		browser_buttons + 
		if_enabled(:bookmarklet_buttons).to_a +
		if_enabled(:action_buttons).to_a
		 # + bookmark_buttons
	end

	def browser_buttons
		browsers_to_add.map do |browser|
			title = "Open page in #{browser[:description]}"
			title = nil  # TODO change prop consumption
			button = new_button title,  browser[:icon] do
				NSApp.send_to_responder 'handle_open_url_in:', browser
			end
		end
	end

	def action_buttons
		[
			{
				title: 'Reading List',
				on_click: -> sender {
					pe_log "send to safari reading list."

					invoke_service :safari_reading_list, page_url
				}
			},
			{
				title: 'Stacks',
				on_click: -> sender {
					NSApp.delegate.wc.component(FilteringPlugin).toggle_plugin
				}
			},
			{
				title: 'Bleeding Edge',
				on_click: -> sender {
					NSApp.delegate.wc.component(FilteringPlugin).toggle_dev
				}
			},
		].map do |button_spec|
			
			new_button button_spec[:title], nil do |sender|
				pe_log "action button #{button_spec[:title]}"
				button_spec[:on_click].call sender
			end

		end
	end

	def bookmarklet_buttons
		bookmarklets = [
			{
				title: 'LastPass',
				path: "plugins/bookmarklets/lastpass.js"
			},
			{
				title: 'Pocket',
				path: "plugins/bookmarklets/pocket.js"
			},
			{
				title: 'Feedly',
				path: "plugins/bookmarklets/feedly.js"
			},
			{
				title: 'Instapaper',
				path: "plugins/bookmarklets/instapaper.js"
			},
			{
				title: 'Evernote',
				path: "plugins/bookmarklets/evernote.js"
			},
		]

		bookmarklets.map do |bookmarklet|
			
			new_button bookmarklet[:title], nil do |sender|
				pe_log "bookmarklet button #{bookmarklet[:title]}"
				self.eval_bookmarklet bookmarklet[:path]
			end

			new_button.tap do |button|
				button.on_r_click do |button, event|
					puts "rclick!"
					edit_action bookmarklet, button
				end
			end

		end
	end

	def bookmark_buttons
		context.sites.collect {|site| site[1] }.map do |site|	# FIXME reconcile strange context.sites data structure
			bookmark = new_bookmark_from site
		end
	end

	#=

	def setup_browsers(force = true)
		# lazy setup.
		return if @browsers_setup and ! force

		@browsers_setup = true

		# FIXME encapsulation violation - migrate to component.
		click_handlers = NSApp.delegate.component(BrowserDispatch).defaults
		handler_assigned_browsers = click_handlers.map do |key, handler_bundle_id|
			handler_bundle_id.downcase
		end
		self.browsers_to_add = Browsers::installed_browsers.values.select do |browser_spec|
			bid = browser_spec[:bundle_id].downcase

			( handler_assigned_browsers.include? bid ) && 
				( bid.casecmp(NSApp.bundle_id) != 0 )  # webbuddy shouldn't go in.
		end
	end

	def new_bookmark_from( site )
		button = new_button site.name do |sender|
			pe_debug "button #{button} clicked - site #{site}"

	    send_notification :Bar_item_selected_notification, site
		end

		button.on_r_click do |the_button, event|
			# TODO highlight the button, unhighlight on menu dismissal

			# attach right model to menu items.
			update_view_model site

			button.display_context_menu @context_menu
		end

		button
	end


	#= realising reading list action. move

	def pasteboard(name)
	  pb = NSPasteboard.pasteboardWithName(name.to_s)
	  def pb.copy_content( content )
	  	unless content.is_a? Array
	  		content = [ content ]
	  	end

	  	self.writeObjects(content)
	  	self
  	end
  	pb
	end
	

	def invoke_service( service_name, params )
		case service_name
		when :safari_reading_list
			p = pasteboard(:page_url).copy_content params
		  item = 'Add to Reading List'
		  
		  retval = NSPerformService item, p
		  pe_log "performed service with #{p}, got #{retval}"
		 else
		 	raise "service #{service_name} unimplemented."
		end

	end
	
	#=

  # show the action plugin as a popover.
	def edit_action action_spec, button
		show_popover button, web_view_controller( "http://localhost:59124/plugins/#/action")
	end
	
	def show_popover anchor_view, view_controller
	  popover = Popover.new view_controller
	  popover.show anchor: anchor_view
	end
	
	def web_view_controller url
		WebViewController.new url:url
	end
	
	#=

	def page_url
	  self.view.window.windowController.browser_vc.url
	end
	

end