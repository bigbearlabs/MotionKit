class PEPopoverController < NSViewController
end

module KVOMixin
end


class MainWindowController
  extend IB
  outlet :page_details_vc
end


class BrowserWindowController
  extend IB

  outlet :page_details_vc
end