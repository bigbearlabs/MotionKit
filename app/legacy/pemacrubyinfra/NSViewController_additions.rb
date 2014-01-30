# CONSIDER just monkey-patching NSViewController
class PEViewController < NSViewController

	attr_accessor :frame_view
	
	def init
		if self.initWithNibName(self.class.name.gsub(/Controller$/,''), bundle:nil)
		end
		
		self
	end
	
	def initWithNibName(nib, bundle:bundle)
		if super
			pe_log "inited #{self} with nibName:#{self.nibName}"
			init_state if self.respond_to? :init_state
		end
		
		self
	end
	
	def initWithCoder(coder)
		if super
			pe_log  "inited #{self} with nibName:#{self.nibName}"
			init_state if self.respond_to? :init_state
		end
		
		self
	end

	def awakeFromNib
		super

		# if self.view
		# 	pe_log  "#{self} awoke from nib with view set."
		# else
		# 	pe_log "#{self} awoke from nib but without the view."
		# end
		pe_log "#{self} awoke from nib."
	end

#= lifecycle

	def setup
		# ensure view is loaded.
		pe_debug self.view
		
		self.add_view_to_frame

		# other stuff to be performed by subclasses
	end
	
#= view

	def hide
		self.frame_view.visible = false
	end

	def show
		self.frame_view.visible = true
	end

	def visible
		self.frame_view.visible
	end


	def clear_all
		self.view.clear_subviews
	end

	def add_view_to_frame
		if @frame_view
			@frame_view.addSubview( self.view )
			self.view.fit_to_superview
		else
			pe_log "#{self} has nil frame_view, skipping view setup."
			debug
		end
	end
	
#= dialog management

	def show_dialog( details )
		pe_trace

		dialog_sheet_controller = DialogSheetController.alloc.init details
		self.view.window.windowController.show_sheet dialog_sheet_controller do
			pe_trace
			details[:confirm_handler].call
		end
	end

end


