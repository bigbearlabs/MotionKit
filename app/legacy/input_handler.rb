## RENAME InputParser
# application logic for handling text input.
# NOTE filtering input not handled here.
# TODO resolve with repl.rb
class InputHandler < BBLComponent
  include Reactive

  def setup
    # watch for submitted text.
    react_to 'client.input_field_vc.submitted_text' do |val|
      self.process_input val
    end
  end
  
  def process_input( input )
    input = input.dup
    type = input.pe_type
    pe_log "input type for '#{input}': #{type}"
    case type
    when :module
      module_name = input.gsub /^#/, ''
      self.client.plugin_vc.load_url "http://localhost:9000/#/#{module_name}"

    when :cmd
      self.client.component(RubyEvalPlugin).input = input.gsub(/^>/,'')

    when :url
      self.client.load_url input.to_url_string, stack_id: "navigation to '#{input}'"

    when :search
      self.client.load_url input.to_search_url_string, stack_id: input

    else
      self.client.load_url [
        input,
        input.to_search_url_string
      ], stack_id: input
    end
  end

end


class String
  
  # NOTE this is probably incomplete.
  def valid_url?
    case self.to_s
    when %r{^(\w+)://}  # with a scheme.
      return true
    when %r{\S+:\d+}  # address/host:port format.
      return true
    end

    false
  end
  
  def pe_type
    if self.starts_with? '#'
      :module

    elsif self.starts_with? '>'
      :cmd
    
    elsif self.valid_url?
      :url

    # catch some obvious hints for an enquiry
    elsif self.include? ' '
      :search

    else
      :other
    end
  end
end


