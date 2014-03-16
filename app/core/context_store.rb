# stores and retrieves all contexts, passes them to the context-related vc's
# require 'CocoaHelper'
# require 'defaults'

# require 'fileutils'

class ContextStore
	include CoreDataPersistence
	include ThumbnailPersistence
	
	attr_accessor :current_context  # SMELL
		
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
		# stack_expr is the id for now (which in turn is the name), but can be extensible.
		stack_id = stack_expr

		stack = find_stack stack_id
		stack ||= add_stack stack_id
	end

	def find_stack(stack_id)
		@stacks_by_id[stack_id]
	end

	def add_stack( stack_id )
		if @stacks_by_id[stack_id]
			raise "stack_id '#{stack_id}' is not available."
		end

		stack = Context.new stack_id
		kvo_change_bindable :stacks do
			@stacks_by_id[stack_id] = stack

			pe_log "new stack '#{stack_id}' created"
		end

		stack_updated stack
	end
	
	def update_stack( stack_id, details )
		stack = find_stack stack_id
		if stack
			if url = details[:url]
				details = details.dup
				details.delete :url
				stack.touch url, details

				# tactical special cases
				if details[:thumbnail]
					save_thumbnail stack.item_for_url(url)
				end
			else
				raise "can't update with #{details}"
			end

			stack_updated stack

		else
			raise "no stack '#{stack_id}' found"
		end
	end

	def stack_updated(stack)
	  # work around the kvo bug.
	  NSApp.delegate.updated_stack = stack
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

