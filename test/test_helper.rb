
ACTIVERECORD_GEM_VERSION = ENV['ACTIVERECORD_GEM_VERSION'] || '~> 3.2.0'

require 'rubygems'
gem 'activerecord', ACTIVERECORD_GEM_VERSION

require 'active_record'
require 'test/unit'
require 'logger'
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

puts "Testing against ActiveRecord #{Gem.loaded_specs['activerecord'].version.to_s}"
if postgresql_version = ARBC.query('SELECT version()').flatten.to_s
  puts "PostgreSQL info from version(): #{postgresql_version}"
end

if postgis_version = ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib]
  puts "PostGIS info from postgis_full_version(): #{postgis_version}"
else
  puts "PostGIS not installed"
end

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def statements
    @statements ||= []
  end

  def execute_with_statement_capture(sql, name = nil)
    PostgreSQLExtensionsTestHelper.add_statement(sql)
    #execute_without_statement_capture(sql, name)
  end
  alias_method_chain :execute, :statement_capture

  def query_with_statement_capture(sql, name = nil)
    PostgreSQLExtensionsTestHelper.add_statement(sql)
    #query_without_statement_capture(sql, name)
  end
  alias_method_chain :query, :statement_capture
end

module PostgreSQLExtensionsTestHelper
  class << self
    def statements
      @statements ||= []
    end

    def clear_statements!
      @statements = []
    end

    def add_statement(sql)
      case sql
        when /SHOW search_path;/
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

class Mig < ActiveRecord::Migration
end

class Foo < ActiveRecord::Base
end
