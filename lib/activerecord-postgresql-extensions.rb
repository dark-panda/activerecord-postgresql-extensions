
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module PostgreSQLExtensions
  end
end

dirname = File.join(File.dirname(__FILE__), *%w{ active_record postgresql_extensions })

%w{
  adapter_extensions
  constraints
  tables
  tablespaces
  indexes
  permissions
  schemas
  languages
  rules
  functions
  sequences
  triggers
  views
  geometry
  types
  roles
  text_search
  extensions
  foreign_key_associations
}.each do |file|
  require File.join(dirname, file)
end

ActiveRecord::Base.send(:include, ActiveRecord::PostgreSQLExtensions::ForeignKeyAssociations)

