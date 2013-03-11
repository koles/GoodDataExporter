#!/usr/bin/env ruby

require 'gooddata_exporter'
require 'logger'
require 'json'
require 'getoptlong'
require '../lib/gooddata_exporter'

def options
  config_file_locations = ['.gooddata', File.expand_path(File.dirname(File.dirname(__FILE__)))+'/.gooddata', ENV['HOME']+'/.gooddata']
  config_file_locations.each {
      |path|
    if File.exists?(path)
      opt = JSON.parse(open(path).read())
      puts "Retrieving options from '#{path}'."
      return opt
    end
  }
end

o = options

GoodData::connect(o['username'], o['password'])
GoodData.project = 'alobesvmeuze3hhwevp6juokl5ixjr16'
exporter = GdcEraser.new()

exporter.drop_all_objects('alobesvmeuze3hhwevp6juokl5ixjr16', 'dimensions')


