# eg. break_on_call User, :perform_direct_nav
def break_on_call( clazz, method_name )
	# make a proc that leads to the breakpoing
	$breakpoint_p ||= proc { |*args|
		Environment.instance.breakpoint( [ self, args ] )
	}

	# add a breakpoint to $c#update_current_history_item
	clazz.add_intercept method_name, $breakpoint_p
end

def debug(params = nil)
	Environment.instance.breakpoint( {
		'receiver' => self,
		'info' => params,
		'trace' => ( $DEBUG ? caller.format_backtrace : caller.format_backtrace[0..2].join(', ') )
	} )
end
