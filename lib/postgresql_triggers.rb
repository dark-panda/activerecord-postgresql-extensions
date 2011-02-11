
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
	class InvalidTriggerCallType < ActiveRecordError #:nodoc:
		def initialize(called)
			super("Invalid trigger call type - #{called}")
		end
	end

	class InvalidTriggerEvents < ActiveRecordError #:nodoc:
		def initialize(events)
			super("Invalid trigger event(s) - #{events.inspect}")
		end
	end

	module ConnectionAdapters
		class PostgreSQLAdapter < AbstractAdapter
			# Creates a PostgreSQL trigger.
			#
			# The +called+ argument specifies when the trigger is called and
			# can be either <tt>:before</tt> or <tt>:after</tt>.
			#
			# +events+ can be on or more of <tt>:insert</tt>,
			# <tt>:update</tt> or <tt>:delete</tt>. There are no
			# <tt>:select</tt> triggers, as SELECT generally doesn't modify
			# the database.
			#
			# +table+ is obviously the table the trigger will be created on
			# while +function+ is the name of the procedure to call when the
			# trigger is fired.
			#
			# ==== Options
			#
			# * <tt>:for_each</tt> - defines whether the trigger will be fired
			#   on each row in a statement or on the statement itself. Possible
			#   values are <tt>:row</tt> and <tt>:statement</tt>, with
			#   <tt>:statement</tt> being the default.
			# * <tt>:args</tt> - if the trigger function requires any
			#   arguments then this is the place to let everyone know about it.
			#
			# ==== Example
			#
			#	### ruby
			#	create_trigger(
			#	  'willie_nelsons_trigger',
			#	  :before,
			#	  :update,
			#	  { :nylon => :guitar },
			#	  'strum_trigger',
			#	  :for_each => :row
			#	)
			#	# => CREATE TRIGGER "willie_nelsons_trigger" BEFORE UPDATE
			#	#    ON "nylon"."guitar" FOR EACH ROW EXECUTE PROCEDURE "test_trigger"();
			def create_trigger(name, called, events, table, function, options = {})
				execute PostgreSQLTriggerDefinition.new(self, name, called, events, table, function, options).to_s
			end

			# Drops a trigger.
			#
			# ==== Options
			#
			# * <tt>:if_exists</tt> - adds IF EXISTS.
			# * <tt>:cascade</tt> - cascades changes down to objects referring
			#   to the trigger.
			def drop_trigger(name, table, options = {})
				sql = 'DROP TRIGGER '
				sql << 'IF EXISTS ' if options[:if_exists]
				sql << "#{quote_generic(name)} ON #{quote_table_name(table)}"
				sql << ' CASCADE' if options[:cascade]
				execute sql
			end

			# Renames a trigger.
			def rename_trigger(name, table, new_name, options = {})
				execute "ALTER TRIGGER #{quote_generic(name)} ON #{quote_table_name(table)} RENAME TO #{quote_generic(new_name)}"
			end
		end

		# Creates a PostgreSQL trigger definition. This class isn't really
		# meant to be used directly. You'd be better off sticking to
		# PostgreSQLAdapter#create_trigger. Honestly.
		class PostgreSQLTriggerDefinition
			attr_accessor :base, :name, :called, :events, :table, :function, :options

			def initialize(base, name, called, events, table, function, options = {}) #:nodoc:
				assert_valid_called(called)
				assert_valid_events(events)
				assert_valid_for_each(options[:for_each])
			
				@base, @name, @events, @called, @table, @function, @options =
					base, name, events, called, table, function, options
			end

			def to_sql #:nodoc:
				sql = "CREATE TRIGGER #{base.quote_generic(name)} #{called.to_s.upcase} "
				sql << Array(events).collect { |e| e.to_s.upcase }.join(' OR ')
				sql << " OF " << Array(options[:of]).collect { |o| base.quote_generic(o) }.join(', ') if options[:of].present?
				sql << " ON #{base.quote_table_name(table)}"
				sql << " FOR EACH #{options[:for_each].to_s.upcase}" if options[:for_each]
				sql << " EXECUTE PROCEDURE #{base.quote_function(function)}(#{options[:args]})"
				sql
			end
			alias :to_s :to_sql

			private
				CALLED_TYPES = %w{ before after }.freeze
				EVENT_TYPES = %w{ insert update delete }.freeze
				FOR_EACH_TYPES = %w{ row statement }.freeze

				def assert_valid_called(c) #:nodoc:
					if !CALLED_TYPES.include?(c.to_s.downcase)
						raise ActiveRecord::InvalidTriggerCallType.new(c)
					end
				end

				def assert_valid_events(events) #:nodoc:
					check_events = Array(events).collect(&:to_s) - EVENT_TYPES
					if !check_events.empty?
						raise ActiveRecord::InvalidTriggerEvent.new(check_events)
					end
				end

				def assert_valid_for_each(f) #:nodoc:
					if !FOR_EACH_TYPES.include?(f.to_s.downcase)
						raise ActiveRecord::InvalidTriggerForEach.new(f)
					end unless f.nil?
				end
		end
	end
end
