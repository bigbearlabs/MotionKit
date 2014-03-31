class AppProcess

  def initialize( bundle_id, spaces_manager )
    super
    @bundle_id = bundle_id
    @spaces_manager = spaces_manager
  end

  def pid
    bundle_id_matches = NSWorkspace.sharedWorkspace.runningApplications.select { |running_app| running_app.bundleIdentifier == @bundle_id }

    return nil if bundle_id_matches.empty?
    
    if bundle_id_matches.size > 1
      pe_warn "more than 1 match for #{@bundle_id} - returning the last one."
    end

    bundle_id_matches.last.processIdentifier
  end
end


