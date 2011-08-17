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
    next unless line.index("/services/site/")
    next unless (line =~ /^\s*([a-z0-9_-]*?)\s+([A-Z]*)\s+(\/[^\s]*)\s*(\{.+\})?$/)
    name, method, path, defaults = $1, $2, $3, $4
    name = nil if name.empty?
    method = nil if method.empty?
    defaults = defaults ? eval(defaults) : {}
    puts "#{name} #{method} #{path}"
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

root.write_graph("2.svg")
#path = "/system/user_setup/users/search"
path = "/system/user_setup/users/1/profile"

t1 = Time.now
count = 1000
(0...count).each do |i|
  env = {
    "PATH_INFO" => path,
    "REQUEST_METHOD" => "GET"
  }
  unless app = route_set.recognize(env)
    puts "ERROR"
  end
end
t2 = Time.now
puts "recognize time: #{t2 - t1}, count=#{count}, #{(t2-t1)/count}"

t1 = Time.now
count = routes_data.size
routes_data.each do |name, method, path, defaults|
  path = path.sub("(.:format)", ".html").gsub(/:\w+/, "1")
  env = {
    "PATH_INFO"      => path,
    "REQUEST_METHOD" => method
  }
  result = route_set.call(env)
  if result[0] != 200
    puts "ERROR: #{method}##{path}\nenv: #{env.inspect}\nresult: #{result.inspect}"
  end
end
t2 = Time.now
puts "call route time: #{t2 - t1}, count=#{count}, #{(t2-t1)/count}"

=begin
routes_data.each do |name, method, path, defaults|
  params = path.scan(/:([\w_]+)/).flatten.inject({}) do |memo, key|
    memo[key.to_sym] = ":#{key}"
    memo
  end
  puts route_set.path_for(defaults.merge(params))
end
=end
