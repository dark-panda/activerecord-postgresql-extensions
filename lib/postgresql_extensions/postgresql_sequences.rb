
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidSequenceAction < ActiveRecordError #:nodoc:
    def initialize(action)
      super("Invalid sequence action - #{action}")
    end
  end

  class InvalidSequenceOptions < ActiveRecordError #:nodoc:
  end

  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      # Creates a sequence.
      #
      # Note that you can grant privileges on sequences using the
      # grant_sequence_privileges method and revoke them using
      # revoke_sequence_privileges.
      #
      # ==== Options
      #
      # * <tt>:temporary</tt> - creates a temporary sequence.
      # * <tt>:incement</tt> - sets the sequence increment value.
      # * <tt>:min_value</tt> - sets a minimum value for the sequence.
      #   If this value is <tt>nil</tt> or <tt>false</tt>, we'll go with
      #   "NO MINVALUE".
      # * <tt>:max_value</tt> - same as <tt>:min_value</tt> but for
      #   maximum values. Mindblowing.
      # * <tt>:start</tt> - the initial value of the sequence.
      # * <tt>:cache</tt> - the number of future values to cache in
      #   the sequence. This is generally dangerous to mess with, so be
      #   sure to refer to the PostgreSQL documentation for reasons why.
      # * <tt>:cycle</tt> - whether or not the sequence should cycle.
      # * <tt>:owned_by</tt> - this refers to the table and column that
      #   a sequence is owned by. If that column/table were to be
      #   dropped in the future, for instance, the sequence would be
      #   automatically dropped with it. This option can be set using
      #   an Array (as in <tt>[ table, column ]</tt>) or a Hash
      #   (as in <tt>{ :table => 'foo', :column => 'bar' }</tt>).
      #
      # ==== Example
      #
      #  ### ruby
      #  create_sequence(
      #    'what_a_sequence_of_events',
      #    :increment => 2,
      #    :cache => 2,
      #    :min_value => nil,
      #    :max_value => 10,
      #    :owned_by => [ :foo, :id ]
      #  )
      #  # => CREATE SEQUENCE "what_a_sequence_of_events" INCREMENT BY 2
      #  #    NO MINVALUE MAXVALUE 10 CACHE 2 OWNED BY "foo"."id";
      def create_sequence(name, options = {})
        execute PostgreSQLSequenceDefinition.new(self, :create, name, options).to_s
      end

      # Drops a sequence.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - cascades the operation down to objects
      #   referring to the sequence.
      def drop_sequence(name, options = {})
        sql = 'DROP SEQUENCE '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array(name).collect { |s| quote_sequence(s) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Renames the sequence.
      def rename_sequence(name, rename, options = {})
        execute "ALTER SEQUENCE #{quote_sequence(name)} RENAME TO #{quote_generic_ignore_schema(rename)};"
      end

      # Alters the sequence's schema.
      def alter_sequence_schema(name, schema, options = {})
        execute "ALTER SEQUENCE #{quote_sequence(name)} SET SCHEMA #{quote_schema(schema)};"
      end

      # Alters any of the various options for a sequence. See
      # create_sequence for details on the available options. In addition
      # to the options provided by create_sequence, there is also the
      # <tt>:restart_with</tt> option, which resets the sequence to
      # a new starting value and sets the <tt>is_called</tt> flag to
      # false, which would be the equivalent of calling the PostgreSQL
      # function <tt>setval</tt> with a false value in the third
      # parameter.
      def alter_sequence(name, options = {})
        execute PostgreSQLSequenceDefinition.new(self, :alter, name, options).to_s
      end

      # Calls the <tt>setval</tt> function on the sequence.
      #
      # ==== Options
      #
      # * <tt>:is_called</tt> - the value to set in the third argument
      #   to the function call, which is, appropriately enough, the
      #   <tt>is_called</tt> argument. The default value is true.
      def set_sequence_value(name, value, options = {})
        options = {
          :is_called => true
        }.merge(options)

        execute "SELECT setval(#{quote(name)}, #{value.to_i}, " <<
          if options[:is_called]
            'true'
          else
            'false'
          end <<
          ');'
      end

      # Returns an Array of available sequences.
      def sequences(name = nil)
        query(<<-SQL, name).map { |row| row[0] }
          SELECT c.relname AS sequencename
          FROM pg_class c
          WHERE c.relkind = 'S'::"char";
        SQL
      end

      def sequence_exists?(name)
        sequences.include?(name.to_s)
      end
    end

    # Class used to create or alter sequences. Generally you should be
    # using PostgreSQLAdapter#create_sequence and its various sequence
    # manipulation functions rather than using this class directly.
    class PostgreSQLSequenceDefinition
      attr_accessor :base, :action, :name, :options

      def initialize(base, action, name, options = {}) #:nodoc:
        assert_valid_owned_by(options)
        assert_valid_action(action)

        @base, @action, @name, @options = base, action, name, options
      end

      def to_sql #:nodoc:
        sql = Array.new
        if action == :create
          sql << 'CREATE'
          sql << 'TEMPORARY' if options[:temporary]
        else
          sql << 'ALTER'
        end
        sql << "SEQUENCE #{base.quote_sequence(name)}"
        sql << "INCREMENT BY #{options[:increment].to_i}" if options[:increment]
        if options.has_key?(:min_value)
          sql << case options[:min_value]
            when NilClass, FalseClass
              'NO MINVALUE'
            else
              "MINVALUE #{options[:min_value].to_i}"
          end
        end

        if options.has_key?(:max_value)
          sql << case options[:max_value]
            when NilClass, FalseClass
              'NO MAXVALUE'
            else
              "MAXVALUE #{options[:max_value].to_i}"
          end
        end
        sql << "START WITH #{options[:start].to_i}" if options[:start]
        sql << "CACHE #{options[:cache].to_i}" if options[:cache]

        if options.has_key?(:cycle)
          sql << (options[:cycle] ? 'CYCLE' : 'NO CYCLE')
        end

        if options.has_key?(:owned_by)
          table_column = if options[:owned_by].is_a?(Hash)
            [ options[:owned_by][:table], options[:owned_by][:column] ]
          elsif options[:owned_by].is_a?(Array)
            options[:owned_by]
          end

          sql << 'OWNED BY ' + if options[:owned_by] == :none
            'NONE'
          else
            "#{base.quote_table_name(table_column.first)}.#{base.quote_column_name(table_column.last)}"
          end
        end

        if action != :create && options.has_key?(:restart_with)
          sql << "RESTART WITH #{options[:restart_with].to_i}"
        end
        "#{sql.join(' ')};"
      end
      alias :to_s :to_sql

      private
        def assert_valid_owned_by(options) #:nodoc:
          if options.has_key?(:owned_by)
            begin
              if options[:owned_by].is_a?(Hash)
                raise if !(options[:owned_by].keys.sort == [ :column, :table ])
              elsif options[:owned_by].is_a?(Array)
                raise if options[:owned_by].length != 2
              end
            rescue
              raise ActiveRecord::InvalidSequenceOptions.new("Invalid :owned_by options")
            end
          end
        end

        def assert_valid_action(action) #:nodoc:
          if ![ :create, :alter ].include?(action)
            raise ActiveRecord::InvalidSequenceAction.new(action)
          end
        end
    end
  end
end
