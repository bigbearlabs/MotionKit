# wrap BW::JSON.
class Object

  def to_json
    case self
    when NSString
      '"' + self + '"'
    else
      BW::JSON.generate self
    end
  end

  def self.from_json(json_str)
    BW::JSON.parse json_str.dataUsingEncoding(NSUTF8StringEncoding)
  end
  
end
