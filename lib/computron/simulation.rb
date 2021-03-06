module Computron
  class Simulation
    attr_reader :client

    def initialize(&block)
      @client     = Client.new
      @simulation = Proc.new { instance_eval(&block) }
    end

    def run!
      EM::run { @simulation.call }
    end

    def halt!
      EM::stop
    end

    def default_host(host=nil)
      host ? @default_host = host : @default_host
    end

    def every(interval, opts={}, &block)
      timer = EventMachine::PeriodicTimer.new(0) do
        timer.interval = interval.respond_to?(:call) ? interval.call : interval
        block.call(timer)
      end
    end

    # HTTP utility methods. These are not meant to behave like a client
    %w[get put post delete head].each do |http_meth|
      eval %{
        def #{http_meth}(*args, &block)
          client.send(:#{http_meth}, *args, &block)
        end}
    end

    # Deal with paths and URLs
    def url(path)
      url = String.new
      url.concat "http://#{default_host}" unless url =~ %r{^(\w+)://} if default_host
      url.concat path =~ /^\// ? path : "/#{path}" # Deal with leading /\
      url
    end
  end
end