PlatformViewController = NSViewController


module Delegating
end

class MotionViewController < PlatformViewController
end

class MotionKitViewController < MotionViewController
end

class PEViewController < MotionKitViewController
end
