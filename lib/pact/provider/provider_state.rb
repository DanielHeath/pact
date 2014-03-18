require 'pact/shared/dsl'
require 'pact/provider/provider_state_configured_modules'

module Pact
  module Provider

    BASE_PROVIDER_STATE_NAME = "__base_provider_state_name__"

    module DSL
      def provider_state name, &block
        ProviderStates.provider_state(name, &block).register
      end

      def base_provider_state &block
        ProviderStates.provider_state(BASE_PROVIDER_STATE_NAME, &block).register
      end

      def provider_states_for name, &block
        ProviderStates.current_namespaces << name
        instance_eval(&block)
        ProviderStates.current_namespaces.pop
      end
    end

    class ProviderStates
      def self.provider_state name, &block
        ProviderState.build(name, current_namespaces.join('.'), &block)
      end

      def self.register name, provider_state
        provider_states[name] = provider_state
      end

      def self.provider_states
        @@provider_states ||= {}
      end

      def self.current_namespaces
        @@current_namespaces ||= []
      end

      def self.get name, options = {}
        fullname = options[:for] ? "#{options[:for]}.#{name}" : name
        (provider_states[fullname] || provider_states[fullname.to_sym]) || provider_states[name]
      end

      def self.get_base options = {}
        get(BASE_PROVIDER_STATE_NAME, options) || NoOpProviderState
      end
    end

    class ProviderState

      attr_accessor :name
      attr_accessor :namespace

      extend Pact::DSL

      def initialize name, namespace, &block
        @name = name
        @namespace = namespace
        @set_up_defined = false
        @tear_down_defined = false
        @no_op_defined = false
        #not sure why but using include doesn't bring in the configured module methods
        self.extend ProviderStateConfiguredModules
      end

      dsl do
        def set_up &block
          self.register_set_up &block
        end

        def tear_down &block
          self.register_tear_down &block
        end

        def no_op
          self.register_no_op
        end
      end

      def register
        ProviderStates.register(namespaced(name), self)
      end

      def finalize
        validate
      end

      def register_set_up &block
        @set_up_block = block
        @set_up_defined = true
      end

      def register_tear_down &block
        @tear_down_block = block
        @tear_down_defined = true
      end

      def register_no_op
        @no_op_defined = true
      end

      def set_up
        if @set_up_block
          instance_eval &@set_up_block
        end
      end

      def tear_down
        if @tear_down_block
          instance_eval &@tear_down_block
        end
      end

      private

      attr_accessor :no_op_defined, :set_up_defined, :tear_down_defined

      def validate
        if no_op_defined && set_up_defined
          raise error_message_for_extra_block 'set_up'
        elsif no_op_defined && tear_down_defined
          raise error_message_for_extra_block 'tear_down'
        elsif !(no_op_defined || set_up_defined || tear_down_defined)
          raise "Please provide a set_up or tear_down block for provider state \"#{name}\". If there is no data to set up or tear down, you can use \"no_op\" instead."
        end
      end

      def error_message_for_extra_block block_name
        "Provider state \"#{name}\" has been defined as a no_op but it also has a #{block_name} block. Please remove one or the other."
      end

      def namespaced(name)
        if namespace.empty?
          name
        else
          "#{namespace}.#{name}"
        end
      end
    end

    class NoOpProviderState

      def self.set_up

      end

      def self.tear_down

      end

    end
  end
end
