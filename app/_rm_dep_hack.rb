# needed to work around dep issues for gem 'ib'
require 'ib/outlets'


class MotionViewController < PlatformViewController
end

class MotionKitViewController < MotionViewController
end

class PEViewController < MotionKitViewController
end
