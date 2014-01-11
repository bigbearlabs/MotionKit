# require 'CocoaHelper'
# require 'defaults'

# begin
# 	# for mac os x 10.8
# 	macruby_framework 'CoreGraphics'
# rescue
# end

require 'singleton'

class ScreensManager
	
	def initialize( display_sets = {}, data = {} )
		super
		
		@display_sets_by_id = display_sets
		@display_set_data_by_id = data

		@handlers ||= []
	end
	
	def update_display_sets
		display_set = new_display_set
		@current_display_set = display_set
		@display_sets_by_id[display_set[:id]] = display_set

		self.save

		@display_sets_by_id
	end
		
	def current_display_set_id
		self.screens.collect { |screen| screen[:resolution] } .join ','
	end

	def current_display_set_browser_screen
		display_set = @current_display_set
		index = display_set[:browser_screen_index]
		screen_info = display_set[:screens][index]
		return screen_info[:id]
	end
	
	def current_screen_browser_position
		@current_display_set[:browser_position_index]
	end

#=

	# creates a report obj from current display set
	def new_display_set
		screen_array = self.screens
		id = self.current_display_set_id
		{ 
			id: id,
			name: "#{screen_array.count} screen#{screen_array.count > 1 ? 's' : ''} (#{id})", 
			screens: screen_array,
			browser_screen_index: 0, 
			browser_position_index: 1
		}
	end
	
#=
 
	# when to invoke:
	# - when screens added / removed
	# - when resolution changes
	def handle_display_set_changed
		previous_display_set = @current_display_set

		self.update_display_sets

		@handlers.each do |handler|
			handler.call previous_display_set, @current_display_set
		end

	end
	
	# the handler gets invoked with the _previous_ display set.
	def add_change_handler( handler )
		@handlers ||= []
		@handlers << handler
	end

	def display_set_data( id )
		@display_set_data_by_id[id]
	end

	def set_display_set_data( display_set_id, key, data )
		data_hash = @display_set_data_by_id[display_set_id]
		unless data_hash
			data_hash = {}
			@display_set_data_by_id[display_set_id] = data_hash
		end
		
		data_hash[key] = data
		
		self.save
		
		pe_log "saved #{key} : #{data} for #{display_set_id}"
	end
		
#=
	
	def screens
		# create hash of important screen information
		screen_info = NSScreen.screens
		screen_array = screen_info.collect do |screen|
			{ 
					id: screen.unique_id,
					NSScreenNumber: screen.deviceDescription[:NSScreenNumber],
					resolution: screen.deviceDescription[:NSDeviceSize].sizeValue.pretty_description
			}
		end
		screen_array
	end

#=

	def self.instance
		unless @instance
			# @instance = self.load
			# instance.update_display_sets
			@instance = self.new
		end

		@instance
	end
	
#=

	# FIXME load from a method for NSBundle.
	def self.load
		instance = YAML::load File.open(serialisation_path)
		instance
	rescue Exception => e
		pe_report e, "failed loading #{serialisation_path}"
		self.instance
	end

	def save
		try {
			File.open(self.class.serialisation_path, "w") do |file|
				bytes = file.write self.to_yaml
				bytes
			end
		}

		# TODO only when there are changes.
	end

	def to_yaml_properties
		instance_variables - [ :@handlers ]
	end
	
	def self.serialisation_path
		"#{NSApp.app_support_path}/screens_manager.yaml"
	end
end


class NSScreen
	# this is transient! don't use in situations requiring persitence
	def unique_id
		screen_number = self.deviceDescription['NSScreenNumber'] 
		
		vendor_no = CGDisplayVendorNumber(screen_number)
		model_no = CGDisplayModelNumber(screen_number)
		serial_no = CGDisplaySerialNumber(screen_number)
		
		[ vendor_no, model_no, serial_no ].join('-')
	end
end

