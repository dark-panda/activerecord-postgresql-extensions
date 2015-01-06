
module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      def create_table_with_postgresql_extensions(table_name, options = {})
        if options[:force]
          drop_table(table_name, { :if_exists => true, :cascade => options[:cascade_drop] })
        end

        table_definition = ActiveRecord::PostgreSQLExtensions::PostgreSQLTableDefinition.new(self, native_database_types, table_name, options)
        yield table_definition if block_given?

        execute ActiveRecord::PostgreSQLExtensions::PostgreSQLSchemaCreation.new(self).accept table_definition

        unless table_definition.post_processing.blank?
          table_definition.post_processing.each do |pp|
            execute pp.to_s
          end
        end
      end
      alias_method_chain :create_table, :postgresql_extensions
    end
  end

  module PostgreSQLExtensions
    # Creates a PostgreSQL table definition. This class isn't really meant
    # to be used directly. Instead, see PostgreSQLAdapter#create_table
    # for usage.
    #
    # Beyond our various PostgreSQL-specific extensions, we've also added
    # the <tt>post_processing</tt> member, which allows you to tack on
    # some SQL statements to run after creating the table. This member
    # should be an Array of SQL statements to run once the table has
    # been created. See the source code for PostgreSQLAdapter#create_table
    # and PostgreSQLTableDefinition#geometry for an example of its use.
    class PostgreSQLTableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
      include ActiveRecord::PostgreSQLExtensions::SharedTableDefinition

      attr_accessor :base, :table_name, :options

      def initialize(base, types, name, options = {}) #:nodoc:
        @base = base
        @table_constraints = Array.new
        @table_name = name
        super(types, name, options[:temporary], options)
      end
    end

    class PostgreSQLSchemaCreation < ActiveRecord::ConnectionAdapters::AbstractAdapter::SchemaCreation
      def visit_PostgreSQLTableDefinition(o)
        columns = o.columns

        if o.options[:of_type]
          if !columns.empty?
            raise ArgumentError.new("Cannot specify columns while using the :of_type option")
          elsif o.options[:like]
            raise ArgumentError.new("Cannot specify both the :like and :of_type options")
          elsif o.options[:inherits]
            raise ArgumentError.new("Cannot specify both the :inherits and :of_type options")
          else
            o.options[:id] = false
          end
        end

        if o.options.key?(:if_not_exists)
          ActiveRecord::PostgreSQLExtensions::Features.check_feature(:create_table_if_not_exists)
        elsif o.options.key?(:unlogged)
          ActiveRecord::PostgreSQLExtensions::Features.check_feature(:create_table_unlogged)
        end

        unless o.options[:id] == false
          o.primary_key(o.options[:primary_key] || Base.get_primary_key(o.table_name))

          # ensures that the primary key column is first.
          columns.unshift(o.columns.last)
        end

        sql = 'CREATE '
        sql << 'TEMPORARY ' if o.options[:temporary]
        sql << 'UNLOGGED ' if o.options[:unlogged]
        sql << 'TABLE '
        sql << 'IF NOT EXISTS ' if o.options[:if_not_exists]
        sql << "#{quote_table_name(o.name)}"
        sql << " OF #{quote_table_name(o.options[:of_type])}" if o.options[:of_type]

        ary = []

        if !o.options[:of_type]
          ary << columns.map { |c| accept c }
          ary << accept(o.like_options) if o.like_options.present?
        end

        unless o.table_constraints.empty?
          ary << o.table_constraints.map { |c| accept c }
        end

        unless ary.empty?
          sql << " (\n  "
          sql << ary * ",\n  "
          sql << "\n)"
        end

        sql << "\nINHERITS (" << Array.wrap(o.options[:inherits]).collect { |i| quote_table_name(i) }.join(', ') << ')' if o.options[:inherits]
        sql << "\nWITH (#{ActiveRecord::PostgreSQLExtensions::Utils.options_from_hash_or_string(o.options[:storage_parameters], o.base)})" if o.options[:storage_parameters].present?
        sql << "\nON COMMIT #{o.options[:on_commit].to_s.upcase.gsub(/_/, ' ')}" if o.options[:on_commit]
        sql << "\n#{o.options[:options]}" if o.options[:options]
        sql << "\nTABLESPACE #{o.base.quote_tablespace(o.options[:tablespace])}" if o.options[:tablespace]
        "#{sql};"
      end

      def add_column_options_with_expression!(sql, options) #:nodoc:
        if options_include_default?(options) &&
          options[:default].is_a?(Hash) &&
          options[:default].has_key?(:expression)

          expression = options.delete(:default)
          sql << " DEFAULT #{expression[:expression]}"
        end
        add_column_options_without_expression!(sql, options)
      end
      alias_method_chain :add_column_options!, :expression

      def visit_PostgreSQLUniqueConstraint(o)
        o.to_sql
      end

      def visit_PostgreSQLPrimaryKeyConstraint(o)
        o.to_sql
      end

      def visit_PostgreSQLExcludeConstraint(o)
        o.to_sql
      end

      def visit_PostgreSQLLikeOptions(o)
        o.to_sql
      end

      def visit_PostgreSQLForeignKeyConstraint(o)
        o.to_sql
      end

      def visit_PostgreSQLCheckConstraint(o)
        o.to_sql
      end

      def visit_PostgreSQLCheckConstraintCollection(o)
        o.to_sql
      end
    end
  end
end
