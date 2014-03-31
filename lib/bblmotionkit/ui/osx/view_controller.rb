
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
