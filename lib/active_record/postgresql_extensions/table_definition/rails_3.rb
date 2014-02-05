
module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      def create_table_with_postgresql_extensions(table_name, options = {})
        if options[:force]
          drop_table(table_name, { :if_exists => true, :cascade => options[:cascade_drop] })
        end

        table_definition = if ActiveRecord::VERSION::STRING >= "4.0"
          ActiveRecord::PostgreSQLExtensions::PostgreSQLTableDefinition.new(self, native_database_types, table_name, options)
        else
          ActiveRecord::PostgreSQLExtensions::PostgreSQLTableDefinition.new(self, table_name, options)
        end

        yield table_definition if block_given?

        execute table_definition.to_s
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

      def initialize(base, table_name, options = {}) #:nodoc:
        @table_name, @options = table_name, options
        super(base)
      end

      def to_sql #:nodoc:
        if self.options[:of_type]
          if !@columns.empty?
            raise ArgumentError.new("Cannot specify columns while using the :of_type option")
          elsif options[:like]
            raise ArgumentError.new("Cannot specify both the :like and :of_type options")
          elsif options[:inherits]
            raise ArgumentError.new("Cannot specify both the :inherits and :of_type options")
          else
            options[:id] = false
          end
        end

        if options.key?(:if_not_exists)
          ActiveRecord::PostgreSQLExtensions::Features.check_feature(:create_table_if_not_exists)
        elsif options.key?(:unlogged)
          ActiveRecord::PostgreSQLExtensions::Features.check_feature(:create_table_unlogged)
        end

        unless options[:id] == false
          self.primary_key(options[:primary_key] || Base.get_primary_key(table_name))

          # ensures that the primary key column is first.
          @columns.unshift(@columns.pop)
        end

        sql = 'CREATE '
        sql << 'TEMPORARY ' if options[:temporary]
        sql << 'UNLOGGED ' if options[:unlogged]
        sql << 'TABLE '
        sql << 'IF NOT EXISTS ' if options[:if_not_exists]
        sql << "#{base.quote_table_name(table_name)}"
        sql << " OF #{base.quote_table_name(options[:of_type])}" if options[:of_type]

        ary = []
        if !options[:of_type]
          ary << @columns.collect(&:to_sql)
          ary << like_options if like_options
        end
        ary << table_constraints unless table_constraints.empty?

        unless ary.empty?
          sql << " (\n  "
          sql << ary * ",\n  "
          sql << "\n)"
        end

        sql << "\nINHERITS (" << Array.wrap(options[:inherits]).collect { |i| base.quote_table_name(i) }.join(', ') << ')' if options[:inherits]
        sql << "\nWITH (#{ActiveRecord::PostgreSQLExtensions::Utils.options_from_hash_or_string(options[:storage_parameters], base)})" if options[:storage_parameters].present?
        sql << "\nON COMMIT #{options[:on_commit].to_s.upcase.gsub(/_/, ' ')}" if options[:on_commit]
        sql << "\n#{options[:options]}" if options[:options]
        sql << "\nTABLESPACE #{base.quote_tablespace(options[:tablespace])}" if options[:tablespace]
        "#{sql};"
      end
      alias :to_s :to_sql
    end
  end
end
