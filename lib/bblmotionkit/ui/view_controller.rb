# TODO reconcile with PEViewController
class MotionViewController < PlatformViewController


#= lifecycle

  def setup
    # ensure view is loaded.
    pe_debug self.view
    
    self.add_view_to_frame

    # other stuff to be performed by subclasses
  end
  

#= interacting with frame

  extend IB
  outlet :frame_view

  def add_view_to_frame
    if @frame_view
      @frame_view.addSubview( self.view )
      self.view.fit_to_superview
    else
      pe_log "#{self} has nil frame_view, skipping view setup."
      debug
    end
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



=begin
  def load_view nib_name
      views = NSBundle.mainBundle.loadNibNamed nib_name, owner:self, options:nil
      self.view = views[0]
  end
=end

#= init

  def init( nib_name = self.class.name.gsub(/Controller$/,'') )
    obj = self.initWithNibName(nib_name, bundle:nil)
    obj
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

    # RECONCILE PEViewController modelled setup external to awakeFromNib. resolve.
    if @frame_view
      @frame_view.addSubview self.view
    else
      pe_warn "no frame view set up for for #{self}"
    end

    pe_log "#{self} awoke from nib."
  end

end


# RENAME MotionKitViewController
class MotionKitViewController < MotionViewController
end


# CONSIDER just monkey-patching NSViewController
class PEViewController < MotionKitViewController

  def awakeFromNib
    super

    # if self.view
    #   pe_log  "#{self} awoke from nib with view set."
    # else
    #   pe_log "#{self} awoke from nib but without the view."
    # end
    pe_log "#{self} awoke from nib."
  end

end
