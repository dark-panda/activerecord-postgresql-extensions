
# -*- ruby -*-

require 'rubygems'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/rdoctask'

$:.push 'lib'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "postgresql-extensions"
    gem.summary = "A whole bunch of extensions the Rails PostgreSQL adapter."
    gem.description = gem.summary
    gem.email = "code@zoocasa.com"
    gem.homepage = "http://github.com/zoocasa/postgresql-extensions"
    gem.authors =    [ "J Smith" ]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

desc 'Test PostgreSQL extensions'
Rake::TestTask.new(:test) do |t|
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

desc 'Build docs'
Rake::RDocTask.new do |t|
  require 'rdoc'
  t.main = 'README.rdoc'
  t.rdoc_dir = 'doc'
  t.rdoc_files.include('README.rdoc', 'lib/**/*.rb')
end

