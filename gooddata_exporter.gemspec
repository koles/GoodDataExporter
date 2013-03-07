Gem::Specification.new do |s|
  s.name        = 'gooddata_exporter'
  s.version     = '0.1.0'
  s.date        = '2013-03-07'
  s.summary     = "Command line tool that exports metadata from GoodData project and imports it to another project."
  s.description = "Command line tool that exports metadata from GoodData project and imports it to another project."
  s.authors     = ["Zdenek Svoboda"]
  s.email       = 'zsvoboda@gmail.com'
  s.files       = ["lib/gooddata_exporter.rb"]
  s.homepage    = 'https://github.com/zsvoboda/GoodDataExporter'
  s.executables << 'gdci'
end