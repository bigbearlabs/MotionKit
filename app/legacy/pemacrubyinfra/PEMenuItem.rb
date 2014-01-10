class PEMenuItem < NSMenuItem
	attr_accessor :control_for_item

	def update_control_state
		@control_for_item.enabled = self.isEnabled
	end
end