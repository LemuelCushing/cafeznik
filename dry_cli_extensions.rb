module Dry
  class CLI
    class Command
      class << self
        alias_method :original_option, :option

        def option(name, **kwargs)
          original_option(name, **kwargs)

          # Define an instance variable
          define_method(:"#{name}=") do |value|
            instance_variable_set(:"@#{name}", value)
          end

          # Define a getter method
          define_method(name) do
            instance_variable_get(:"@#{name}")
          end

          # Override the call method to set instance variables
          old_call = instance_method(:call)
          define_method(:call) do |**options|
            options.each do |key, value|
              send(:"#{key}=", value) if respond_to?(:"#{key}=")
            end
            old_call.bind(self).call(**options)
          end
        end
      end
    end
  end
end
