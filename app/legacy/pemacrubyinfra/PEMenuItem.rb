#
#  PEMenuItem.rb
#  WebBuddy
#
#  Created by Park Andy on 23/11/2011.
#  Copyright 2011 TheFunHouseProject. All rights reserved.
#


class PEMenuItem < NSMenuItem
	attr_accessor :control_for_item

	def update_control_state
		@control_for_item.enabled = self.isEnabled
	end
end