
# -*- ruby -*-

require 'rubygems'

gem 'rdoc', '~> 3.12'

require 'rubygems/package_task'
require 'rake/testtask'
require 'rdoc/task'

if RUBY_VERSION >= '1.9'
  begin
    gem 'psych'
  rescue Exception => e
    # it's okay, fall back on the bundled psych
  end
end

$:.push 'lib'

version = File.read('VERSION') rescue ''

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "activerecord-postgresql-extensions"
    gem.summary = "A whole bunch of extensions the ActiveRecord PostgreSQL adapter."
    gem.description = gem.summary
    gem.email = "code@zoocasa.com"
    gem.homepage = "http://github.com/zoocasa/activerecord-postgresql-extensions"
    gem.authors =    [ "J Smith" ]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

desc 'Test PostgreSQL extensions'
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/**/*_tests.rb']
  t.verbose = false
end

desc 'Build docs'
Rake::RDocTask.new do |t|
  t.title = "ActiveRecord PostgreSQL Extensions #{version}"
  t.main = 'README.rdoc'
  t.rdoc_dir = 'doc'
  t.rdoc_files.include('README.rdoc', 'MIT-LICENSE', 'lib/**/*.rb')
end

