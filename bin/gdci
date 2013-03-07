#!/usr/bin/env ruby

require 'gooddata_exporter'
require 'logger'
require 'json'
require 'getoptlong'


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

opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--dir', '-d', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--username', '-u', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--password', '-p', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--source', '-s', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--target', '-t', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--labels', '-l', GetoptLong::OPTIONAL_ARGUMENT ]
)

out_dir = ""
username = ""
password = ""
source_project = ""
target_project = ""
identifiers = []
primary_labels = {}

opts.each do |opt, arg|
  case opt
    when '--help'
      puts "gdi.rb [options]

-h, --help:
   show help

--dir [output-directory], -d [output-directory]:
  Directory where the export/import stores/retrieves metadata objects.

--username [gooddata-username], -u [gooddata-username]
  Valid GoodData username. You can also store the username in the .gooddata JSON file located in the current directory,
  script directory, or your home directory. Example: {'username'':'you@gooddata.com', 'password':'password'}

--password [gooddata-password], -u [gooddata-password]
  Valid GoodData password. You can also store the password in the .gooddata JSON file located in the current directory,
  script directory, or your home directory. Example: {'username'':'you@gooddata.com', 'password':'password'}

--source [source-project], -s [source-project]
  An existing GoodData project where the metadata objects will be retrieved from.

--target [target-project], -t [target-project]
  An existing GoodData project where the metadata objects will be stored.

--labels [attribute-primary-labels], -l [attribute-primary-labels]
  Ruby hash that identifies the primary label for each attribute that has multiple labels. The primary label must
  uniquely identify every attribute element. (e.g. {'attr.user.userid'=>'label.user.userid', 'attr.account.id'=>'label.account.id'}
"
    when '--dir'
      if File.exists?(arg)
        out_dir = arg
      else
        puts "The output directory #{arg} doesn't exist! Please create it."
        exit 1
      end
    when '--username'
      username = arg
    when '--password'
      password = arg
    when '--source'
      source_project = arg
    when '--target'
      target_project = arg
    when '--labels'
      if (not arg.nil?) and arg.size > 0
        primary_labels = eval(arg)
      end
  end
end

o = options

if out_dir.nil? or out_dir.size <= 0
  puts "INFO: Parameter --dir not specified. Looking in config file."
  out_dir = o['dir']
  if out_dir.nil? or out_dir.size <= 0
    out_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))
    puts "INFO: Parameter --dir not found in config file. Defaulting to the current directory '#{out_dir}'"
  end
end

if username.nil? or username.size <= 0
  puts "INFO: Parameter --username not specified. Looking in config file."
  username = o['username']
  if username.nil? or username.size <= 0
    puts "ERROR: Parameter --username not found in config file. Please specify a valid GoodData username."
    exit 1
  end
end

if password.nil? or password.size <= 0
  puts "INFO: Parameter --password not specified. Looking in config file."
  password = o['password']
  if password.nil? or password.size <= 0
    puts "ERROR: Parameter --password not found in config file. Please specify a valid GoodData password."
    exit 1
  end
end

if source_project.nil? or source_project.size <= 0
  puts "INFO: Parameter --source not specified. Looking in config file."
  source_project = o['source']
  if source_project.nil? or source_project.size <= 0
    puts "ERROR: Parameter --source not found in config file. Please specify a valid GoodData source project."
    exit 1
  end
end

if target_project.nil? or target_project.size <= 0
  puts "INFO: Parameter --target not specified. Looking in config file."
  target_project = o['target']
  if target_project.nil? or target_project.size <= 0
    puts "ERROR: Parameter --target not found in config file. Please specify a valid GoodData target project."
    exit 1
  end
end

if primary_labels.nil? or primary_labels.size <= 0
  puts "INFO: Parameter --labels not specified. Looking in config file."
  primary_labels = eval(o['labels'])
  if primary_labels.nil? or primary_labels.size <= 0
    puts "INFO: Parameter --labels not found in config file. Using empty mapping as default."
  end
end

command =  ARGV.shift

identifiers = eval(ARGV.shift)

puts "#{command}: #{identifiers}"

#GoodData::connect(c['username'], c['password'])



