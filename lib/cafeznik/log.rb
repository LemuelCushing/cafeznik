require "logger"
require "digest"

module Cafeznik
  module Log
    module_function

    def verbose=(value)
      @verbose = value
      logger.level = value ? Logger::DEBUG : Logger::INFO
      logger.formatter.verbose = value
    end

    def verbose? = @verbose || false

    def logger
      @_logger ||= Logger.new($stdout).tap do |log|
        log.level = verbose? ? Logger::DEBUG : Logger::INFO
        log.formatter = CompactFormatter.new
        log.debug "Verbose mode enabled" if verbose?
      end
    end

    %i[info debug warn error fatal].each do |level|
      define_method(level) do |msg = nil, &block|
        return unless logger.send(:"#{level}?")

        caller_context = caller_locations(1, 1).first
        component = caller_context.path[%r{/([^/]+)\.rb$}, 1]&.capitalize || "Unknown"
        method = caller_context.label.split(/[#.]/).last

        source_prefix = "[#{component}::#{method}]"

        message = block ? "#{msg}:\n#{block.call}" : msg
        formatted_message = "#{source_prefix} #{message}"

        logger.send(level, formatted_message)
        return unless level == :fatal

        exit(1)
      end
    end
  end

  class CompactFormatter < Logger::Formatter
    COLOR_MAP = {
      colors: (30..37).to_a + (90..97).to_a # ANSI text colors
    }.freeze

    COLORS = {
      severity: {
        "DEBUG" => ["\e[44m", "\e[37m"],  # Blue bg, white fg
        "INFO" => ["\e[42m", "\e[30m"],   # Green bg, black fg
        "WARN" => ["\e[43m", "\e[30m"],   # Yellow bg, black fg
        "ERROR" => ["\e[41m", "\e[37m"],  # Red bg, white fg
        "FATAL" => ["\e[45m", "\e[30m"]   # Magenta bg, black fg
      },
      reset: "\e[0m"
    }.freeze

    attr_accessor :verbose

    def initialize
      @component_colors = {}
      @verbose = false
      super
    end

    def call(severity, _time, _progname, message)
      component, method, content = parse_message(message)
      severity_bg, severity_fg = COLORS[:severity][severity] || COLORS[:severity]["DEBUG"]
      severity_prefix = "#{severity_bg}#{severity_fg}#{severity[0]}#{COLORS[:reset]}"
      source_prefix = format_source(component, method)

      formatted_content = content.gsub("\n", "\n" + (" " * (severity_prefix.size + source_prefix.size + 1)))
      if @verbose
        "#{severity_prefix} #{source_prefix} #{formatted_content}\n"
      else
        "#{formatted_content}\n"
      end
    end

    private

    def parse_message(message)
      if message =~ /\[([^:]+)::([^\]]+)\]\s+(.+)/m
        [::Regexp.last_match(1), ::Regexp.last_match(2), ::Regexp.last_match(3)]
      else
        ["Unknown", "unknown", message]
      end
    end

    def format_source(component, method)
      component_color = color_for_string(component)
      method_color = color_for_string(method)

      "[#{component_color}#{component}#{COLORS[:reset]}::#{method_color}#{method}#{COLORS[:reset]}]"
    end

    def color_for_string(str)
      index = Digest::MD5.hexdigest(str).to_i(16) % COLOR_MAP[:colors].size
      "\e[#{COLOR_MAP[:colors][index]}m"
    end
  end
end
