
require 'active_record/postgresql_extensions/table_definition/shared'

if ActiveRecord::VERSION::STRING >= "4.0"
  require 'active_record/postgresql_extensions/table_definition/rails_4'
else
  require 'active_record/postgresql_extensions/table_definition/rails_3'
end

