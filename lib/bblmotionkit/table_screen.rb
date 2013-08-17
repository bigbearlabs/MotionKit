class GenericTableScreen < ProMotion::GroupedTableScreen
  include NibLoading

  attr_accessor :cell_nib_name
  attr_accessor :data

  def on_load
    self.title = @data[:title] if @data[:title]

    # add_right_nav_button(label: "Save", action: :save)
    set_tab_bar_item(title: @data[:tab_bar][:title], icon: @data[:tab_bar][:icon]) if @data[:tab_bar]

    update_table_data

  end

  # table_data is automatically called. Use this format in the return value.
  # It's an array of cell groups, each cell group consisting of a title and an array of cells.
  def table_data
    @data ? @data[:sections] : []
  end

  def new_table_cell(data_cell)
    cell = load_from_nib @cell_nib_name
    cell
  end

  # This method allows you to create a "jumplist", the index on the right side of the table
  def table_data_index
    # Ruby magic to make an alphabetical array of letters.
    # Try this in Objective-C and tell me you want to go back.
    return ("A".."Z").to_a 
  end

  def set_stub_data
    self.data = {
      title: 'Generic Table',
      tab_bar: {
        title: 'tab title',
        icon: ''
      },
      sections: [
        {
          title: 'Generic section',
          cells: [
            { 
              title: "generic entry", 
              action: :handle_entry_select, 
              # arguments: { id: 3 } 
              weight: 5
            }
          ]
        }
      ]
    }
  end

end