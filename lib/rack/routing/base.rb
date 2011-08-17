require 'cgi'

module Rack
  module Routing

    class RouteError < StandardError; end

    class GeneratePathError < RouteError; end

    module Constants

      PATH_INFO = "PATH_INFO".freeze

      REQUEST_METHOD = "REQUEST_METHOD".freeze

      EMPTY_HASH = {}.freeze

      EMPTY_ARRAY = [].freeze

      EMPTY_STR = "".freeze

      SLASH_STR = "/".freeze

      SLASH_CHAR = ?/

			AMP_STR = "&".freeze

			QM_STR = "?".freeze

    end

    class Route

      include Constants

      attr_reader :name, :app, :defaults

      attr_accessor :node

      def initialize(app, conditions, defaults, name)
        @app = app
        @defaults = (defaults && defaults.any?) ? defaults.freeze : EMPTY_HASH
        @name = name ? name.to_sym : nil
      end

      def matches?(env)
        false
      end

      def generate(params)
        segments = []
        current_node = node
        while current_node
          segments.unshift current_node.generate(params)
          current_node = current_node.parent
        end
        path = segments.join
        query_string = params.map do |k, v|
          "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"
        end.join(AMP_STR)
        path << QM_STR << query_string unless query_string.empty?
        path
      end

    end

    class NoConditionRoute < Route

      def matches?(env)
        true
      end

    end

    class RequestMethodRoute < Route

      @@regexps = {}

      attr_reader :request_method

      def initialize(app, conditions, defaults, name)
        super
        request_method = conditions[:request_method]
        @request_method =
          case request_method
          when String then
            @@regexps[request_method] ||= %r{^(?:#{request_method})$}
          when Array then
            key = request_method.sort.join("|")
            @@regexps[key] ||= %r{^(?:#{key})$}
          when Regexp then
            @@regexps[request_method.source] ||= request_method
          else
            raise "invalid request method: #{request_method}"
          end
      end

      def matches?(env)
        method = env[REQUEST_METHOD]
        method =~ @request_method
      end
    end

    class RouteMatcher
      def initialize(env)
        @env = env
      end

      def matches?(route)
        route.matches?(@env)
      end
    end

    class RouteSet

      include Constants

      def initialize(options = {})
        @root = RootNode.new("/")
        @node_parser = NodeParser.new
        @named_routes = {}
        @lookup_routes = {}
        @lookup_keys = options[:lookup_keys] || [:controller, :action]
				@parameters_key = options.delete(:parameters_key) || 'rack.routing_args'

        yield self if block_given?
      end

      def add_route(app, conditions = EMPTY_HASH, defaults = EMPTY_HASH, name = nil)
        defaults = EMPTY_HASH if defaults.nil? || defaults.empty?
        route_klass = conditions[:request_method] ? RequestMethodRoute : NoConditionRoute
        route = route_klass.new(app, conditions, defaults, name)

        path = conditions[:path_info]
        requirements = conditions.delete(:requirements) || EMPTY_HASH
        node = @node_parser.parse(@root, path, requirements)
        node.add_route(route)
        @named_routes[route.name] = route if route.name

        if defaults.any? && key = lookup_key(defaults)
          @lookup_routes[key] = route
        end
      end

      def recognize(env)
				path = env[PATH_INFO]
        matcher = RouteMatcher.new(env)

        state = RecognizeState.new(path, true, {}, matcher)
        @root.recognize(state)
        return nil unless state.success?

        route, params, remaining_path = state.route, state.params, state.remaining_path
        params.merge!(route.defaults)
        if block_given?
          yield route, params, remaining_path
        else
          return [route, params, remaining_path]
        end
			end

      def call(env)
				recognize(env) do |route, params, remaining_path|
					env[@parameters_key] = params
					return route.app.call(env)
				end
        not_found
      end

      # :name, params
      def path_for(*args)
        named_route, params = args
        named_route, params = nil, named_route if named_route.is_a?(Hash)
        params ||= EMPTY_HASH
        route =
          if named_route
            @named_routes[named_route.to_sym]
          else
            key = lookup_key!(params)
            @lookup_routes[key]
          end
        raise RouteError, "No route found: #{named_route} #{params.inspect}" unless route
        route.generate(params)
      end

      private
      def not_found
        [404, {'Content-Type' => 'text/html', 'X-Cascade' => 'pass'}, ['Not Found']]
      end

      def lookup_key(params)
        @lookup_keys.map do |key|
          params[key] || return
        end.join("#")
      end

      def lookup_key!(params)
        key = lookup_key(params)
        @lookup_keys.each {|k| params.delete k} if key
        key
      end

    end
  end
end
