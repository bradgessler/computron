# TODO integrate this puppy into the runner
module Computron
  class Report

    class Request
      
      class Response
        attr_accessor :headers, :status, :at
      end

      attr_accessor :uri, :response, :headers, :at, :method

      def response
        yield @response if block_given?
        @response
      end

      def duration
        @duration ||= response.at.to_f - at.to_f if at and response.at
      end

      def initialize
        @response = Response.new
        yield self if block_given?
      end
      
    end

    attr_reader :requests

    def initialize
      @requests = []
    end

    def by_status
      requests.inject({}) do |memo, request|
        memo[request.response.status] ||= []
        memo[request.response.status] << request
        memo
      end
    end

    def sample(&block)
      requests << Request.new(&block)
    end

  end  
end