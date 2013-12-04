# application logic for handling text input.
# TODO resolve with repl.rb
module InputHandler
  
  def process_input( input )
    type = input.dup.pe_type
    pe_log "input type: #{type}"
    case type
    when :enquiry
      NSApp.delegate.user.perform_search input

      # TODO move to the right notification handler.
      NSApp.delegate.wc.input_field_vc.current_enquiry = input

    when :cmd
      self.process_command input

    else
      # it's a url.

      NSApp.delegate.user.perform_url_input input
    end
  end

  #= REFACTOR move to the module.

  attr_accessor :command_output

  def process_command( input )
    command = input.gsub /^>/, ''

    self.command_output = eval command

    pe_log "command result: #{self.command_output}"

    # HACK put output into an html and load.
    output_file = "#{NSApp.app_support_dir}/modules/output/data/output.json"
    FileUtils.mkdir_p( File.dirname output_file) unless Dir.exist? File.dirname( output_file )
    File.open output_file, 'w' do |f|
      f << %Q(
        {
          "output": "#{self.command_output}"
        }
      )
    end

    # TODO pull out.
    NSApp.delegate.wc.browser_vc.load_module :output
  end
end


class String
  def valid_url?
    # MOTION-MIGRATION temp disable due to 'uri' not being compatible
    # return true if URI::DEFAULT_PARSER.regexp[:ABS_URI].match self
    # return true if URI::DEFAULT_PARSER.regexp[:ABS_URI].match self.to_url_string
    # false

    self =~ %r{^http(s?)://}
  end
  
  def pe_type
=begin
    if ! self.valid_url? || 
      # exceptionally handle single words which aren't pingable as enquiries.
        (self.single_word? && ! is_reachable_host?(self))
=end
    if self =~ /^>/
      :cmd
    elsif ! self.strip.valid_url? || self.single_word?
      :enquiry
    else
      :url
    end
  end
end

