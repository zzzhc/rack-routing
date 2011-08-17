require File.expand_path("../abstract_unit", __FILE__)

class NodeParserTest < RoutingTestCase

  def setup
    super
    @parser = NodeParser.new
    @root = RootNode.new("/")
  end

  def test_parse_root
    path = "/"
    result = @parser.parse(@root, path)
    assert @root.str_children.empty?
    assert @root.children.empty?
    assert_equal @root, result
  end

  def test_parse_str
    [
      ["/users", "users"],
      ["/users/", "users/"]
    ].each do |path, expected|
      result = @parser.parse(@root, path)
      assert_equal expected, result.str
      assert_equal result, @root.str_children[expected]
      assert_equal @root, result.parent
    end
  end

  def test_parse_named_segment
    path = "/users/:id"
    id_re = %r{\d+}
    result = @parser.parse(@root, path, :id => id_re)
    assert RegexpNode === result
    assert_equal :id, result.key
    assert_equal %r{^(?:\d+)}, result.re
    assert_equal "users/", result.parent.str
    assert_equal @root, result.parent.parent
  end

  def test_parse_resources
    [
      "/users/new",
      "/users/:id",
      "/users/:id/edit",
      "/users/:id/roles/:role_id",
      "/users/:id/roles/:role_id/edit",
    ].each do |path|
      @parser.parse(@root, path)
    end
    users_node = @root.str_children["users/"]
    assert_equal 1, users_node.str_children.size
    assert_equal 2, users_node.children.size

    roles_node = users_node.children.find {|n|
      RegexpNode === n && n.key == :id && n.suffix == "/"
    }.str_children["roles/"]
    assert_equal 2, roles_node.children.size
  end

  def test_parse_star
    [
      ["/users/*id", {}, :id, StarNode::ANY_RE],
      ["/users/*id", {:id => /\d+/}, :id, /^(?:\d+)/],
      ["/users/*", {}, nil, StarNode::ANY_RE]
    ].each do |path, requirements, key, re|
      result = @parser.parse(@root, path, requirements)
      assert StarNode === result
      assert_equal key, result.key
      assert_equal re, result.re
    end
  end

  def test_parse_optional_node
    path = "/users(.:format)"
    result = @parser.parse(@root, path, :format => /\w+/)
    assert OptionalNode === result
    assert_equal false, result.has_child?
    assert RegexpNode === result.root
    assert_equal ".", result.root.prefix
    assert_equal /^(?:\w+)/, result.root.re
    assert_equal "", result.root.suffix
    assert_equal "users", result.parent.str

    path = "/(:locale/)users"
    result = @parser.parse(@root, path, :locale => /[\w-]+/)
    assert_equal "users", result.str
    assert @root.children.size == 1
    node = @root.children.first
    assert OptionalNode === node
    assert_equal result, node.str_children["users"]
    assert RegexpNode === node.root
    assert_equal :locale, node.root.key
    assert_equal "", node.root.prefix
    assert_equal /^(?:[\w-]+)/, node.root.re
    assert_equal "/", node.root.suffix
  end

  def test_parse_optional_node2
    path = "/:controller(/:action(/:id))"
    result = @parser.parse(@root, path, :controller => /\w+/, :action => /\w+/, :id => /\d+/)

    controller_node = @root.children.first
    assert RegexpNode === controller_node
    assert_equal :controller, controller_node.key
    assert_equal /^(?:\w+)/, controller_node.re

    assert OptionalNode === result
    assert_equal "/:action(/:id)", result.path
    assert RootNode === result.root
    assert_equal "/", result.root.str

    action_node = result.root.children.first
    assert RegexpNode === action_node
    assert_equal :action, action_node.key
    assert_equal /^(?:\w+)/, action_node.re

    id_optional_node = action_node.children.first
    assert OptionalNode === id_optional_node
    assert_equal "/", id_optional_node.root.str

    id_node = id_optional_node.root.children.first
    assert_equal "", id_node.prefix
    assert_equal /^(?:\d+)/, id_node.re
    assert_equal "", id_node.suffix
  end

end
