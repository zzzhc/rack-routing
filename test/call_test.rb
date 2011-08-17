require File.expand_path("../abstract_unit", __FILE__)

class CallTest < RoutingTestCase

	def setup
		super
		@routes = load_fixture(PathApp, "r1.txt")
    @routes.root.write_graph("tmp/1.svg")
	end

  def call_route(path, method, params = {})
    env = {
      "PATH_INFO"      => path,
      "REQUEST_METHOD" => method
    }
    @routes.call(env)
  end

  def assert_call(path, method, code, body = nil)
    response = call_route(path, method)
    assert_equal code, response[0]
    body ||= path
    assert_equal body, path
  end

  def test_call
    assert_call("/", "GET", 200)
    assert_call("/", "POST", 200)
    assert_call("/users/1/company", "GET", 200)
    assert_call("/users/1/company", "PUT", 404)
  end

end
