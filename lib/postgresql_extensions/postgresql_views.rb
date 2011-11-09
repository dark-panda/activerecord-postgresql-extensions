
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      # Creates a new PostgreSQL view.
      #
      # +name+ is the name of the view. View quoting works the same as
      # table quoting, so you can use PostgreSQLAdapter#with_schema and
      # friends. See PostgreSQLAdapter#with_schema and
      # PostgreSQLAdapter#quote_table_name for details.
      #
      # +query+ is the SELECT query to use for the view. This is just
      # a straight-up String, so quoting rules will not apply.
      #
      # Note that you can grant privileges on views using the
      # grant_view_privileges method and revoke them using
      # revoke_view_privileges.
      #
      # ==== Options
      #
      # * <tt>:replace</tt> - adds a REPLACE clause, as in "CREATE OR
      #   REPLACE".
      # * <tt>:temporary</tt> - adds a TEMPORARY clause.
      # * <tt>:columns</tt> - you can rename the output columns as
      #   necessary. Note that this can be an Array and that it must be
      #   the same length as the number of output columns created by
      #   +query+.
      #
      # ==== Examples
      #
      #  ### ruby
      #  create_view(:foo_view, 'SELECT * FROM bar')
      #  # => CREATE VIEW "foo_view" AS SELECT * FROM bar;
      #
      #  create_view(
      #    { :geospatial => :foo_view },
      #    'SELECT * FROM bar',
      #    :columns => [ :id, :name, :the_geom ]
      #  )
      #  # => CREATE VIEW "geospatial"."foo_view" ("id", "name", "the_geom") AS SELECT * FROM bar;
      def create_view(name, query, options = {})
        execute PostgreSQLViewDefinition.new(self, name, query, options).to_s
      end

      # Drops a view.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_view(name, options = {})
        sql = 'DROP VIEW '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array(name).collect { |v| quote_view_name(v) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Renames a view.
      def rename_view(name, new_name, options = {})
        execute "ALTER TABLE #{quote_view_name(name)} RENAME TO #{quote_generic_ignore_schema(new_name)};"
      end

      # Change the ownership of a view.
      def alter_view_owner(name, role, options = {})
        execute "ALTER TABLE #{quote_view_name(name)} OWNER TO #{quote_role(role)};"
      end

      # Alter a view's schema.
      def alter_view_schema(name, schema, options = {})
        execute "ALTER TABLE #{quote_view_name(name)} SET SCHEMA #{quote_schema(schema)};"
      end
    end

    # Creates a PostgreSQL view definition. This class isn't really meant
    # to be used directly. Instead, see PostgreSQLAdapter#create_view
    # for usage.
    class PostgreSQLViewDefinition
      attr_accessor :base, :name, :query, :options

      def initialize(base, name, query, options = {}) #:nodoc:
        @base, @name, @query, @options = base, name, query, options
      end

      def to_sql #:nodoc:
        sql = 'CREATE '
        sql << 'OR REPLACE ' if options[:replace]
        sql << 'TEMPORARY ' if options[:temporary]
        sql << "VIEW #{base.quote_view_name(name)} "
        if options[:columns]
          sql << '(' << Array(options[:columns]).collect do |c|
            base.quote_column_name(c)
          end.join(', ') << ') '
        end
        sql << "AS #{query}"
        "#{sql};"
      end
      alias :to_s :to_sql
    end
  end
end
