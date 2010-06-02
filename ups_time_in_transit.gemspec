# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ups_time_in_transit}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Joe Stelmach"]
  s.cert_chain = ["/Users/joe/workspace/personal/gem-public_cert.pem"]
  s.date = %q{2010-06-01}
  s.description = %q{Provides an easy to use interface to the UPS time in transit API}
  s.email = %q{joestelmach @nospam@ gmail.com}
  s.extra_rdoc_files = ["LICENSE", "README", "lib/ups_time_in_transit.rb"]
  s.files = ["LICENSE", "Manifest", "README", "Rakefile", "lib/ups_time_in_transit.rb", "ups_time_in_transit.gemspec"]
  s.homepage = %q{http://github.com/joestlemach/ups_time_in_transit}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Ups_time_in_transit", "--main", "README"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ups_time_in_transit}
  s.rubygems_version = %q{1.3.5}
  s.signing_key = %q{/Users/joe/workspace/personal/gem-private_key.pem}
  s.summary = %q{Provides an easy to use interface to the UPS time in transit API}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 0"])
    else
      s.add_dependency(%q<activesupport>, [">= 0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 0"])
  end
end
