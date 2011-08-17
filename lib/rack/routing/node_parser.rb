module Rack
  module Routing

    class ParserError < StandardError; end

    class InvalidPathError < ParserError; end

    class NodeParser

      include Constants

      #NEXT_RE = %r{^(:[\w_]+|\*([\w_]+)?|\([^\)]+\)|[^\(/:\*]*)/?}
      NEXT_RE = /
				^
				(
					([^\*\/\(]*)(:[\w_]+)
				|
				  \*([\w_]*)
				|
					\([^\\)]+\)
				|
					[^\(\/:\*]*
				)
				\/?
				/x

      LEFT_PARENTHESIS = "("

      RIGHT_PARENTHESIS = ")"

      NEXT_RIGHT_PARENTHESIS = %r{^([^\)]*)\)}

      DEFAULT_SEPARATORS = %w{/ ? .}

      def initialize(separators = DEFAULT_SEPARATORS)
        self.separators = separators
				@regexps = {}
        @optional_root_node_cache ||= {}
      end

      def separators=(separators)
        @separators = separators
        @separators_re = %r{^([^#{separators.join}]+)}
      end

      # /
      # /users
      # /users/:id(.:format)
      # /users/*
      # /users/*id/roles/:role_id
      #   users .*/roles :role_id
      # (/:current_network_id)/advertising/network/video/1
      #   /(:current_network_id/)advertising/network/video/1
      # /:controller(/:action(/:id))
      def parse(root, path, requirements = EMPTY_HASH)
        raise ArgumentError, "root must be a #{RootNode.name}" unless RootNode === root
        raise InvalidPathError, "path: #{path}" unless path.start_with?(root.str)

        remaining = path[root.str.size..-1]
        current_node = root

        while !remaining.empty? && (m = NEXT_RE.match(remaining))
          remaining = m.post_match
          end_with_slash = m[0][-1] == SLASH_CHAR
					node =
						if m[3] && m[3][0] == ?:
              key = m[3][1..-1]
              prefix = m[0][0] != ?: ? m[2] : EMPTY_STR
              re = requirements[key.to_sym] || @separators_re
              suffix = end_with_slash ? SLASH_STR : ""
              RegexpNode.new(key,  prefix, re, suffix)
						else
							case m[0][0]
							when ?* then
								key = m[4]
                requirement = requirements[key.to_sym] unless key.empty?
								StarNode.new(key, requirement, end_with_slash)
							when ?( then
								optional_node, remaining =
									parse_optional_path(path, m[1], m.post_match, requirements)
								optional_node
							else
								str = m[0]
								StrNode.new(str)
							end
						end
					current_node = current_node.add_node(node)
				end

				raise InvalidPathError, "path: #{path}, remaining: #{remaining}" unless remaining.empty?
				current_node
			end

      def parse_optional_path(path, optional_path, post_path, requirements)
        # replace (\((:id)) to ((:id))
        safe_path = optional_path.gsub(/\\\(/, '')
        left_parenthesis_count = safe_path.count(LEFT_PARENTHESIS)
        right_parenthesis_count = safe_path.count(RIGHT_PARENTHESIS)

        while right_parenthesis_count < left_parenthesis_count
          m = NEXT_RIGHT_PARENTHESIS.match(post_path)
          raise InvalidPathError, "path: #{path}" if m.nil?
          post_path = m.post_match
          next if m[1][-1] == ?\ #skip \)
          optional_path << m[0]
          right_parenthesis_count += 1
        end
        sub_path = optional_path[1..-2]

        optional_node = OptionalNode.new(sub_path)
        unless @optional_root_node_cache[sub_path]
          child_node = parse(optional_node.root, sub_path, requirements)
          optional_node.optimize_root
          @optional_root_node_cache[sub_path] = optional_node.root
        end
        optional_node.root = @optional_root_node_cache[sub_path]
        [optional_node, post_path]
      end

    end

  end
end

