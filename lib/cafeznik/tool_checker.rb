module Cafeznik
  module ToolChecker
    ALT = {
      "fd" => %w[fd fdfind],
      "bat" => %w[bat batcat]
    }.freeze

    def self.resolve(name)
      names = ALT.fetch(name.to_s, [name.to_s])
      names.find { |n| system("command -v #{n} > /dev/null 2>&1") }
    end

    def self.available?(name) = !!resolve(name)

    def self.method_missing(method_name, *)
      return super unless method_name.to_s.end_with?("_available?")

      tool = method_name.to_s.delete_suffix("_available?")
      available?(tool)
    end

    def self.respond_to_missing?(method_name, include_private = false)
      method_name.to_s.end_with?("_available?") || super
    end
  end
end
