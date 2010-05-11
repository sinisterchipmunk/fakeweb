module FakeWeb
  class Registry #:nodoc:
    include Singleton
    attr_accessor :uri_map

    def initialize
      clean_registry
    end

    def clean_registry
      self.uri_map = Hash.new { |hash, key| hash[key] = {} }
    end

    def register_uri(method, uri, options)
      data = data_from_options(options)
      target_hash = uri_map[normalize_uri(uri)][method] ||= {}
      target_hash[data] = [*[options]].flatten.collect do |option|
        FakeWeb::Responder.new(method, uri, option, option[:times])
      end
    end

    def registered_uri?(method, uri, data = nil)
      data = data_from_options(data) || data
      !responders_for(method, uri, data).empty?
    end

    def response_for(method, uri, data = nil, &block)
      responders = responders_for(method, uri, data)
      return nil if responders.empty?

      next_responder = responders.last
      responders.each do |responder|
        if responder.times and responder.times > 0
          responder.times -= 1
          next_responder = responder
          break
        end
      end

      if next_responder
        next_responder.response(&block)
      else nil
      end
    end


    private
    def data_from_options(options)
      data = options.kind_of?(Hash) && options.key?(:data) ? options[:data] : nil
      stringified_data(data)
    end
    
    def stringified_data(data)
      if data.kind_of?(Hash)
        data.inject({}) do |hash, (key, value)|
          hash[key.to_s] = stringified_data(value)
          hash
        end
      else
        data
      end
    end

    def responders_for(method, uri, data)
      data = stringified_data(data)
      uri = normalize_uri(uri)

      uri_map_matches(method, uri, URI, data) ||
      uri_map_matches(:any,   uri, URI, data) ||
      uri_map_matches(method, uri, Regexp, data) ||
      uri_map_matches(:any,   uri, Regexp, data) ||
      []
    end

    def uri_map_matches(method, uri, type_to_check = URI, data = nil)
      uris_to_check = variations_of_uri_as_strings(uri)

      matches = uri_map.select { |registered_uri, method_hash|
        registered_uri.is_a?(type_to_check) && method_hash.has_key?(method)
      }.select { |registered_uri, method_hash|
        if type_to_check == URI
          uris_to_check.include?(registered_uri.to_s)
        elsif type_to_check == Regexp
          uris_to_check.any? { |u| u.match(registered_uri) }
        end
      }

      if matches.size > 1
        raise MultipleMatchingURIsError,
          "More than one registered URI matched this request: #{method.to_s.upcase} #{uri}"
      end

      matches.map do |_, method_hash|
        if !(value = method_hash[method][data]) && method_hash[method].has_key?(nil)
          method_hash[method][nil]
        else
          value
        end
      end.first
    end
    

    def variations_of_uri_as_strings(uri_object)
      normalized_uri = normalize_uri(uri_object.dup)
      normalized_uri_string = normalized_uri.to_s

      variations = [normalized_uri_string]

      # if the port is implied in the original, add a copy with an explicit port
      if normalized_uri.default_port == normalized_uri.port
        variations << normalized_uri_string.sub(
                        /#{Regexp.escape(normalized_uri.request_uri)}$/,
                        ":#{normalized_uri.port}#{normalized_uri.request_uri}")
      end

      variations
    end

    def normalize_uri(uri)
      return uri if uri.is_a?(Regexp)
      normalized_uri =
        case uri
        when URI then uri
        when String
          uri = 'http://' + uri unless uri.match('^https?://')
          URI.parse(uri)
        end
      normalized_uri.query = sort_query_params(normalized_uri.query)
      normalized_uri.normalize
    end

    def sort_query_params(query)
      if query.nil? || query.empty?
        nil
      else
        query.split('&').sort.join('&')
      end
    end

  end
end
