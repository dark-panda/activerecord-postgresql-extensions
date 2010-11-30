
require 'active_record/connection_adapters/postgresql_adapter'

require File.join(File.dirname(__FILE__), 'postgresql_adapter_extensions')
require File.join(File.dirname(__FILE__), 'postgresql_constraints')
require File.join(File.dirname(__FILE__), 'postgresql_tables')
require File.join(File.dirname(__FILE__), 'postgresql_indexes')
require File.join(File.dirname(__FILE__), 'postgresql_permissions')
require File.join(File.dirname(__FILE__), 'postgresql_schemas')
require File.join(File.dirname(__FILE__), 'postgresql_languages')
require File.join(File.dirname(__FILE__), 'postgresql_rules')
require File.join(File.dirname(__FILE__), 'postgresql_functions')
require File.join(File.dirname(__FILE__), 'postgresql_sequences')
require File.join(File.dirname(__FILE__), 'postgresql_triggers')
require File.join(File.dirname(__FILE__), 'postgresql_views')
require File.join(File.dirname(__FILE__), 'postgresql_geometry')
require File.join(File.dirname(__FILE__), 'foreign_key_associations')

ActiveRecord::Base.send(:include, ActiveRecord::ForeignKeyAssociations)

