module Rack
  module Routing

    module NodeGraphViz

      def to_graph
        require 'graphviz'
        g = ::GraphViz.new("structs", :type => :digraph)
        g.node["shape"] = "record"
        g.node["style"] = "rounded"
        add_graph_node(g)
        g
      end

      def write_graph(svg_file)
        to_graph.output(:svg => svg_file)
      end

      private
      @@node_id_counter = 0

      def add_graph_node(g)
        node_id = "node_#{@@node_id_counter += 1}"

        labels = ["<name> #{self.class.name.sub(/.*:/, "")}"]
        %w(str key prefix re suffix path).each do |attr|
          next unless respond_to?(attr)
          value = send(attr)
          next if value.nil?
          value = value.source if Regexp === value
          value = value.to_s.gsub(/>/, '&gt;').gsub(/</, '&lt;')
          labels << "#{attr}=#{value}"
        end
        labels << "/" if respond_to?(:end_with_slash?) && end_with_slash?
        labels << "<root> root" if OptionalNode === self
        labels << "<children> children" if has_child?
        labels << "<routes> routes" if routes.size > 0

        g.add_node(node_id, "shape" => "record", "label" => "{#{labels.join("|")}}")

        (str_children.values + self.children).each do |child|
          child_node_id = child.send(:add_graph_node, g)
          g.add_edge({"#{node_id}" => "children"}, {"#{child_node_id}" => "name"})
        end

        if OptionalNode === self
          child_node_id = root.send(:add_graph_node, g)
          g.add_edge({"#{node_id}" => "root"}, {"#{child_node_id}" => "name"})
        end

        add_graph_routes(g, node_id)

        node_id
      end

      def add_graph_routes(g, node_id)
        routes.each do |route|
          child_node_id = "node_#{@@node_id_counter += 1}"
          labels = ["<name> #{route.class.name.sub(/.*:/, "")}"]
          labels << route.request_method.source if RequestMethodRoute === route
          labels << "any" if NoConditionRoute === route
          g.add_node(child_node_id, "shape" => "record", "label" => "{#{labels.join("|")}}")

          g.add_edge({"#{node_id}" => "routes"}, {"#{child_node_id}" => "name"})
        end

      end

    end

  end
end
