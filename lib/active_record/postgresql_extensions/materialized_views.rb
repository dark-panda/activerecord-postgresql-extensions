
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates a new PostgreSQL materialized view.
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
      # * <tt>:columns</tt> - you can rename the output columns as
      #   necessary. Note that this can be an Array and that it must be
      #   the same length as the number of output columns created by
      #   +query+.
      # * <tt>:tablespace</tt> - allows you to set the tablespace of a
      #   materialized view.
      # * <tt>:with_data</tt> - whether to populate the materialized view
      #   upon creation. The default is true.
      #
      # ==== Examples
      #
      #   create_materialized_view(:foo_view, 'SELECT * FROM bar')
      #   # => CREATE MATERIALIZED VIEW "foo_view" AS SELECT * FROM bar;
      #
      #   create_view(
      #     { :geospatial => :foo_view },
      #     'SELECT * FROM bar',
      #     :columns => [ :id, :name, :the_geom ],
      #     :with_data => false
      #   )
      #   # => CREATE MATERIALIZED VIEW "geospatial"."foo_view" ("id", "name", "the_geom") AS SELECT * FROM bar WITH NO DATA;
      def create_materialized_view(name, query, options = {})
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:materialized_views)

        execute PostgreSQLMaterializedViewDefinition.new(self, name, query, options).to_s
      end

      # Drops a materialized view.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_materialized_view(*args)
        options = args.extract_options!
        args.flatten!

        sql = 'DROP MATERIALIZED VIEW '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array.wrap(args).collect { |v| quote_view_name(v) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Renames a materialized view.
      def rename_materialized_view(name, new_name, options = {})
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :rename_to => new_name
        }, options).to_sql
      end

      # Change the default of a materialized view column. The default value can
      # be either a straight-up value or a Hash containing an expression
      # in the form <tt>:expression => value</tt> which will be passed
      # through unescaped. This allows you to set expressions and use
      # functions and the like.
      def alter_materialized_view_set_column_default(name, column, default, options = {})
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :column => column,
          :set_default => default
        }, options).to_sql
      end

      # Drop the default value on a materialized view column
      def alter_materialized_view_drop_column_default(name, column, options = {})
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :drop_default => column
        }, options).to_sql
      end

      # Change the ownership of a materialized view.
      def alter_materialized_view_owner(name, role, options = {})
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :owner_to => role
        }, options).to_sql
      end

      # Alter a materialized view's schema.
      def alter_materialized_view_schema(name, schema, options = {})
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :set_schema => schema
        }, options).to_sql
      end

      # Sets a materialized view's options using a Hash.
      def alter_materialized_view_set_options(name, set_options, options = {})
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :set_options => set_options
        }, options).to_sql
      end

      # Resets a materialized view's options.
      def alter_materialized_view_reset_options(name, *args)
        options = args.extract_options!

        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :reset_options => args
        }, options).to_sql
      end

      # Cluster a materialized view on an index.
      def cluster_materialized_view(name, index_name)
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :cluster_on => index_name
        }).to_sql
      end

      # Remove a cluster from materialized view.
      def remove_cluster_from_materialized_view(name)
        execute PostgreSQLMaterializedViewAlterer.new(self, name, {
          :remove_cluster => true
        }).to_sql
      end

      # Refreshes the data in a materialized view.
      #
      # ==== Options
      #
      # * <tt>:with_data</tt> - whether to populate the materialized view with
      #   data. The default is true.
      def refresh_materialized_view(name, options = {})
        options = {
          :with_data => true
        }.merge(options)

        sql = "REFRESH MATERIALIZED VIEW #{quote_view_name(name)}"
        sql << " WITH NO DATA" unless options[:with_data]

        execute "#{sql};"
      end
    end

    # Creates a PostgreSQL materialized view definition. This class isn't
    # really meant to be used directly. Instead, see
    # PostgreSQLAdapter#create_materialized_view for usage.
    class PostgreSQLMaterializedViewDefinition
      include ActiveRecord::PostgreSQLExtensions::Utils

      attr_accessor :base, :name, :query, :options

      def initialize(base, name, query, options = {}) #:nodoc:
        @base, @name, @query, @options = base, name, query, options
      end

      def to_sql #:nodoc:
        sql = "CREATE MATERIALIZED VIEW #{base.quote_view_name(name)} "

        if options[:columns]
          sql << '(' << Array.wrap(options[:columns]).collect do |c|
            base.quote_column_name(c)
          end.join(', ') << ') '
        end

        sql << "WITH (#{options_from_hash_or_string(options[:with_options])}) " if options[:with_options].present?

        sql << "TABLESPACE #{base.quote_tablespace(options[:tablespace])} " if options[:tablespace]
        sql << "AS #{query}"
        sql << " WITH NO DATA" if options.key?(:with_data) && !options[:with_data]
        "#{sql};"
      end
      alias :to_s :to_sql
    end

    # Alters a PostgreSQL materialized view definition. This class isn't
    # really meant to be used directly. Instead, see the various
    # PostgreSQLAdapter materialied views methods for usage.
    class PostgreSQLMaterializedViewAlterer
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
        cluster_on
        remove_cluster
      }.freeze

      def initialize(base, name, actions, options = {}) #:nodoc:
        @base, @name, @actions, @options = base, name, actions, options
      end

      def to_sql #:nodoc:
        all_sql = []

        VALID_OPTIONS.each do |key|
          key = key.to_sym

          if actions.key?(key)
            sql = "ALTER MATERIALIZED VIEW "
            sql << "IF EXISTS " if options[:if_exists]
            sql << "#{base.quote_view_name(name)} "

            sql << case key
              when :set_default
                expression = if actions[:set_default].is_a?(Hash) && actions[:set_default].key?(:expression)
                   actions[:set_default][:expression]
                else
                  base.quote(actions[:set_default])
                end

                "ALTER COLUMN #{base.quote_column_name(actions[:column])} SET DEFAULT #{expression}"

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

              when :cluster_on
                "CLUSTER ON #{base.quote_generic(actions[:cluster_on])}"

              when :remove_cluster
                next unless actions[:remove_cluster]

                "SET WITHOUT CLUSTER"
            end

            all_sql << "#{sql};"
          end
        end

        all_sql.join("\n")
      end
    end
  end
end
