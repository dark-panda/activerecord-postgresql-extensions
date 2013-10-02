
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
          copy_from_freeze
          copy_from_encoding
          copy_from_program
          foreign_tables
          materialized_views
          modify_mass_privileges
          postgis
          view_if_exists
          view_set_options
        }.each do |feature|
          self.class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def #{feature}?
              sniff_features unless sniffed?
              !!@has_#{feature}
            end
          RUBY
        end

        def check_feature(feature)
          if !self.send("#{feature}?")
            raise ActiveRecord::PostgreSQLExtensions::FeatureNotSupportedError.new(feature)
          end
        end

        private
          def sniffed?
            @sniffed
          end

          def sniff_features
            @sniffed = true

            if ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.3'
              @has_copy_from_freeze = true
              @has_copy_from_program = true
              @has_materialized_views = true
            end

            if ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.1'
              @has_extensions = true
              @has_foreign_tables = true
              @has_copy_from_encoding = true
              @has_view_if_exists = true
              @has_view_set_options = true
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
