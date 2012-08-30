
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      # VACUUMs a database, table or columns on a table. See
      # PostgreSQLVacuum for details.
      def vacuum(*args)
        vacuumer = PostgreSQLVacuum.new(self, *args)
        execute("#{vacuumer};")
      end
    end

    # Creates queries for invoking VACUUM.
    #
    # This class is meant to be used by the PostgreSQLAdapter#vacuum method.
    # VACUUMs can be performed against the database as a whole, on specific
    # tables or on specific columns.
    #
    # ==== Examples
    #
    #   ActiveRecord::Base.connection.vacuum
    #   # => VACUUM;
    #
    #   ActiveRecord::Base.connection.vacuum(:full => true, :analyze => true)
    #   # => VACUUM FULL; # PostgreSQL < 9.0
    #   # => VACUUM (FULL); # PostgreSQL >= 9.0
    #
    #   ActiveRecord::Base.connection.vacuum(:foos)
    #   # => VACUUM "foos";
    #
    #   ActiveRecord::Base.connection.vacuum(:foos, :columns => [ :bar, :baz ])
    #   # => VACUUM (ANALYZE) "foos" ("bar", "baz");
    #
    # ==== Options
    #
    # * <tt>:full</tt>, <tt>:freeze</tt>, <tt>:verbose</tt> and
    #   <tt>:analyze</tt> are all supported.
    # * <tt>:columns</tt> - specifies the columns to VACUUM. You must specify
    #   a table when using this option. This option also forces the :analyze
    #   option to true, as PostgreSQL doesn't like to try and VACUUM a column
    #   without analyzing it.
    class PostgreSQLVacuum
      VACUUM_OPTIONS = %w{
        FULL FREEZE VERBOSE ANALYZE
      }.freeze

      attr_accessor :base, :table, :options

      def initialize(base, *args)
        if !args.length.between?(0, 2)
          raise ArgumentError.new("Wrong number of arguments #{args.length} for 0-2")
        end

        options = args.extract_options!
        table = args.first

        if options[:columns]
          if !table
            raise ArgumentError.new("You must specify a table when using the :columns option.")
          end

          options[:analyze] = true
        end

        @base, @table, @options = base, table, options
      end

      def to_sql
        vacuum_options = options.collect { |(k, v)|
          k = k.to_s.upcase
          k if VACUUM_OPTIONS.include?(k)
        }.compact

        sql = 'VACUUM'

        if !vacuum_options.empty?
          sql << if ActiveRecord::PostgreSQLExtensions.SERVER_VERSION.to_f >= 9.0
            " (#{vacuum_options.join(', ')})"
          else
            ' ' << VACUUM_OPTIONS.collect { |v|
              v.upcase if vacuum_options.include?(v)
            }.compact.join(' ')
          end
        end

        sql << " #{base.quote_table_name(table)}" if self.table

        if options[:columns]
          sql << ' (' << Array(options[:columns]).collect { |column|
            base.quote_column_name(column)
          }.join(', ') << ')'
        end

        sql
      end
      alias :to_s :to_sql
    end
  end
end
