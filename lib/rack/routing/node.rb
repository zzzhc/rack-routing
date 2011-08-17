module Rack
  module Routing

    class RecognizeState

      attr_reader :path, :anchor, :params, :matcher

      attr_reader :route

      attr_accessor :remaining_path, :current_node

      def initialize(path, anchor, params, matcher)
        @path, @anchor, @params = path, anchor, params
        @matcher = matcher
        @remaining_path = @path
        @current_node = @root
      end

      def to_s
        "path: #{path}, anchor: #{anchor}, params: #{params.inspect}, remaining_path: #{remaining_path}, current_node: #{current_node}, matcher: #{matcher}"
      end

      def matches?
        return true unless matcher
        return false if @current_node.routes.empty?
        ! route.nil?
      end

      def route
        @current_node.routes.find do |route|
          @matcher.matches?(route)
        end
      end

      def success?
        return false unless current_node.endpoint?
        anchor ? remaining_path.empty? : true
      end

      def merge!(child_state)
        self.remaining_path = child_state.remaining_path
        self.params.merge!(child_state.params)
      end

      def child_state(path = nil, anchor = nil, params = nil, matcher = nil)
        path ||= self.remaining_path
        anchor = self.anchor if anchor.nil?
        params = self.params.dup if params.nil?
        matcher = self.matcher if matcher.nil?
        matcher = nil if matcher == false
        state = RecognizeState.new(path, anchor, params, matcher)
        state
      end

    end

    class Node < Struct.new(:str_children, :children, :routes, :parent)

      include Constants

      include NodeGraphViz

      PART_RE = %r{^(?:[^/\.\?]+/?|\.)}

      def initialize(*)
				self.str_children = EMPTY_HASH
				self.children = EMPTY_ARRAY
				self.routes = EMPTY_ARRAY
      end

      def add_route(route)
				self.routes = [] if self.routes.equal? EMPTY_ARRAY
				self.routes << route
        route.node = self
      end

      def find_node(node)
        case node
        when StrNode then
          str_children[node.str]
				else
					children.find {|child| child == node}
        end
      end

      def add_node(node)
        exists_node = find_node(node)
        return exists_node if exists_node

        case node
        when StrNode then
					self.str_children = {} if self.str_children.equal? EMPTY_HASH
          str_children[node.str] = node
				else
					self.children = [] if self.children.equal? EMPTY_ARRAY
					self.children << node
        end
				node.parent = self
        node
      end

			def has_child?
				str_children.any? || children.any?
			end

      def endpoint?
        routes.any? || !has_child?
      end

      def visit
        return false unless yield self
        [
          str_children.values,
          children,
        ].flatten.each do |child|
          next unless child.visit do |n|
            yield n
          end
          return true
        end
      end

      def recognize(state)
        recognize_node(state, true)
        state
      end

      def recognize_in_children(state, check_route)
        node = self
        path = state.remaining_path
        while path.any?
          md = PART_RE.match(path)
          break unless md
          part = md[0]
          if child = node.str_children[part]
            node = child
            path = md.post_match
            next
          end

          break
        end

        state.remaining_path = path
        state.current_node = node

        old_remaining_path, old_current_node = state.remaining_path, state.current_node
        old_params = state.params.dup
				node.children.each do |child|
          if child.recognize_node(state, check_route)
            return state if state.success? && (!check_route || state.matches?)
          end

          state.remaining_path = old_remaining_path
          state.current_node = old_current_node
          state.params.replace(old_params)
				end

        state.success? ? state : nil
			end

		end

		# /users
		class StrNode < Node

      attr_accessor :str

      def initialize(str)
        super
        @str = str
      end

      def generate(params)
        @str
      end

			def ==(other)
				self.class == other.class && str == other.str
			end

      def recognize_node(state, check_route = true)
        path = state.remaining_path
        return unless path.start_with?(str)
        state.remaining_path = path[str.size..-1]
        recognize_in_children(state, check_route)
      end

    end

    class RootNode < StrNode

    end

    class KeyNode < Node

      attr_reader :key, :end_with_slash

      def key=(key)
        @key = (key.nil? || key.empty?) ? nil : key.to_sym
      end

      def end_with_slash?
        @end_with_slash
      end

    end

    class RegexpNode < KeyNode

      attr_accessor :prefix, :re, :suffix

      def initialize(key, prefix, re, suffix)
        super
        self.key = key
        @prefix = prefix || EMPTY_STR
        @re = re.source[0] == ?^ ? re : %r{^(?:#{re.source})}
        @suffix = suffix || EMPTY_STR
      end

      def ==(other)
        self.class == other.class &&
					other.key == key &&
          other.prefix == prefix &&
					other.re == re &&
          other.suffix == suffix
      end

      def generate(params)
        return nil unless params[key]
        s = params.delete key
        "#{prefix}#{s}#{suffix}"
      end

      def recognize_node(state, check_route = true)
        path = state.remaining_path
        unless prefix.empty?
          return unless path.start_with?(prefix)
          path = path[prefix.size..-1]
        end

        md = @re.match(path)
        return unless md
        remaining = md.post_match

        unless suffix.empty?
          return unless remaining.start_with?(suffix)
          remaining = remaining[suffix.size..-1]
        end

        state.params[key] = md[1] if key
        state.remaining_path = remaining
        state.current_node = self

        recognize_in_children(state, check_route)
      end

    end

    # /users/*id
    # /users/*
    # TODO
    # /users/*id/roles
    class StarNode < KeyNode

      ANY_RE = %r{^(.*)}

      attr_reader :re

      def initialize(key, re = nil, end_with_slash = false)
        super
        @end_with_slash = end_with_slash
        self.key = key
        re ||= ANY_RE
        @re = re.source[0] == ?^ ? re : %r{^(?:#{re.source})}
      end

      def ==(other)
        self.class == other.class &&
					other.key == key &&
					other.re == re &&
					other.end_with_slash == end_with_slash
      end

      def generate(params)
        return nil unless params[@key]
        s = params.delete @key
        @end_with_slash ? s.to_s + SLASH_STR : s.to_s
      end

      def recognize_node(state, check_route = true)
        path = state.remaining_path
        if has_child?
          md = @re.match(path)
          path0 = md[1]
          start_index = 0
          while true
            slash_index = path0.index(SLASH_CHAR, start_index)
            if slash_index.nil?
              state.params[@key] = md[1] if @key
              state.current_node = self
              state.remaining_path = md.post_match
              return state
            end

            remaining = path[slash_index + 1..-1]
            child_state = state.child_state(remaining)
            child_state.params[@key] = path[0...slash_index] if @key

            recognize_in_children(child_state, check_route)
            if child_state.success?
              state.merge!(child_state)
              state.current_node = child_state.current_node
              return state
            end

            start_index = slash_index + 1
          end
        else
          md = @re.match(path)
          return unless md
          state.params[@key] = md[1] if @key
          state.remaining_path = md.post_match
          state.current_node = self
          return state
        end
      end
    end

    class OptionalNode < Node

      attr_accessor :root, :path

      def initialize(path)
        super
        @path = path
        str = path[0] == SLASH_CHAR ? SLASH_STR : EMPTY_STR
        @root = RootNode.new(str)
      end

      def optimize_root
        return if root.str.any?
        return unless root.str_children.size + root.children.size == 1
        self.root = root.str_children.values.first || root.children.first
      end

      def recognize_node(state, check_route = true)
        recognize_in_children(state, check_route)
        if state.remaining_path.empty? && state.success?
          return state
        end

        child_state = state.child_state(state.remaining_path, false, nil, false)
        return unless @root.recognize_node(child_state, false)
        state.merge!(child_state)
        state.current_node = self

        if state.remaining_path.empty?
          return state
        end
        recognize_in_children(state, check_route)
      end

      def ==(other)
        self.class == other.class && other.path == path
      end

      def generate(params)
        segments = []
        root.visit do |node|
          case node
          when KeyNode then
            s = node.generate(params)
            next false if s.nil?
            segments << s
          when StrNode then
            segments << node.generate(params)
          else
            segments << node.generate(params)
          end
        end
        segments.join
      end
    end

  end
end
