# require 'tags'

class Action
  
end


class Visit < Action
  attr_reader :url
  
  def initialize(url)
    @url = url
  end

  def descriptive_string
    "Url: #{url}"
  end
end

class Revisit < Action
  attr_reader :url
  attr_reader :track_id
  
  def initialize(url, track_id)
    @url = url
    @track_id = track_id
  end

  def descriptive_string
    "Url: #{url}"
  end
end


class SearchAction < Action
  attr_reader :search_string
  attr_reader :url
  
  def initialize(input)
    super
    
    @search_string = input
    @url = input.to_search_url_string
  end

  def descriptive_string
    "Search: #{search_string}"
  end

  def filter_string
    search_string
  end
end


class FilterAction < Action
  attr_reader :filter_string
  
  def initialize(filter_str)
    super
    
    @filter_string = filter_str
  end
  
  def descriptive_string
    "Filter: #{filter_string}"
  end
end


class UnfilterAction < Action
end


class ActionTest
  
  # actions from input field
  
  def test_visit_url
    # on url input,
    action = Visit.new(url, current_tags)
    @user.add_action action
  end
  
  def test_filter
    # on filter input,
    action = FilterAction.new(filter_input)
    @user.add_action action  
    
    # then create view spec from action.tags
  end
  
  def test_search
    # on search input,
    action = SearchAction.new(search_input)
    @user.add_action action 
    
    # then create new view spec or add a refinement trail item to existing
  end

  # actions from page
  
  def test_visit_link
    # on link click,
    action = Visit.new(url, current_tags)
    @user.add_action action
  end
  
end
