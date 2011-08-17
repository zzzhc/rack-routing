
require File.expand_path("../abstract_unit", __FILE__)

class PathForTest < RoutingTestCase

	def setup
		super
		@routes = load_fixture(PathApp, "r1.txt")
	end

  def test_path_for_named_route
    [
      [:root, "/"],
      [:search_companies, "/advertising/companies/search"],
      [:companies, "/advertising/companies"],
      [:new_company, "/advertising/companies/new"],
      [:edit_company, "/advertising/companies/1/edit", {:id => 1}],
      [:locale_user, "/en/users", {:locale => "en"}]
    ].each do |name, path, requirements|
      requirements ||= {}
      assert_equal path, @routes.path_for(name, requirements.dup)
      assert_equal "#{path}.json", @routes.path_for(name, {:format => "json"}.merge(requirements))
      assert_equal "#{path}?a=1&b=2", @routes.path_for(name, {"a" => 1, "b" => 2}.merge(requirements))
    end
  end

  def test_path_for_lookup_keys
    [
      ["/", {:action=>"index", :controller=>"root"}],
      ["/advertising/companies/search", {:action=>"search", :controller=>"network/advertising/company"}],
      ["/advertising/companies", {:action=>"index", :controller=>"network/advertising/company"}],
      ["/advertising/companies/new", {:action=>"new", :controller=>"network/advertising/company"}],
      ["/advertising/companies/1/edit", {:action=>"edit", :controller=>"network/advertising/company", :id => 1}],
      ["/en/users", {:action => "index", :controller => "users", :locale => "en"}]
    ].each do |path, params|
      assert_equal path, @routes.path_for(params.dup)
      assert_equal "#{path}.json", @routes.path_for({:format => "json"}.merge params)
      assert_equal "#{path}?a=1&b=2", @routes.path_for({"a" => 1, "b" => 2}.merge(params))
    end
  end

end
