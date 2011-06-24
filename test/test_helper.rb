
ACTIVERECORD_GEM_VERSION = ENV['ACTIVERECORD_GEM_VERSION'] || '~> 3.0.3'

require 'rubygems'
gem 'activerecord', ACTIVERECORD_GEM_VERSION

require 'active_record'
require 'test/unit'
require File.join(File.dirname(__FILE__), *%w{ .. lib postgresql_extensions })

puts "Testing against ActiveRecord #{Gem.loaded_specs['activerecord'].version.to_s}"

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter => 'postgresql',
    :database => 'postgresql_extensions_unit_tests',
    :min_messages => 'warning'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
#ActiveRecord::Base.connection.drop_database('postgresql_extensions_unit_tests')
#ActiveRecord::Base.connection.create_database('postgresql_extensions_unit_tests')

ARBC = ActiveRecord::Base.connection

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def statements
    @statements ||= []
  end

  def execute_with_statement_capture(sql, name = nil)
    statements << sql
    #execute_without_statement_capture(sql, name)
  end
  alias_method_chain :execute, :statement_capture

  def query_with_statement_capture(sql, name = nil)
    statements << sql
    #query_without_statement_capture(sql, name)
  end
  alias_method_chain :query, :statement_capture

  def clear_statements!
    @statements = []
  end
end

module PostgreSQLExtensionsTestHelper
  def clear_statements!
    ActiveRecord::Base.connection.clear_statements!
  end

  def statements
    ActiveRecord::Base.connection.statements
  end

  def setup
    clear_statements!
  end
end

class Mig < ActiveRecord::Migration
end
