# stores and retrieves all contexts, passes them to the context-related vc's
# require 'CocoaHelper'
# require 'defaults'

# require 'fileutils'

class ContextStore
	include DefaultsAccess

  include CoreDataPersistence
	
	attr_accessor :current_context

	default :plist_name  # RENAME yaml_name.  # REFACTOR abstract into a uri
	default :default_plist_name
	default :thumbnail_dir
	default :thumbnail_extension
	
	def stacks
		@stacks_by_id.values.dup.freeze
	end

	def initialize
		super

		@io_queue = Dispatch::Queue.new(self.class.name + ".io")
		@save_queuer = LastOnlyQueuer.new(self.class.name + ".saving")
		
		@stacks_by_id = {}
	end

	#= serialisation

	def to_hash
		stacks_data = @stacks_by_id.dup.map do |stack_id, stack|
			# case context.name
			# when "History"
			# 	# hash for history is treated in a special way.
			# 	pages = self.stacks.map(&:pages).flatten.uniq
			# 	stack_data = {
			# 		"name" => "History",
			# 		"items" => pages.map(&:to_hash),
			# 		"sites" => context.site_data,
			# 		"stacks" => context.tracks_data
			# 	}
			# else
			# 	stack_data = context.to_hash
			# end

			stack_data = stack.to_hash

			stack_data
		end

		{ 
			'stacks' => stacks_data
		}
	end

#= stacks

  def stack_for( stack_expr )
    # stack_expr is query, but can be extensible.
    stack_id = stack_expr

    stack = @stacks_by_id[stack_id]
    if ! stack
      kvo_change_bindable :stacks do
        stack = Context.new stack_id
        @stacks_by_id[stack_id] = stack

        pe_log "new stack '#{stack_id}' created"
      end
    end

    stack
  end


  def stacks_data
    self.stacks.map &:to_hash
  end


  def tokens
    tokens = self.stacks.map{|e| e.name}.join(' ').split.uniq

    # get rid of short ones.
    tokens.select do |token|
      token.size > 2
    end
  end

#=

	def thumbnail_path
		"#{NSApp.app_support_path}/" + thumbnail_dir
	end

  def thumbnail_url( item )
    "#{thumbnail_path}/#{item.url.hash}.#{thumbnail_extension}"
  end
  
#=

	def new_item(item_data)
		item = ItemContainer.from_hash item_data

    item.filter_tag = 'deserialised item'

    item
	end
	
#= persistence

	def save
		@io_queue.async do

			# economise on redundant save requests.
			@save_queuer.async_last_only do

				try {
					trace_time 'save_stacks' do
						self.save_stacks
					end

					trace_time 'save_thumbnails' do
						self.save_thumbnails
					end
				}
				
			end

		end
	end
	
		# TODO guard against exceptions / empty file, restore from backup.
	# TODO implement periodic backup.
	def load
		@io_queue.async do

			trace_time 'load_stacks' do
				self.load_stacks
			end

			trace_time 'load_thumbnails' do
				self.load_thumbnails
			end

		end

		yield if block_given?
	end
	

	# HACKY

	def save_thumbnails
		Dir.mkdir thumbnail_path unless Dir.exists? thumbnail_path
		
		concurrently proc {
			self.stacks
				.map(&:pages)
				.flatten.select(&:thumbnail_dirty).map do |history_item|
					file_name = "#{thumbnail_path}/#{history_item.url.hash}.#{thumbnail_extension}"
					thumbnail = history_item.thumbnail
					image_rep = thumbnail.representations[0]
					data = image_rep.representationUsingType(NSPNGFileType, properties:nil)

					result = data.writeToFile("#{file_name}", atomically:false)
					
					if result
						pe_log "saved #{file_name}"
						history_item.thumbnail_dirty = false
					else
						pe_log "failed saving #{file_name}"
					end
				end
		}
	end


	def load_thumbnails    
		self.stacks.each do |stack|
			stack.pages do |history_item|
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

	#=

  # PERF
  # FIXME position keeping is a hassle here.
	def history_stack
		item_union = NSSet.setWithArray self.stacks.map { |e| e.pages }.flatten

	  h = Context.new('History', item_union.allObjects)
	end
	
	def compact
	  nil_names = stacks.select {|e| e.name.nil?}
	  pe_warn "stacks #{nil_names} have empty names. let's remove."

	  nil_names.map do |bad_stack|
		  @stacks_by_id.delete_if {|k,v| v == bad_stack}
		  bad_stack.persistence_record && bad_stack.persistence_record.destroy
		end
	end
	
end

