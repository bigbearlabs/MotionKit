#
#  ContextStore.rb
#  WebBuddy
#
#  Created by Park Andy on 12/12/2011.
#  Copyright 2011 TheFunHouseProject. All rights reserved.
#

# stores and retrieves all contexts, passes them to the context-related vc's
# require 'CocoaHelper'
# require 'defaults'

# require 'fileutils'

class ContextStore
	include DefaultsAccess
	
	attr_accessor :contexts
	attr_accessor :current_context

	default :plist_name
	default :default_plist_name
	default :thumbnail_dir
	default :thumbnail_extension
	
	def initialize
		super

		@io_queue = Dispatch::Queue.new(self.class.name + ".io")
		@save_queuer = LastOnlyQueuer.new(self.class.name + ".saving")
		
		@contexts = [ Context.new("History") ]
		@items_by_id = {}

		self.current_context = @contexts.first
	end
		
	def to_hash
		contexts_data = @contexts.map do |context|
			case context.name
			when "History"
				# hash for history is treated in a special way.
				history_items = @contexts.map(&:history_items).flatten.uniq
				context_data = {
					"name" => "History",
					"items" => history_items.map(&:to_hash),
					"sites" => context.site_data,
					"tracks" => context.tracks_data
				}
			else
				context_data = context.to_hash
			end

			context_data
		end

		{ 
			'contexts' => contexts_data
		}
	end

	def history_to_hash( history_context )
		{
			'name' => history_context.name,
			'items' => history_context.history_data
		}
	end

	def thumbnail_path
		"#{NSApp.app_support_dir}/cache/" + thumbnail_dir
	end

  def thumbnail_url( item )
    "#{thumbnail_path}/#{item.url.hash}.#{thumbnail_extension}"
  end
  
#=

	def new_context( name )
		context = Context.new(name)

		@contexts << context
		self.current_context = context
		
		context
	end

#=

	# TODO guard against exceptions / empty file, restore from backup.
	# TODO implement periodic backup.
	def load
		@io_queue.async do

			trace_time 'load_contexts' do
				self.load_contexts
			end

			trace_time 'load_thumbnails' do
				self.load_thumbnails
			end

		end

		yield if block_given?
	end
	
	def load_contexts
		begin
			pe_log "loading contexts from #{plist_name}"
			context_store_data  = NSDictionary.dictionary_from plist_name
		rescue Exception => e
			pe_report e
			pe_warn "TODO trigger backup restoration workflow"  # IMPL
			
			context_store_data = {}
		end
		
		if ( ! context_store_data || context_store_data.keys.empty? )
			pe_log "initializing empty context store from default template."
			context_store_data = NSBundle.mainBundle.dictionary_from_plist( "data/#{default_plist_name}" )
		end

		
		# load the history context.

		history_data = context_store_data['contexts'].find do |context_hash|
			context_hash['name'] == 'History'
		end
		history_context = @contexts.find do |context|
			context.name == 'History'
		end

		items_data = history_data['items']
		items_data.each do |item_hash|
			item = new_item item_hash
			history_context.add_item item
		end
		pe_log "loaded #{items_data.count} items in history context."

		history_context.load_sites history_data['sites']
		history_context.load_tracks history_data['tracks']


		# initialise or populate the other contexts.
		other_context_data = context_store_data.dup
		other_context_data['contexts'].delete history_data
		try {	
			other_context_data['contexts'].each do |context_hash|

				name = context_hash['name']

				case contexts.size
				when 0
					pe_log "initializing new context #{name}"
					context = Context.new
					@contexts << context
				when 1
					# the object already exists.
				else
					pe_warn "multiple contexts named '#{name}' found - using last one."
				end

				context ||= contexts.last

				context.load_items context_hash['items'], @items_by_id
				context.load_sites context_hash['sites']
				context.load_tracks context_hash['tracks']
			end

		}
		
	end
	
	def new_item(item_data)
		item = ItemContainer.from_hash item_data

    item.filter_tag = 'deserialised item'

    item
	end
	

	def save
		@io_queue.async do

			# economise on redundant save requests.
			@save_queuer.async_last_only do

				try {
					trace_time 'save_contexts' do
						self.save_contexts
					end

					trace_time 'save_thumbnails' do
						self.save_thumbnails
					end
				}
				
			end

		end
	end
	
	def save_contexts
		hash = self.to_hash
		save_report =  hash['contexts'].collect do |context|
			"#{context['name']}: #{context['items'].count} history items"
		end

		save_result = hash.save_to plist_name
		if ! save_result
			raise "error while saving. save_result: #{save_result}"
		else
			pe_log "saved #{self} - #{save_report}"
		end
	rescue Exception => e
		pe_report e, "error saving #{plist_name}"
	end

#=

	# TACTICAL
	def save_thumbnails
		FileUtils.mkdir_p thumbnail_path unless Dir.exists? thumbnail_path
		
		concurrently proc {
			contexts.each do |context|
				context.each_history_item do |history_item|
					if history_item.thumbnail_dirty
						file_name = "#{thumbnail_path}/#{history_item.url.hash}.#{thumbnail_extension}"
						thumbnail = history_item.thumbnail
						image_rep = thumbnail.representations[0]
						data = image_rep.representationUsingType(NSPNGFileType, properties:nil)
						result = data.writeToFile("#{file_name}", atomically:false)   # OPTIMISE change to do this lazily
						if result
							pe_log "saved #{file_name}"
							history_item.thumbnail_dirty = false
						else
							pe_log "failed saving #{file_name}"
						end
					end
				end
			end
		}
	end

	def load_thumbnails    
		contexts.each do |context|
			context.each_history_item do |history_item|
				if ! history_item.thumbnail
					file_name = thumbnail_url history_item
					image_png_data = NSData.data_from_file file_name  # OPTIMISE change to do this lazily
					if File.exists? file_name
						image = NSImage.alloc.initWithData(image_png_data)
						on_main {
							history_item.thumbnail = image
							pe_debug "loaded #{file_name} to #{image}"
						}
					end
				end
			end
		end
	end
end