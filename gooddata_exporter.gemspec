Gem::Specification.new do |s|
  s.name = %q{gooddata_exporter}
  s.version = "0.1.7"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Zdenek Svoboda"]
  s.date = %q{2013-03-07}
  s.description = %q{Run the gdci commandline with the --help option to learn how to export and import a GoodData project metadata.}
  s.email = %q{zd@gooddata.com}
  s.executables = ["gdci"]
  s.extra_rdoc_files = [
      "LICENSE",
      "README.rdoc"
  ]
  s.files = [
      "LICENSE",
      "README.rdoc",
      "VERSION",
      "bin/gdci",
      "lib/gooddata_exporter.rb"
  ]
  s.homepage = %q{https://github.com/zsvoboda/GoodDataExporter}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Tool for exporting and importing GoodData metadata}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json>, [">= 0"])
      s.add_runtime_dependency(%q<gooddata>, [">= 0"])
    else
      s.add_dependency(%q<json>, [">= 0"])
      s.add_runtime_dependency(%q<gooddata>, [">= 0"])
    end
  else
    s.add_dependency(%q<json>, [">= 0"])
    s.add_runtime_dependency(%q<gooddata>, [">= 0"])
  end
end
