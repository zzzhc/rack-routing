
require File.expand_path("../abstract_unit", __FILE__)

class RecognizeTest < RoutingTestCase

	def setup
		super
		@routes = load_fixture(PathApp, "r1.txt")
	end

	def test_recognize
		assert_recognize({:action => "index", :controller => "root"}, "/", :root)
    assert_recognize({:action => "index", :controller => "network/advertising/company"}, "/advertising/companies", :companies, "GET")
    assert_recognize({:action => "create", :controller => "network/advertising/company"}, "/advertising/companies", nil, "POST")
	end

  def test_recognize_regexp_path
    assert_recognize(
      {:action=>"edit", :controller=>"network/advertising/company", :id => "99", :format => "json"},
      "/advertising/companies/99/edit.json",
      :edit_company,
      "GET"
    )
  end

  def test_recognize_optional_path
		assert_recognize({:action => "search", :controller => "network/advertising/company", :format => "json"}, "/advertising/companies/search.json", :search_companies, "GET")
    assert_recognize({:action => "index", :controller => "users", :locale => "en"}, "/en/users", :locale_user)
  end

  def test_recognize_plus_method
		assert_recognize({:action => "create_company", :controller => "users", :user_id => "1"}, "/users/1/company", nil, "POST")
  end

  def test_recognize_complex_optional_path
		assert_recognize({:action => "a", :controller => "c", :id => "1"}, "/c/a/1", nil, "GET")
  end

end
