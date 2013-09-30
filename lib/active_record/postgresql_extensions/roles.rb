
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidRoleAction < ActiveRecordError #:nodoc:
    def initialize(action)
      super("Invalid role action - #{action}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates a PostgreSQL ROLE. See PostgreSQLRole for details on options.
      def create_role(name, options = {})
        execute PostgreSQLRole.new(self, :create, name, options).to_sql
      end
      alias :create_user :create_role

      # Alters a PostgreSQL ROLE. See PostgreSQLRole for details on options.
      def alter_role(name, options = {})
        execute PostgreSQLRole.new(self, :alter, name, options).to_sql
      end
      alias :alter_user :alter_role

      # Drop PostgreSQL ROLEs.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - don't raise an error if the ROLE doesn't
      #   exist. The default is false.
      def drop_role(*args)
        options = args.extract_options!
        args.flatten!

        sql = 'DROP ROLE '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array(args).collect { |r| quote_role(r) }.join(', ')
        execute("#{sql};")
      end
      alias :drop_user :drop_role
    end

    # This is a base class for creating and altering ROLEs and is not meant to
    # be used directly.
    class PostgreSQLRole
      attr_accessor :base, :action, :name, :options

      def initialize(base, action, name, options = {}) #:nodoc:
        assert_valid_action(action)

        @base, @action, @name, @options = base, action, name, options
      end

      def to_sql #:nodoc:
        sql = Array.new
        if action == :create
          sql << 'CREATE'
        else
          sql << 'ALTER'
        end
        sql << "ROLE #{base.quote_role(name)}"

        if options[:superuser]
          sql << 'SUPERUSER'
        end

        if options[:create_db]
          sql << 'CREATEDB'
        end

        if options[:create_role]
          sql << 'CREATEROLE'
        end

        if options.has_key?(:inherit) && !options[:inherit]
          sql << 'NOINHERIT'
        end

        if options[:login]
          sql << 'LOGIN'
        end

        if options[:connection_limit]
          sql << "CONNECTION LIMIT #{options[:connection_limit].to_i}"
        end

        if options[:password]
          if options.has_key?(:encrypted_password)
            if options[:encrypted_password]
              sql << 'ENCRYPTED'
            else
              sql << 'UNENCRYPTED'
            end
          end

          sql << 'PASSWORD'
          sql << base.quote(options[:password])
        end

        if options[:valid_until]
          sql << 'VALID UNTIL'
          timestamp = case options[:valid_until]
            when Date, Time, DateTime
              options[:valid_until].to_s(:sql)
            else
              options[:valid_until].to_s
          end
          sql << base.quote(timestamp)
        end

        if options[:in_role].present?
          sql << 'IN ROLE'
          sql << Array(options[:in_role]).collect { |r| base.quote_role(r) }.join(', ')
        end

        if options[:role].present?
          sql << 'ROLE'
          sql << Array(options[:role]).collect { |r| base.quote_role(r) }.join(', ')
        end

        if options[:admin].present?
          sql << 'ADMIN'
          sql << Array(options[:admin]).collect { |r| base.quote_role(r) }.join(', ')
        end

        "#{sql.join(' ')};"
      end
      alias :to_s :to_sql

      private
        def assert_valid_action(action) #:nodoc:
          if ![ :create, :alter ].include?(action)
            raise ActiveRecord::InvalidRoleAction.new(action)
          end
        end
    end
  end
end
