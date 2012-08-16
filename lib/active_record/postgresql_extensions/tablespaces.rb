
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidTablespaceParameter < ActiveRecordError #:nodoc:
    def initialize(parameter)
      super("Invalid tablespace parameter - #{parameter}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates a new PostgreSQL tablespace.
      def create_tablespace(name, location, options = {})
        sql = "CREATE TABLESPACE #{quote_tablespace(name)} "
        sql << "OWNER #{quote_role(options[:owner])} " if options[:owner]
        sql << "LOCATION #{quote(location)}"

        execute("#{sql};")
      end

      # Drops a tablespace.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      def drop_tablespace(name, options = {})
        sql = 'DROP TABLESPACE '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << quote_tablespace(name)

        execute("#{sql};")
      end

      #ALTER TABLESPACE name SET ( tablespace_option = value [, ... ] )
      #ALTER TABLESPACE name RESET ( tablespace_option [, ... ] )

      # Renames a tablespace.
      def rename_tablespace(old_name, new_name)
        execute("ALTER TABLESPACE #{quote_tablespace(old_name)} RENAME TO #{quote_tablespace(new_name)};")
      end

      # Changes a tablespace's owner.
      def alter_tablespace_owner(tablespace, role)
        execute("ALTER TABLESPACE #{quote_tablespace(tablespace)} OWNER TO #{quote_role(role)};")
      end

      def alter_tablespace_parameters(tablespace, parameters_and_values)
        sql = "ALTER TABLESPACE #{quote_tablespace(tablespace)} SET ("

        sql << parameters_and_values.collect { |k, v|
          assert_valid_tablespace_parameter(k)
          "\n  #{quote_generic(k)} = #{v}"
        }.join(",")

        sql << "\n);"

        execute(sql)
      end

      def reset_tablespace_parameters(tablespace, *parameters)
        sql = "ALTER TABLESPACE #{quote_tablespace(tablespace)} RESET ("

        sql << parameters.flatten.collect { |k|
          assert_valid_tablespace_parameter(k)
          "\n  #{quote_generic(k)}"
        }.join(",")

        sql << "\n);"

        execute(sql)
      end

      private
        TABLESPACE_PARAMETERS = %w{ seq_page_cost random_page_cost }.freeze

        def assert_valid_tablespace_parameter(parameter)
          if !TABLESPACE_PARAMETERS.include? parameter.to_s.downcase
            raise ActiveRecord::InvalidTablespaceParameter.new(option)
          end
        end
    end
  end
end
