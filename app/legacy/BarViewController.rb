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

			add_action_buttons

			# add_folder

			# if context
			# 	add_bookmarks
			# end
		}
	end

	def add_folder  #STUB
		button = new_button 'stub-folder'
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
		menu = new_menu menu_data

		button.on_click do
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

	def new_action_button( action_def )
		button = new_button nil, action_def[:icon] 
		button.on_click do |the_button|
			self.instance_exec &action_def[:proc] 
		end

		button
	end


#= platform integration

	def update_view_model( site )
		@context_menu.itemArray.each do |item|
			item.representedObject = site
		end
	end

	def new_button( title = 'cloned-button', icon )
		button = @button_template.duplicate
		
		button.title = title
		button.image = icon
		button.sizeToFit

		button
	end

	def add_button( button )
		self.view.addSubview(button)
		self.view.arrange_single_row
	end

end


# webbuddy-specific
class BarViewController
	# view model
	attr_accessor :browsers_to_add

	def add_action_buttons
		browsers_to_add.each do |browser|
			# attach the handler to each view model 
			browser[:proc] ||= -> {
				NSApp.send_to_responder 'handle_open_url_in:', browser
			}

			button = new_action_button browser
			add_button button
		end
	end

	def add_bookmarks
		context.sites.collect {|site| site[1] }.each do |site|	# FIXME reconcile strange context.sites data structure
			bookmark = new_bookmark_from site
			add_button bookmark
		end
	end


	def setup_browsers
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
		button = new_button( site.name )
		button.on_click do |the_button|
			pe_debug "button #{the_button} clicked - site #{site}"

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

end