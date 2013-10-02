
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
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
      # * <tt>:with_options</tt> - sets view options. View options were added
      #   in PostgreSQL 9.1. See the PostgreSQL docs for details on the
      #   available options.
      # * <tt>:recursive</tt> - adds the RECURSIVE clause. Available in
      #   PostgreSQL 9.3+.
      #
      # ==== Examples
      #
      #   create_view(:foo_view, 'SELECT * FROM bar')
      #   # => CREATE VIEW "foo_view" AS SELECT * FROM bar;
      #
      #   create_view(
      #     { :geospatial => :foo_view },
      #     'SELECT * FROM bar',
      #     :columns => [ :id, :name, :the_geom ]
      #   )
      #   # => CREATE VIEW "geospatial"."foo_view" ("id", "name", "the_geom") AS SELECT * FROM bar;
      def create_view(name, query, options = {})
        execute PostgreSQLViewDefinition.new(self, name, query, options).to_s
      end

      # Drops a view.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_view(*args)
        options = args.extract_options!
        args.flatten!

        sql = 'DROP VIEW '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array.wrap(args).collect { |v| quote_view_name(v) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Renames a view.
      def rename_view(name, new_name, options = {})
        execute PostgreSQLViewAlterer.new(self, name, {
          :rename_to => new_name
        }, options).to_sql
      end

      # Change the ownership of a view.
      def alter_view_owner(name, role, options = {})
        execute PostgreSQLViewAlterer.new(self, name, {
          :owner_to => role
        }, options).to_sql
      end

      # Alter a view's schema.
      def alter_view_schema(name, schema, options = {})
        execute PostgreSQLViewAlterer.new(self, name, {
          :set_schema => schema
        }, options).to_sql
      end

      # Sets a view's options using a Hash.
      def alter_view_set_options(name, set_options, options = {})
        execute PostgreSQLViewAlterer.new(self, name, {
          :set_options => set_options
        }, options).to_sql
      end

      # Resets a view's options.
      def alter_view_reset_options(name, *args)
        options = args.extract_options!

        execute PostgreSQLViewAlterer.new(self, name, {
          :reset_options => args
        }, options).to_sql
      end

      # Set a column default on a view.
      def alter_view_set_column_default(name, column, expression, options = {})
        execute PostgreSQLViewAlterer.new(self, name, {
          :set_default => {
            column => expression
          }
        }, options).to_sql
      end

      # Drop a column default from a view.
      def alter_view_drop_column_default(name, column, options = {})
        execute PostgreSQLViewAlterer.new(self, name, {
          :drop_default => column
        }, options).to_sql
      end
    end

    # Creates a PostgreSQL view definition. This class isn't really meant
    # to be used directly. Instead, see PostgreSQLAdapter#create_view
    # for usage.
    class PostgreSQLViewDefinition
      include ActiveRecord::PostgreSQLExtensions::Utils

      attr_accessor :base, :name, :query, :options

      def initialize(base, name, query, options = {}) #:nodoc:
        @base, @name, @query, @options = base, name, query, options
      end

      def to_sql #:nodoc:
        sql = 'CREATE '
        sql << 'OR REPLACE ' if options[:replace]
        sql << 'TEMPORARY ' if options[:temporary]
        sql << 'RECURSIVE ' if options[:recursive]
        sql << "VIEW #{base.quote_view_name(name)} "

        if options[:columns]
          sql << '(' << Array.wrap(options[:columns]).collect do |c|
            base.quote_column_name(c)
          end.join(', ') << ') '
        end

        if options[:with_options]
          ActiveRecord::PostgreSQLExtensions::Features.check_feature(:view_set_options)

          sql << "WITH (#{options_from_hash_or_string(options[:with_options])}) " if options.present?
        end

        sql << "AS #{query}"
        "#{sql};"
      end
      alias :to_s :to_sql
    end

    class PostgreSQLViewAlterer
      include ActiveRecord::PostgreSQLExtensions::Utils

      attr_accessor :base, :name, :actions, :options

      VALID_OPTIONS = %w{
        set_default
        drop_default
        owner_to
        rename_to
        set_schema
        set_options
        reset_options
      }.freeze

      def initialize(base, name, actions, options = {}) #:nodoc:
        @base, @name, @actions, @options = base, name, actions, options
      end

      def to_sql #:nodoc:
        all_sql = []

        VALID_OPTIONS.each do |key|
          key = key.to_sym

          if actions.key?(key)
            sql = "ALTER VIEW "

            if options.key?(:if_exists)
              ActiveRecord::PostgreSQLExtensions::Features.check_feature(:view_if_exists)

              sql << "IF EXISTS " if options[:if_exists]
            end

            sql << "#{base.quote_view_name(name)} "

            sql << case key
              when :set_default
                column, expression = actions[:set_default].flatten
                "ALTER COLUMN #{base.quote_column_name(column)} SET DEFAULT #{expression}"

              when :drop_default
                "ALTER COLUMN #{base.quote_column_name(actions[:drop_default])} DROP DEFAULT"

              when :owner_to
                "OWNER TO #{base.quote_role(actions[:owner_to])}"

              when :rename_to
                "RENAME TO #{base.quote_generic_ignore_scoped_schema(actions[:rename_to])}"

              when :set_schema
                "SET SCHEMA #{base.quote_schema(actions[:set_schema])}"

              when :set_options
                ActiveRecord::PostgreSQLExtensions::Features.check_feature(:view_set_options)

                "SET (#{options_from_hash_or_string(actions[:set_options])})" if actions[:set_options].present?

              when :reset_options
                ActiveRecord::PostgreSQLExtensions::Features.check_feature(:view_set_options)

                'RESET (' << Array.wrap(actions[:reset_options]).collect { |value|
                  base.quote_generic(value)
                }.join(", ") << ')'
            end

            all_sql << "#{sql};"
          end
        end

        all_sql.join("\n")
      end
    end
  end
end
