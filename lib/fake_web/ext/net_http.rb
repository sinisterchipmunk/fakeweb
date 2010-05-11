require 'net/http'
require 'net/https'
require 'stringio'
require 'cgi'

module Net  #:nodoc: all

  class BufferedIO
    def initialize_with_fakeweb(io, debug_output = nil)
      @read_timeout = 60
      @rbuf = ''
      @debug_output = debug_output

      @io = case io
      when Socket, OpenSSL::SSL::SSLSocket, IO
        io
      when String
        if !io.include?("\0") && File.exists?(io) && !File.directory?(io)
          File.open(io, "r")
        else
          StringIO.new(io)
        end
      end
      raise "Unable to create local socket" unless @io
    end
    alias_method :initialize_without_fakeweb, :initialize
    alias_method :initialize, :initialize_with_fakeweb
  end

  class HTTP
    class << self
      def socket_type_with_fakeweb
        FakeWeb::StubSocket
      end
      alias_method :socket_type_without_fakeweb, :socket_type
      alias_method :socket_type, :socket_type_with_fakeweb
    end

    def request_with_fakeweb(request, body = nil, &block)
      uri = FakeWeb::Utility.request_uri_as_string(self, request)
      method = request.method.downcase.to_sym
      body ||= decode_hash(request.body) if request.body

      if FakeWeb.registered_uri?(method, uri, body)
        @socket = Net::HTTP.socket_type.new
        FakeWeb.response_for(method, uri, body, &block)
      elsif FakeWeb.allow_net_connect?
        connect_without_fakeweb
        request_without_fakeweb(request, body, &block)
      else
        uri = FakeWeb::Utility.strip_default_port_from_uri(uri)
        if body || method == :post || method == :put
          raise FakeWeb::NetConnectNotAllowedError,
                "Real HTTP connections are disabled. Unregistered request: #{request.method} #{uri} (with #{body.inspect})"
        else
          raise FakeWeb::NetConnectNotAllowedError,
                "Real HTTP connections are disabled. Unregistered request: #{request.method} #{uri}"
        end
      end
    end
    alias_method :request_without_fakeweb, :request
    alias_method :request, :request_with_fakeweb


    def connect_with_fakeweb
      unless @@alredy_checked_for_net_http_replacement_libs ||= false
        FakeWeb::Utility.puts_warning_for_net_http_replacement_libs_if_needed
        @@alredy_checked_for_net_http_replacement_libs = true
      end
      nil
    end
    alias_method :connect_without_fakeweb, :connect
    alias_method :connect, :connect_with_fakeweb
    
    private
    def decode_hash(string)
      hash = CGI.parse string
      hash.each do |key, value|
        if value.kind_of?(Array) && value.length == 1
          hash[key] = YAML::load(value.shift)
        end
      end
      hash
    end
  end

end
