
module ActiveRecord
  module PostgreSQLExtensions
    class FeatureNotSupportedError < Exception
      def initialize(feature)
        super(%{The feature "#{feature}" is not supported by server. (Server version #{ActiveRecord::PostgreSQLExtensions.SERVER_VERSION}.)"})
      end
    end

    module Features
      class << self
        def extensions?
          if defined?(@has_extensions)
            @has_extensions
          else
            @has_extensions = ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.1'
          end
        end

        def foreign_tables?
          if defined?(@has_foreign_tables)
            @has_foreign_tables
          else
            @has_foreign_tables = ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.1'
          end
        end

        def modify_mass_privileges?
          if defined?(@has_modify_mass_privileges)
            @has_modify_mass_privileges
          else
            @has_modify_mass_privileges = ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.0'
          end
        end

        def postgis?
          if defined?(@has_postgis)
            @has_postgis
          else
            @has_postgis = !!ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION
          end
        end
      end
    end
  end
end
