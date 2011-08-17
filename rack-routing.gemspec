Gem::Specification.new do |s|
  s.name = %q{rack-routing}
  s.version = "0.1"
  s.authors = ["zzzhc"]
  s.date = Time.now.utc.strftime("%Y-%m-%d")
  s.email = %q{zzzhc.starfire@gmail.com}
  s.files = `git ls-files`.split("\n")
  s.homepage = %q{http://github.com/zzzhc/rack-routing}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
	s.summary = %q{rack routing}
  s.description = %q{A fast, little memory footprint rack routing implementation}
  s.test_files = `git ls-files test`.split("\n")
end

