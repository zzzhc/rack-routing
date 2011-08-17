#!/usr/bin/env ruby

require 'rubygems'
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require 'rack/routing'
include Rack::Routing
route_set = RouteSet.new
root = route_set.instance_variable_get("@root")
app = lambda { |env| [200, {}, env["PATH_INFO"]] }

def mm
	total0 = `free`.split[-5].to_i
	yield
	total1 = `free`.split[-5].to_i
	puts "memory usage: #{total0 - total1}"
end

routes_data = nil
mm do
  t1 = Time.now
  routes_file = File.expand_path("../routes.r3.txt", __FILE__)
  routes_data = File.readlines(routes_file).map do |line|
    next unless (line =~ /^\s*([a-z0-9_-]*?)\s+([A-Z]*)\s+(\/[^\s]*)\s*(\{.+\})?$/)
    name, method, path, defaults = $1, $2, $3, $4
    name = nil if name.empty?
    method = nil if method.empty?
    defaults = defaults ? eval(defaults) : {}
    [name, method, path, defaults]
  end.compact

  routes_data.each do |name, method, path, defaults|
    conditions = {
      :path_info => path,
      :request_method => method
    }
    route_set.add_route(app, conditions, defaults, name)
  end

  t2 = Time.now
  puts "time: #{t2 - t1}"
end
