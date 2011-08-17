#!/usr/bin/env ruby


require 'rubygems'
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'benchmark'
require 'rack/mount'
require 'rack/routing'
include Rack::Routing

routes_file = File.expand_path("../routes.r3.txt", __FILE__)
routes_data = File.readlines(routes_file).map do |line|
	next unless (line =~ /^\s*([a-z0-9_-]*?)\s+([A-Z]*)\s+(\/[^\s]*)\s*(\{.+\})?$/)
	name, method, path, defaults = $1, $2, $3, $4
	name = nil if name.empty?
	method = nil if method.empty?
	defaults = defaults ? eval(defaults) : {}
	[name, method, path, defaults]
end.compact

def load_routing_routes(routes_data, app)
	route_set = RouteSet.new
	routes_data.each do |name, method, path, defaults|
		conditions = {
			:path_info => path,
			:request_method => method
		}
		route_set.add_route(app, conditions, defaults, name)
	end
	route_set
end

def load_rack_mount_routes(routes_data, app)
	separators = %w( / ? . )
	Rack::Mount::RouteSet.new do |set|
		routes_data.each do |name, method, path, defaults|
			re = Rack::Mount::Strexp.compile(path, {}, separators)
			set.add_route app, { :request_method => method, :path_info => re }, {}, name
		end
	end
end

routing_routes = nil
mount_routes = nil
app = lambda { |env| [200, {}, env["PATH_INFO"]] }

puts "load routes"
Benchmark.bm(15) do |x|
	x.report("rack routing") { routing_routes = load_routing_routes(routes_data, app) }
	x.report("rack mount") { mount_routes = load_rack_mount_routes(routes_data, app) }
end

envs = [
	{
		"PATH_INFO" => "/",
		"REQUEST_METHOD" => "GET"
	},
	{
		"PATH_INFO" => "/system/user_setup/users/1/profile",
		"REQUEST_METHOD" => "GET"
	},
	{
		"PATH_INFO" => "/services/transcode/1",
		"REQUEST_METHOD" => "DELETE"
	}
]
times = 10000
puts "call app"
envs.each do |env|
	puts "  call #{env["PATH_INFO"]}"
	Benchmark.bmbm(15) do |x|
		x.report("rack routing") do
			times.times do
				routing_routes.call(env.dup)
			end
		end
		x.report("rack mount") do
			times.times do
				mount_routes.call(env.dup)
			end
		end
	end
end

samples = [
	[:root, {}],
	[:profile_user, {:id => 1}],
	[:services_transcode, {:id => 1}]
]
times = 10000
puts "generate url"
samples.each do |sample|
	name, params = sample
	puts "name: #{name}, params: #{params.inspect}"
	Benchmark.bmbm(15) do |x|
		x.report("rack routing") do
			times.times do
				routing_routes.path_for(name, params.dup)
			end
		end
		x.report("rack mount") do
			times.times do
				mount_routes.generate(:path_info, name, params.dup)
			end
		end
	end
end

