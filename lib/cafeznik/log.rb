require "logger"

module Cafeznik
  module Log
    module_function

    def verbose=(value)
      @verbose = value
      logger.level = value ? Logger::DEBUG : Logger::INFO
    end

    def verbose?
      @verbose || false
    end

    def logger
      @_logger ||= Logger.new($stdout).tap do |log|
        log.level = verbose? ? Logger::DEBUG : Logger::INFO
        log.formatter = proc { |severity, _, _, msg| "[#{severity}] #{msg}\n" }
        log.debug "Verbose mode enabled" if verbose?
      end
    end

    %i[info debug warn error].each do |level|
      define_method(level) do |msg = nil, &block|
        return unless logger.send(:"#{level}?")

        message = block ? "#{msg}:\n#{block.call.gsub(/^/, '  ')}" : msg
        logger.send(level, message)
      end
    end
  end
end
