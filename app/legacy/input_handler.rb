# application logic for handling text input.
# TODO resolve with repl.rb
class InputHandler < BBLComponent
  
  def setup
    
  end
  
  def process_input( input )
    input = input.dup
    type = input.pe_type
    pe_log "input type for '#{input}': #{type}"
    case type
    when :cmd
      self.process_command input

    when :url
      NSApp.delegate.user.perform_url_input input
    else
      self.client.load_url [
        input.to_url_string,
        input.to_search_url_string
      ]
    end
  end


  #= command processing.  REFACTOR move to a plugin.

  attr_accessor :command_output

  def process_command( input )
    command = input.gsub /^>/, ''

    self.command_output = eval command

    pe_log "command result: #{self.command_output}"

    # HACK put output into an html and load.
    output_file = "#{NSApp.app_support_dir}/plugin/output/data/output.json"
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
    # NOTE this is probably incomplete.
    self =~ %r{^(\w+)://}
  end
  
  def pe_type
    if self =~ /^>/
      :cmd
    elsif self.valid_url?
      :url
    else
      :other
    end
  end
end

