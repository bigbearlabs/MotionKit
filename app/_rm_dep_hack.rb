PlatformViewController = NSViewController

# work around dep resolution failure for key motionkit classes

module Delegating
end

class MotionKitAppDelegate
end

class MotionViewController < PlatformViewController
end

class MotionKitViewController < MotionViewController
end

# bridges post bblmotionkit refactor

class PEViewController < MotionKitViewController
end

class PEAppDelegate < MotionKitAppDelegate
end

