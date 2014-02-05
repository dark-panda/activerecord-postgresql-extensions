
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidEventTriggerEventType < ActiveRecordError #:nodoc:
    def initialize(events)
      super("Invalid trigger event(s) - #{events.inspect}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates a PostgreSQL event trigger. Available in PostgreSQL 9.3+.
      #
      # +event+ is one of the valid event trigger event names. See the
      # PostgreSQL documentation for details.
      #
      # ==== Options
      #
      # ==== Example
      #
      def create_event_trigger(name, event, function, options = {})
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:event_triggers)

        execute ActiveRecord::PostgreSQLExtensions::PostgreSQLEventTriggerDefinition.new(self, name, event, function, options).to_s
      end

      # Drops an event trigger.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - cascades changes down to objects referring
      #   to the trigger.
      def drop_event_trigger(name, options = {})
        sql = 'DROP EVENT TRIGGER '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << quote_generic(name)
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Renames an event trigger.
      def rename_event_trigger(name, new_name)
        execute "ALTER EVENT TRIGGER #{quote_generic(name)} RENAME TO #{quote_generic(new_name)};"
      end

      # Reassigns ownership of an event trigger.
      def alter_event_trigger_owner(name, role)
        execute "ALTER EVENT TRIGGER #{quote_generic(name)} OWNER TO #{quote_generic(role)};"
      end

      # Enables an event trigger.
      #
      # ==== Options
      #
      # * <tt>:replica
      def enable_event_trigger(name, options = {})
        if options[:always] && options[:replica]
          raise ArgumentError.new("Cannot use :replica and :always together when enabling an event trigger.")
        end

        sql = "ALTER EVENT TRIGGER #{quote_generic(name)} ENABLE"

        if options[:always]
          sql << ' ALWAYS'
        elsif options[:replica]
          sql << ' REPLICA'
        end

        execute "#{sql};"
      end

      # Disables an event trigger.
      def disable_event_trigger(name)
        execute "ALTER EVENT TRIGGER #{quote_generic(name)} DISABLE;"
      end
    end
  end

  module PostgreSQLExtensions
    # Creates a PostgreSQL event trigger definition. This class isn't really
    # meant to be used directly. You'd be better off sticking to
    # PostgreSQLAdapter#create_event_trigger. Honestly.
    class PostgreSQLEventTriggerDefinition
      attr_accessor :base, :name, :event, :function, :options

      def initialize(base, name, event, function, options = {}) #:nodoc:
        assert_valid_event_name(event)

        @base, @name, @event, @function, @options =
          base, name, event, function, options
      end

      def to_sql #:nodoc:
        sql = "CREATE EVENT TRIGGER #{base.quote_generic(name)} ON #{base.quote_generic(event)}"

        if options[:when].present?
          sql << "\n  WHEN "

          sql << options[:when].inject([]) { |memo, (k, v)|
            memo.tap {
              values = Array.wrap(v).collect { |value|
                base.quote(value)
              }.join(', ')

              memo << "#{base.quote_generic(k)} IN (#{values})"
            }
          }.join("\n  AND ")

          sql << "\n "
        end

        sql << " EXECUTE PROCEDURE #{base.quote_function(function)}()"

        "#{sql};"
      end
      alias :to_s :to_sql


      private
        EVENT_NAMES = %w{ ddl_command_start ddl_command_end sql_drop }.freeze

        def assert_valid_event_name(event) #:nodoc:
          if !EVENT_NAMES.include?(event.to_s.downcase)
            raise ActiveRecord::InvalidEventTriggerEventType.new(event)
          end
        end
    end
  end
end
