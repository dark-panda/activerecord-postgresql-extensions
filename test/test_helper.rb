

if RUBY_VERSION >= '1.9'
  require 'simplecov'

  SimpleCov.command_name('Unit Tests')
  SimpleCov.start do
    add_filter '/test/'
  end
end

require 'rubygems'
require 'active_record'
require 'logger'
require 'minitest/autorun'

if RUBY_VERSION >= '1.9'
  require 'minitest/reporters'
end

require File.join(File.dirname(__FILE__), *%w{ .. lib activerecord-postgresql-extensions })

ActiveRecord::Base.logger = Logger.new("debug.log") if ENV['ENABLE_LOGGER']
ActiveRecord::Base.configurations = {
  'arunit' => {}
}

%w{
  database.yml
  local_database.yml
}.each do |file|
  file = File.join('test', file)

  next unless File.exists?(file)

  configuration = YAML.load(File.read(file))

  if configuration['arunit']
    ActiveRecord::Base.configurations['arunit'].merge!(configuration['arunit'])
  end

  if defined?(JRUBY_VERSION) && configuration['jdbc']
    ActiveRecord::Base.configurations['arunit'].merge!(configuration['jdbc'])
  end
end

ActiveRecord::Base.establish_connection 'arunit'
ARBC = ActiveRecord::Base.connection

puts "Ruby version #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} - #{RbConfig::CONFIG['RUBY_INSTALL_NAME']}"
puts "Testing against ActiveRecord #{Gem.loaded_specs['activerecord'].version.to_s}"
if postgresql_version = ActiveRecord::PostgreSQLExtensions.SERVER_VERSION
  puts "PostgreSQL info from pg_catalog.version(): #{postgresql_version}"
end

if postgis_version = ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib]
  puts "PostGIS info from postgis_full_version(): #{postgis_version}"
else
  puts "PostGIS not installed"
end

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def real_execute
    @real_execute = true
    yield
  ensure
    @real_execute = false
  end

  def execute_with_statement_capture(*args)
    PostgreSQLExtensionsTestHelper.add_statement(args.first)

    if @real_execute
      execute_without_statement_capture(*args)
    else
      if RUBY_PLATFORM == 'java'
        if args.first =~ /pg_tables/
          return execute_without_statement_capture(*args)
        end
      end

      args.first
    end
  end
  alias_method_chain :execute, :statement_capture

  unless RUBY_PLATFORM == 'java'
    def query_with_statement_capture(*args)
      if @real_execute
        query_without_statement_capture(*args)
      else
        PostgreSQLExtensionsTestHelper.add_statement(args.first)
      end
    end
    alias_method_chain :query, :statement_capture
  end
end

module PostgreSQLExtensionsTestHelper
  include ActiveRecord::PostgreSQLExtensions::Utils

  class << self
    def statements
      @statements ||= []
    end

    def clear_statements!
      @statements = []
    end

    def add_statement(sql)
      case sql
        when /SHOW search_path;/, /pg_tables/
          # ignore
        else
          ActiveRecord::Base.logger.debug(sql) if ENV['ENABLE_LOGGER']
          self.statements << sql
      end

      sql
    end
  end

  def clear_statements!
    PostgreSQLExtensionsTestHelper.clear_statements!
  end

  def statements
    PostgreSQLExtensionsTestHelper.statements
  end

  def setup
    clear_statements!
  end
end

class ActiveRecord::Migration
  def say(*args)
    # no-op -- we just want it to be quiet.
  end
end

class Mig < ActiveRecord::Migration
end

class Foo < ActiveRecord::Base
end

class PostgreSQLExtensionsTestCase < ActiveRecord::TestCase
  include ActiveRecord::TestFixtures
  include PostgreSQLExtensionsTestHelper

  attr_writer :tagged_logger

  def before_setup
    if tagged_logger
      heading = "#{self.class}: #{__name__}"
      divider = '-' * heading.size
      tagged_logger.info divider
      tagged_logger.info heading
      tagged_logger.info divider
    end
    super
  end

  private
    def tagged_logger
      @tagged_logger ||= (defined?(ActiveRecord::Base.logger) && ActiveRecord::Base.logger)
    end
end

if RUBY_VERSION >= '1.9'
  MiniTest::Reporters.use!(MiniTest::Reporters::SpecReporter.new)
end

