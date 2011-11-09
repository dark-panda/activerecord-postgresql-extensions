
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidRuleEvent < ActiveRecordError #:nodoc:
    def initialize(event)
      super("Invalid rule event - #{event}")
    end
  end

  class InvalidRuleAction < ActiveRecordError #:nodoc:
    def initialize(action)
      super("Invalid rule action - #{action}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      # Creates a PostgreSQL rule.
      #
      # +event+ can be one of <tt>:select</tt>, <tt>:insert</tt>,
      # <tt>:update</tt> or <tt>:delete</tt>.
      #
      # +action+ can be one of <tt>:instead</tt> or <tt>:also</tt>.
      #
      # +commands+ is the actual query to rewrite to. commands can
      # actually be "+NOTHING+", a String representing the commands
      # or an Array of Strings if you have multiple commands you want to
      # fire.
      #
      # ==== Options
      #
      # * <tt>:force</tt> - add an <tt>OR REPLACE</tt> clause to the
      #   command.
      # * <tt>:conditions</tt> - a <tt>WHERE</tt> clause to limit the
      #   rule.
      #
      # ==== Examples
      #
      #  ### ruby
      #  create_rule(
      #    'check_it_out_rule',
      #    :select,
      #    :child,
      #    :instead,
      #    'select * from public.another', :conditions => 'id = 1'
      #  )
      #  # => CREATE RULE "check_it_out_rule" AS ON SELECT TO "child" WHERE id = 1 DO INSTEAD select * from public.another;
      def create_rule(name, event, table, action, commands, options = {})
        execute PostgreSQLRuleDefinition.new(self, name, event, table, action, commands, options).to_s
      end

      # Drops a PostgreSQL rule.
      def drop_rule(name, table)
        execute "DROP RULE #{quote_rule(name)} ON #{quote_table_name(table)};"
      end
    end

    # Creates a PostgreSQL rule.
    #
    # The PostgreSQL rule system is basically a query-rewriter. You should
    # take a look at the PostgreSQL documentation for more details, but the
    # basic idea is that a rule can be set to fire on certain query events
    # and will force the query to be rewritten before it is even sent to
    # the query planner and executor.
    #
    # Generally speaking, you're probably going to want to stick to
    # create_rule and drop_rule when working with rules.
    class PostgreSQLRuleDefinition
      attr_accessor :base, :name, :event, :table, :action, :commands, :options

      def initialize(base, name, event, table, action, commands, options = {}) #:nodoc:
        assert_valid_event(event)
        assert_valid_action(action)
        @base, @name, @event, @table, @action, @commands, @options =
          base, name, event, table, action, commands, options
      end

      def to_sql #:nodoc:
        sql = 'CREATE '
        sql << ' OR REPLACE ' if options[:force]
        sql << "RULE #{base.quote_rule(name)} AS ON #{event.to_s.upcase} TO #{base.quote_table_name(table)} "
        sql << "WHERE #{options[:conditions]} " if options[:conditions]
        sql << "DO #{action.to_s.upcase} "
        sql << if commands.to_s.upcase == 'NOTHING'
          'NOTHING'
        elsif commands.is_a?(Array)
          '(' << commands.collect(&:to_s).join(';') << ')'
        else
          commands.to_s
        end

        "#{sql};"
      end
      alias :to_s :to_sql

      private
        EVENTS = [ 'select', 'insert', 'update', 'delete' ].freeze
        ACTIONS = [ 'instead', 'also' ].freeze

        def assert_valid_event(event) #:nodoc:
          if !EVENTS.include? event.to_s
            raise ActiveRecord::InvalidRuleEvent.new(event)
          end
        end

        def assert_valid_action(action) #:nodoc:
          if !ACTIONS.include? action.to_s
            raise ActiveRecord::InvalidRuleAction.new(action)
          end
        end
    end
  end
end
