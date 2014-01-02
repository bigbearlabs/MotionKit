# CASE thumbnails after window resize

# CASE consecutive swipe gesture before previous gesture finishes.
# CASE swipe left -> swipe right before swipe left complete, vice versa


class SwipeHandler < BBLComponent
	
	attr_accessor :animation_overlay
	

	def on_setup		
		add_client_methods

		superview = self.client.view
		
		# prep the overlay.
		@animation_overlay = NSView.alloc.initWithFrame(superview.bounds)
		@animation_overlay.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable
		@animation_overlay.layer = CALayer.layer
		@animation_overlay.wantsLayer = true

		superview.add_view @animation_overlay

		# prep the layers.
		@bottom_layer = CALayer.layer
		@bottom_layer.bounds = @animation_overlay.bounds
		@bottom_layer.position = @animation_overlay.center
		@animation_overlay.layer.addSublayer(@bottom_layer)

		@top_layer = CALayer.layer
		# top layer position will be animated.
		@top_layer.bounds = @animation_overlay.bounds
		@animation_overlay.layer.addSublayer(@top_layer)
	end
	
	def add_client_methods
		# work around crash when extending client with a module.

		def client.wantsForwardedScrollEventsForAxis( axis )
			# track horizontal only.
			axis == NSEventGestureAxisHorizontal
		end

		# only deals with forwarded scroll events.
		def client.scrollWheel( event )
			pe_debug event.description
			
			self.component(SwipeHandler).handle_scroll_event event

			super
		end
	end


	# implement horizontal swipe handling.
	# layers in overlay should be created on the fly, based on some count of the target offset from current.
	# FIXME outstanding: multiple concurrent swipes are not handled properly.
	def handle_scroll_event( event )
		case event.phase
		when NSEventPhaseNone
			return
		end
		
		# skip vertical events.
		return if event.scrollingDeltaX.abs <= event.scrollingDeltaY.abs
		
		return if ! NSEvent.isSwipeTrackingFromScrollEventsEnabled
		

		# another important constraint: nav direction must be available for nav.
		# TODO


		# now do the business.
		# on begin event, create and install a new swipe handler.
		if event.phase == NSEventPhaseBegan

			# @swipe_handler ||= new_swipe_handler(event)  # FIXME
			@swipe_handler = new_swipe_handler(event)
					
			event.trackSwipeEventWithOptions(
				NSEventSwipeTrackingClampGestureAmount|NSEventSwipeTrackingLockDirection, 
				dampenAmountThresholdMin:-1, max:1, 
				usingHandler: @swipe_handler)

		end
	end

	def new_swipe_handler( event )
		
		# set up overlay and per-lambda state
		
				
		swipe_handler = lambda { |gestureAmount, phase, isComplete, stop|
			pe_debug "swipe handler block: #{gestureAmount}, #{phase}, #{isComplete}, #{stop}, #{stop[0]}"

			case phase
			when NSEventPhaseBegan
				pe_log "gesture began."
		
				@direction = ( gestureAmount < 0 ? :Forward : :Back )

				# bail out if we can't perform.
				@can_navigate = client.can_navigate @direction
		
				return unless @can_navigate

				@animation_overlay.visible = true  ## DEV

				@swipe_handler_count ||= 0
				@swipe_handler_count += 1
				pe_log "swipe count: #{@swipe_handler_count}"

				ca_immediately {
					case @direction
					when :Forward
						@bottom_layer.contents = client.current_page_image

						@top_layer.contents = client.forward_page_image
						# top layer offset 1 page to the right
						@top_layer.position = NSMakePoint(@animation_overlay.center.x + @animation_overlay.bounds.size.width, @animation_overlay.center.y)

					when :Back
						@bottom_layer.contents = client.back_page_image

						@top_layer.contents = client.current_page_image
						@top_layer.position = @animation_overlay.center

					end
				}
					
				@original_page_x = @top_layer.position.x

				# perform the paging early.
				self.navigate_web_view
			

			when NSEventPhaseCancelled
				# when gesture didn't exceed threshold
					
				return unless @can_navigate

				pe_log "event cancel phase detected in scroll event handler"
	
				@event_cancelled = true

				# animations are handled by further handler invocations -- nothing to implement here.

				# just page.
				self.navigate_web_view opposite_direction( @direction )
				return

			when NSEventPhaseEnded
				pe_log "event phase ended"
			end

			return unless @can_navigate

			# apply page offset rendering.
			# -1 <= normalised offset <= 1. 
			# at 0 the final position should exactly the same as the original position.
			# at 1 the final position should be exactly 1 page to the right.
			ca_immediately {
				@top_layer.position = NSMakePoint(@original_page_x + (gestureAmount * @animation_overlay.frame.size.width), @top_layer.position.y)
			}
				
			if isComplete
				pe_log "swipe #{@swipe_handler_count} complete."
				@swipe_handler_count -= 1

				# reset overlay state
				# FIXME keep overlay in place until browserVC finishes load.
				@animation_overlay.visible = false if @swipe_handler_count == 0

			end

		}
		
		swipe_handler
	end

	#= grammar for navigation.

	def navigate_web_view( direction = @direction )
		# this could potentially take time; clients should call as early as possible.
		on_main_async do
			case direction
			when :Forward
				client.handle_forward(self)
			when :Back
				client.handle_back(self)
			end
		end
	end
	
	def opposite_direction( direction )
	  direction == :Forward ? :Back : :Forward
	end

end