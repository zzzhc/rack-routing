require 'rubygems'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rack/routing'
require 'test/unit'

class Rack::Routing::RouteSet
  attr_reader :root
end

PathApp = lambda do |env|
  [200, {'Content-Type' => 'text/plain'}, env["PATH_INFO"]]
end

class RoutingTestCase < Test::Unit::TestCase

  include Rack::Routing

  def load_routes_data(routes_file)
    File.readlines(routes_file).map do |line|
      next unless (line =~ /^\s*([a-z0-9_-]*?)\s+([A-Z]*)\s+(\/[^\s]*)\s*(\{.+\})?$/)
      name, method, path, defaults = $1, $2, $3, $4
      name = nil if name.empty?
      method = nil if method.empty?
      defaults = defaults ? eval(defaults) : {}
      [name, method, path, defaults]
    end.compact
  end

  def load_routes(app, routes_file, route_set = nil)
    route_set ||= RouteSet.new
    load_routes_data(routes_file).each do |name, method, path, defaults|
      conditions = {
        :path_info      => path,
        :request_method => method
      }
      route_set.add_route(app, conditions, defaults, name)
    end
    route_set
  end

  def load_fixture(app, fixture, route_set = nil)
    file = File.expand_path("../fixtures/#{fixture}", __FILE__)
    load_routes(app, file, route_set)
  end

  def assert_recognize(params, path, named = nil, method = "GET")
    env = {
      "PATH_INFO"      => path,
      "REQUEST_METHOD" => method
    }
    route, actual_params, remaining_path = @routes.recognize(env)
    assert_equal(params, actual_params)
    assert_equal(named, route.name)
    assert_equal("", remaining_path)
  end

  def default_test
  end

end

