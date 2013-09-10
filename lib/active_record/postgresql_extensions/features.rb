
module ActiveRecord
  module PostgreSQLExtensions
    class FeatureNotSupportedError < Exception
      def initialize(feature)
        super(%{The feature "#{feature}" is not supported by server. (Server version #{ActiveRecord::PostgreSQLExtensions.SERVER_VERSION}.)"})
      end
    end

    module Features
      class << self
        %w{
          extensions
          foreign_tables
          modify_mass_privileges
          postgis
        }.each do |feature|
          self.class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def #{feature}?
              sniff_features unless sniffed?
              !!@has_#{feature}
            end
          RUBY
        end

        private
          def sniffed?
            @sniffed
          end

          def sniff_features
            @sniffed = true

            if ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.1'
              @has_extensions = true
              @has_foreign_tables = true
            end

            if ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.0'
              @has_modify_mass_privileges = true
            end

            if !!ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION
              @has_postgis = true
            end
          end
      end
    end
  end
end
