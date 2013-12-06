#
#  intro.rb
#  WebBuddy
#
#  Created by ilo-robbie on 20/01/2013.
#  Copyright 2013 __MyCompanyName__. All rights reserved.
#


class ArrowWindowController < NSWindowController

	def init
		self.initWithWindowNibName('Arrow')

		# set the layer to a 'notice'-compatible one so as to get the user's attention. 
		self.window.level = NSScreenSaverWindowLevel

		self
	end

	def awakeFromNib
		super
		
		setup_window_sbitem_indicator
	end

	# NOTES for 2nd pass: declaratively 'policise' a method.


	def setup_window_sbitem_indicator
		self.window.make_transparent

		# TODO line up the centre with the status item view
		frame = NSApp.status_bar_window.frame
		self.window.center_x = frame.center.x
		self.window.top_edge_y = frame.center.y

		# TODO pulsating animation
	end

	def show
		if ! self.window.isVisible
			self.window.isVisible = true
		else
			self.showWindow(self)
		end
	end
end

