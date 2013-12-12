#
#  SwipeHandler.rb
#  WebBuddy
#
#  Created by Park Andy on 27/02/2012.
#  Copyright 2012 __MyCompanyName__. All rights reserved.
#


class SwipeHandler
	

	attr_accessor :browser_vc
	attr_accessor :animation_overlay
	
	def awakeFromNib
		super
		
		@animation_overlay.layer = CALayer.layer
		@animation_overlay.wantsLayer = true
	end
	
	# FIXME outstanding: multiple concurrent swipes are not handled properly.
	# layers in overlay should be created on the fly, based on some count of the target offset from current.
	# actual navigation of the webview should be done after all animations in order to avoid jittery rendering.
	def handle_scroll_event( event )
		case event.phase
		when NSEventPhaseNone
			return
		when NSEventPhaseCancelled
			# gesture didn't exceed threshold
			
			pe_log "event cancel phase detected in scroll event handler"

			# previous handler will be invoked with amount approaching 0, so no need to do anything here.
			return
		end
		
		return if event.scrollingDeltaX.abs <= event.scrollingDeltaY.abs
		
		return if ! NSEvent.isSwipeTrackingFromScrollEventsEnabled
		
		# if @animation_in_progress
		# 	# there's a previous swipe being tracked - signal that to be cancelled.
		# 	pe_debug "signal previous swipe to be cancelled."
		# 	@cancel_previous_swipes = true
		# end
		
		if event.phase == NSEventPhaseBegan

			# create a handler that will receive continuous calls for the duration of the gesture (including momentum)
			# swipe_handler = new_swipe_handler_paging(event)
			swipe_handler = new_swipe_handler_no_animation(event)
					
			event.trackSwipeEventWithOptions(NSEventSwipeTrackingClampGestureAmount|NSEventSwipeTrackingLockDirection, dampenAmountThresholdMin:-1, max:1, usingHandler: swipe_handler)
		end
	end
	# CASE swipe left -> swipe right before swipe left complete, vice versa
	
	def new_swipe_handler_paging( event )
		
		# set up overlay and per-lambda state
		
		@animation_overlay.visible = true
		
		bottom_layer = CALayer.layer
		top_layer = CALayer.layer
		original_page_x = nil
		direction = nil
		
		@swipe_handler_count ||= 0
		@swipe_handler_count += 1
		
		# event_cancelled = false

		swipe_handler = lambda { |gestureAmount, phase, isComplete, stop|
			pe_debug "event #{event}: swipe handler block: #{gestureAmount}, #{phase}, #{isComplete}, #{stop}, #{stop[0]}"

# 			if @cancel_previous_swipes
# 				# another swipe coming in - reset the overlay and abort this swipe
# #				@animation_overlay.hidden = true
					
# 				pe_log "cancel previous swipes"
# 				@cancel_previous_swipes = false
# 				@animation_in_progress = false
# 				@event_cancelled = false

# 				# hmm, this doesn't seem to stop!!
# 				stop.assign(true)
					
# 				return
# 			end
				
			case phase
			when NSEventPhaseBegan
				pe_log "gesture began."
					
				direction = ( gestureAmount < 0 ? :Forward : :Back )
			
				ca_immediately {
					case direction
					when :Forward
						bottom_layer.contents = @browser_vc.current_page_image
						top_layer.contents = @browser_vc.forward_page_image
						# top layer offset 1 page to the right
						top_layer.position = NSMakePoint(@animation_overlay.center.x + @animation_overlay.bounds.size.width, @animation_overlay.center.y)
					when :Back
						bottom_layer.contents = @browser_vc.back_page_image
						top_layer.contents = @browser_vc.current_page_image
						top_layer.position = @animation_overlay.center
					end

					bottom_layer.bounds = @animation_overlay.bounds
					bottom_layer.position = @animation_overlay.center
					@animation_overlay.layer.addSublayer(bottom_layer)

					# it's all about animating the top layer
					top_layer.bounds = @animation_overlay.bounds
					@animation_overlay.layer.addSublayer(top_layer)
				}
					
				original_page_x = top_layer.position.x

			when NSEventPhaseCancelled
				# when gesture didn't exceed threshold
				pe_log "event phase cancel detected in swipe handler"
					
				event_cancelled = true

#				@browser_vc.load_history_item( @current_history_item )

			when NSEventPhaseEnded
				pe_log "event phase ended"
			end

			# apply page offset.
			# -1 <= normalised offset <= 1. 
			# at 0 the final position should exactly the same as the original position.
			# at 1 the final position should be exactly 1 page to the right.
			ca_immediately {
				top_layer.position = NSMakePoint(original_page_x + (gestureAmount * @animation_overlay.frame.size.width), top_layer.position.y)
			}
				
			if isComplete
				pe_log "#{event} complete"
				@swipe_handler_count -= 1

				# reset overlay state
				# FIXME keep overlay in place until browserVC finishes load.
				@animation_overlay.visible = false if @swipe_handler_count == 0
				top_layer.removeFromSuperlayer
				bottom_layer.removeFromSuperlayer
					
				unless event_cancelled
					concurrently -> {
						case direction
						when :Forward
							@browser_vc.handle_forward(self)
						when :Back
							@browser_vc.handle_back(self)
						end
					}
				end
			end
		}
		
		swipe_handler
	end
	
	def new_swipe_handler_no_animation( event )

		direction = nil

		swipe_handler = lambda { |gestureAmount, phase, isComplete, stop|
			pe_debug "event #{event}: swipe handler block: #{gestureAmount}, #{phase}, #{isComplete}, #{stop}, #{stop[0]}"

# 			if @cancel_previous_swipes
# 				# another swipe coming in - reset the overlay and abort this swipe
# #				@animation_overlay.hidden = true
					
# 				pe_log "cancel previous swipes"
# 				@cancel_previous_swipes = false
# 				@animation_in_progress = false
# 				@event_cancelled = false

# 				# hmm, this doesn't seem to stop!!
# 				stop.assign(true)
					
# 				return
# 			end
				
			case phase
			when NSEventPhaseBegan
				pe_log "gesture began."

				direction = ( gestureAmount < 0 ? :Forward : :Back )

			when NSEventPhaseCancelled
				# when gesture didn't exceed threshold
				pe_log "event phase cancel detected in swipe handler"
					
				event_cancelled = true

#				@browser_vc.load_history_item( @current_history_item )

			when NSEventPhaseEnded
				pe_log "event phase ended"
			
				unless event_cancelled
					concurrently -> {
						case direction
						when :Forward
							@browser_vc.handle_forward(self)
						when :Back
							@browser_vc.handle_back(self)
						end
					}
				end
				
			end
				
			if isComplete
				pe_log "#{event} complete"
			end
		}
		
		swipe_handler
	end
end