require 'logger'
require 'eventmachine'
require 'em-http'

module Computron
  class Client
    class Response

      attr_reader :status

      def initialize(opts={})
        @status = {}
        yield self if block_given?
      end

      def call(http)
        if callback = status[http.response_header.status]
          callback.call(decode_response(http))
        end
        @finished.call  if @finished
      end

      # A shortcut for specifying a callback on an HTTP code if you don't know the status name.
      def code(code, &block)
        status[code] = block
      end

      # Runs after every HTTP request
      def finished(&block)
        @finished = block
      end

      # Returns a hash containing the response code to the status like {200 => ok}.
      def self.http_status_codes
        @http_status_codes ||= %(100 continue
          101 switching_protocols
          200 ok
          201 created
          202 accepted
          203 non_authoritive_information
          204 no_content
          205 reset_content
          206 partial_content
          300 multiple_choices
          301 moved_permanently
          302 found
          303 see_other
          304 not_modified
          305 use_proxy
          307 temporary_redirect
          400 bad_request
          401 unauthorized
          402 payment_required
          403 forbidden
          404 not_found
          405 method_not_allowed
          406 not_acceptable
          407 proxy_authentication_required
          408 request_timeout
          409 conflict
          410 gone
          411 length_required
          412 precondition_failed
          413 request_entity_too_large
          414 request_uri_too_long
          415 unsupported_media_type
          416 request_range_not_satisfiable
          417 expectation_failed
          500 internal_server_error
          501 not_implemented
          502 bad_gateway
          503 service_unavailable
          504 gateway_timeout
          505 http_version_not_supported).inject({}) do |hash, line|
            code, status = line.split(' ')
            hash[code.to_i] = status
            hash
          end
      end

      http_status_codes.each do |code, status|
        eval %(
          def #{status}(&block)
            status[#{code}] = block
          end)
      end

    private
      def decode_response(http)
        content_type = http.response_header['CONTENT_TYPE']

        case content_type
        when %r{^application/json}
          response = ActiveSupport::JSON.decode(http.response)
        else
          response = http.response # Do nothing, just return text
        end

      rescue
        raise StandardError.new("Problem decoding '#{content_type}'!: \n#{http.response}\n")
      end
    end

    attr_accessor :cookie, :name, :logger

    def initialize
      @logger = Logger.new($stdout)
      yield self if block_given?
    end

    def long_poll(url, &block)
      get url do |response|
        repoll = Struct.new(:url).new(url)
        block.call(response, repoll)
        response.finished { long_poll(repoll.url, &block) }
      end
    end

    # HTTP requests
    %w[get put post delete head].each do |http_meth|
      eval %{
        def #{http_meth}(*args, &block)
          request(:#{http_meth}, *args, &block)
        end}
    end

  private
    def log_request(http, extra=nil)
      logger.info "#{http.response_header.status.to_s.ljust(4)} #{http.method.ljust(4)} #{http.uri}#{" (#{extra})" if extra}\n  #{http.response}\n"
    end
  
    # Simplifies em-http-client into something more suitable for tests. Interpets JSON, etc.
    def request(http_meth, url, opts={}, &block)
      response  = Response.new
      request   = EM::HttpRequest.new(url).send(http_meth, opts)

      request.callback {|http|
        persist_cookie(http)
        block.call(response) if block_given?
        response.call(http)
        log_request(http)
      }
      request.errback {|http|
        log_request(http, "Network error or timeout.")
      }
    end

    # Maintains session for mock users
    def persist_cookie(http)
      self.cookie = http.response_header['SET_COOKIE'] if http.response_header.include?('SET_COOKIE')
    end
  end
end