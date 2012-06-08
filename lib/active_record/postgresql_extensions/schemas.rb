
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      # Creates a new PostgreSQL schema.
      #
      # Note that you can grant privileges on schemas using the
      # grant_schema_privileges method and revoke them using
      # revoke_schema_privileges.
      #
      # ==== Options
      #
      # * <tt>:authorization</tt> - adds an AUTHORIZATION clause. This is
      #   used to set the owner of the schema. This can be changed with
      #   alter_schema_owner as necessary.
      def create_schema(schema, options = {})
        sql = "CREATE SCHEMA #{quote_schema(schema)}"
        sql << " AUTHORIZATION #{quote_role(options[:authorization])}" if options[:authorization]
        execute("#{sql};")
      end

      # Drops a schema.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_schema(schemas, options = {})
        sql = 'DROP SCHEMA '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array(schemas).collect { |s| quote_schema(s) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Alter's a schema's name.
      def alter_schema_name(old_schema, new_schema)
        execute("ALTER SCHEMA #{quote_schema(old_schema)} RENAME TO #{quote_schema(new_schema)};")
      end

      # Changes a schema's owner.
      def alter_schema_owner(schema, role)
        execute("ALTER SCHEMA #{quote_schema(schema)} OWNER TO #{quote_role(role)};")
      end
    end
  end
end
