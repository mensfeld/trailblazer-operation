class Trailblazer::Operation
  module PublicCall
    # This is the outer-most public `call` method that gets invoked when calling `Create.()`.
    # The signature of this is `params, options, *containers`. This was a mistake, as the
    # first argument could've been part of `options` hash in the first place.
    #
    # Create.(params, runtime_data, *containers)
    #   #=> Result<Context...>
    #
    # In workflows/Nested compositions, this method is not used anymore and it might probably
    # get removed in future versions of TRB. Currently, we use Operation::__call__ as an alternative.
    #
    # @return Operation::Railway::Result binary result object
    def call(*args)
      ctx = PublicCall.options_for_public_call(*args)

      # call the activity.
      last_signal, (options, flow_options) = __call__( [ctx, {}] ) # Railway::call # DISCUSS: this could be ::call_with_context.

      # Result is successful if the activity ended with an End event derived from Railway::End::Success.
      Railway::Result(last_signal, options, flow_options)
    end

    private
    # Compile a Context object to be passed into the Activity::call.
    def self.options_for_public_call(options={}, *containers)
      # options, *containers = Deprecations.accept_positional_options(params, options, *containers) # TODO: make this optional for "power users".

      # generate the skill hash that embraces runtime options plus potential containers, the so called Runtime options.
      # This wrapping is supposed to happen once in the entire system.

      hash_transformer = ->(containers) { containers[0].to_hash } # FIXME: don't transform any containers into kw args.

      immutable_options = Trailblazer::Context::ContainerChain.new( [options, *containers], to_hash: hash_transformer ) # Runtime options, immutable.

      ctx = Trailblazer::Context(immutable_options)
    end

    module Deprecations
      # Merge the first argument to the public Create.() into the second.
      #
      # DISCUSS: this is experimental since we can never know whether the call is the old or new API.
      #
      # The following situations are _not_ covered here:
      # * You're using a Hash instance as a container.
      # * You're using more than one container.
      #
      # If you do so (we're assuming you know what you're doing then), please update your `call`s.
      def self.accept_positional_options( *args )
        if args.size == 1 && args[0].instance_of?(Hash) # new style, you're doing it right.
          args
        elsif args.size == 2 && args[0].instance_of?(Hash) && !args[1].instance_of?(Hash) # new style with container, you're doing it right.
          args
        else
          warn "[Trailblazer] Passing two positional arguments to `Operation.( params, current_user: .. )` is deprecated. Please use one hash like `Operation.( params: params, current_user: .. )`"
          params, options, *containers = args
          [ options.merge("params" => params), *containers ]
        end
      end
    end
  end
end
