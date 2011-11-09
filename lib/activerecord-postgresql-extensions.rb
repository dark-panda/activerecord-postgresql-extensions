
require 'active_record/connection_adapters/postgresql_adapter'

module PostgreSQLExtensions
end

dirname = File.join(File.dirname(__FILE__), 'postgresql_extensions')

%w{
  postgresql_adapter_extensions
  postgresql_constraints
  postgresql_tables
  postgresql_indexes
  postgresql_permissions
  postgresql_schemas
  postgresql_languages
  postgresql_rules
  postgresql_functions
  postgresql_sequences
  postgresql_triggers
  postgresql_views
  postgresql_geometry
  postgresql_types
  postgresql_roles
  postgresql_text_search
  postgresql_extensions
  foreign_key_associations
}.each do |file|
  require File.join(dirname, file)
end

ActiveRecord::Base.send(:include, PostgreSQLExtensions::ActiveRecord::ForeignKeyAssociations)

