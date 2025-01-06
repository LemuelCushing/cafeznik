module Cafeznik
  module ToolChecker
    def self.method_missing(method_name)
      if method_name.to_s =~ /^(.+)_available\?$/
        tool_name = Regexp.last_match(1)
        system("command -v #{tool_name} > /dev/null 2>&1")
      else
        super
      end
    end

    def self.respond_to_missing?(method_name, include_private = false)
      method_name.to_s.end_with?("_available?") || super
    end
  end
end
