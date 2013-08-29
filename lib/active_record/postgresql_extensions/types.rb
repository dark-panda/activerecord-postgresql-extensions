
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidAddEnumValueOptions < ActiveRecordError #:nodoc:
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Returns an Array of available languages.
      def types(name = nil)
        query(PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL), name).map(&:first)
          SELECT t.typname as type
            FROM pg_type t
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
            WHERE (t.typrelid = 0 OR (
              SELECT c.relkind = 'c'
                FROM pg_catalog.pg_class c
                WHERE c.oid = t.typrelid
            )) AND
              NOT EXISTS(
                SELECT 1
                  FROM pg_catalog.pg_type el
                  WHERE el.oid = t.typelem
                    AND el.typarray = t.oid
              ) AND
              n.nspname NOT IN ('information_schema');
        SQL
      end

      def type_exists?(name)
        types.include?(name.to_s)
      end

      # Creates an ENUM TYPE. An ENUM can contain zero or more values. ENUMs
      # can be dropped with #drop_type.
      def create_enum(name, *values)
        execute PostgreSQLEnumDefinition.new(self, name, *values).to_s
      end

      # Adds a new value to an ENUM.
      #
      # ==== Options
      #
      # * <tt>:before</tt> - add the new value before this value.
      # * <tt>:after</tt> - add the new value after this value.
      # * <tt>:if_not_exists</tt> - adds the value if it doesn't already
      #   exist. Available in PostgreSQL 9.3+.
      def add_enum_value(enum, value, options = {})
        assert_valid_add_enum_value_options(options)

        sql = "ALTER TYPE #{quote_generic(enum)} ADD VALUE"

        if options[:if_not_exists]
          sql << " IF NOT EXISTS"
        end

        sql << " #{quote(value)}"

        if options[:before]
          sql << " BEFORE #{quote(options[:before])}"
        elsif options[:after]
          sql << " AFTER #{quote(options[:after])}"
        end

        execute("#{sql};")
      end

      # Drop TYPEs.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_type(*args)
        options = args.extract_options!
        args.flatten!

        sql = 'DROP TYPE '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array(args).collect { |i| quote_generic(i) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Returns an Array of possible
      def enum_values(name)
        query(%{SELECT unnest(enum_range(NULL::#{quote_generic(name)}))}, 'Enum values').map(&:first)
      end

      private
        def assert_valid_add_enum_value_options(options)
          if options[:before] && options[:after]
            raise InvalidAddEnumValueOptions.new("Can't use both :before and :after options together")
          end

          if options[:if_not_exists] && ActiveRecord::PostgreSQLExtensions.SERVER_VERSION < '9.3'
            raise InvalidAddEnumValueOptions.new("The :if_not_exists option is only available in PostgreSQL 9.3+.")
          end
        end
    end
  end

  # Creates a PostgreSQL enum type definition. This class isn't really meant
  # to be used directly. Instead, see PostgreSQLAdapter#create_enum for
  # usage.
  class PostgreSQLEnumDefinition
    attr_accessor :base, :name, :values

    def initialize(base, name, *values)
      @base, @name, @values = base, name, values.flatten
    end

    def to_sql #:nodoc:
      sql = "CREATE TYPE #{base.quote_generic(name)} AS ENUM ("
      sql << values.collect { |t| base.quote(t.to_s) }.join(', ')
      sql << ")"
      "#{sql};"
    end
    alias :to_s :to_sql
  end
end
