# a sketch of how policies can be set in defaults and implemented in code.
# e.g.
# def setup
# 	execute_policy( { policy: :setup_window, other_param_entries } )

# 	show_view
# end


class Object
	# at policy invocation point, use it with the policy name.
	# the name of the policy impl has to be set as an attr, {policy_name}_policy`
	def execute_policy( policy_name, params_hash = {} )
		policy_val = default :"#{policy_name}_policy"

		if policy_val
			# invoke the method defined as the name of the policy
			method_for_policy = policy_name + "_" + policy_val
			pe_log "execute policy #{method_for_policy}"
			
			return self.send method_for_policy, params_hash
		else
			# default nil / empty to a no-op

			pe_log "no policy set for #{policy_name} - ignoring"	
			return nil
		end
	end
end