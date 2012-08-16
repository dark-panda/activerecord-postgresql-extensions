
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidPrivilegeTypes < ActiveRecordError #:nodoc:
    def initialize(type, privileges)
      super("Invalid privileges for #{type} - #{privileges.inspect}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Grants privileges on tables. You can specify multiple tables,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLGrantPrivilege for
      # usage.
      def grant_table_privileges(tables, privileges, roles, options = {})
        execute PostgreSQLGrantPrivilege.new(self, :table, tables, privileges, roles, options).to_sql
      end

      # Grants privileges on sequences. You can specify multiple
      # sequences, roles and privileges all at once using Arrays for each
      # of the desired parameters. See PostgreSQLGrantPrivilege for
      # usage.
      def grant_sequence_privileges(sequences, privileges, roles, options = {})
        execute PostgreSQLGrantPrivilege.new(self, :sequence, sequences, privileges, roles, options).to_sql
      end

      # Grants privileges on databases. You can specify multiple
      # databases, roles and privileges all at once using Arrays for
      # each of the desired parameters. See PostgreSQLGrantPrivilege for
      # usage.
      def grant_database_privileges(databases, privileges, roles, options = {})
        execute PostgreSQLGrantPrivilege.new(self, :database, databases, privileges, roles, options).to_sql
      end

      # Grants privileges on functions. You can specify multiple
      # functions, roles and privileges all at once using Arrays for
      # each of the desired parameters. See PostgreSQLGrantPrivilege for
      # usage.
      def grant_function_privileges(function_prototypes, privileges, roles, options = {})
        execute PostgreSQLGrantPrivilege.new(self, :function, function_prototypes, privileges, roles, options, :quote_objects => false).to_sql
      end

      # Grants privileges on procedural languages. You can specify
      # multiple languages, roles and privileges all at once using
      # Arrays for each of the desired parameters. See
      # PostgreSQLGrantPrivilege for usage.
      def grant_language_privileges(languages, privileges, roles, options = {})
        execute PostgreSQLGrantPrivilege.new(self, :language, languages, privileges, roles, options).to_sql
      end

      # Grants privileges on schemas. You can specify multiple schemas,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLGrantPrivilege for
      # usage.
      def grant_schema_privileges(schemas, privileges, roles, options = {})
        execute PostgreSQLGrantPrivilege.new(self, :schema, schemas, privileges, roles, options, :ignore_schema => true).to_sql
      end

      # Grants privileges on tablespaces. You can specify multiple
      # tablespaces, roles and privileges all at once using Arrays for
      # each of the desired parameters. See PostgreSQLGrantPrivilege for
      # usage.
      def grant_tablespace_privileges(tablespaces, privileges, roles, options = {})
        execute PostgreSQLGrantPrivilege.new(self, :tablespace, tablespaces, privileges, roles, options).to_sql
      end

      # Grants role membership to another role. You can specify multiple
      # roles for both the roles and the role_names parameters using
      # Arrays.
      #
      # ==== Options
      #
      # * <tt>:with_admin_option</tt> - adds the WITH ADMIN OPTION
      #   clause to the command.
      def grant_role_membership(roles, role_names, options = {})
        sql = "GRANT "
        sql << Array(roles).collect { |r| quote_role(r) }.join(', ')
        sql << ' TO '
        sql << Array(role_names).collect { |r| quote_role(r) }.join(', ')
        sql << ' WITH ADMIN OPTION' if options[:with_admin_option]
        execute("#{sql};")
      end

      # Revokes table privileges. You can specify multiple tables,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLRevokePrivilege for
      # usage.
      def revoke_table_privileges(tables, privileges, roles, options = {})
        execute PostgreSQLRevokePrivilege.new(self, :table, tables, privileges, roles, options).to_sql
      end

      # Revokes sequence privileges. You can specify multiple sequences,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLRevokePrivilege for
      # usage.
      def revoke_sequence_privileges(sequences, privileges, roles, options = {})
        execute PostgreSQLRevokePrivilege.new(self, :sequence, sequences, privileges, roles, options).to_sql
      end

      # Revokes database privileges. You can specify multiple databases,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLRevokePrivilege for
      # usage.
      def revoke_database_privileges(databases, privileges, roles, options = {})
        execute PostgreSQLRevokePrivilege.new(self, :database, databases, privileges, roles, options).to_sql
      end

      # Revokes function privileges. You can specify multiple functions,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLRevokePrivilege for
      # usage.
      def revoke_function_privileges(function_prototypes, privileges, roles, options = {})
        execute PostgreSQLRevokePrivilege.new(self, :function, function_prototypes, privileges, roles, options, :quote_objects => false).to_sql
      end

      # Revokes language privileges. You can specify multiple languages,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLRevokePrivilege for
      # usage.
      def revoke_language_privileges(languages, privileges, roles, options = {})
        execute PostgreSQLRevokePrivilege.new(self, :language, languages, privileges, roles, options).to_sql
      end

      # Revokes schema privileges. You can specify multiple schemas,
      # roles and privileges all at once using Arrays for each of the
      # desired parameters. See PostgreSQLRevokePrivilege for
      # usage.
      def revoke_schema_privileges(schemas, privileges, roles, options = {})
        execute PostgreSQLRevokePrivilege.new(self, :schema, schemas, privileges, roles, options, :ignore_schema => true).to_sql
      end

      # Revokes tablespace privileges. You can specify multiple
      # tablespaces, roles and privileges all at once using Arrays for
      # each of the desired parameters. See PostgreSQLRevokePrivilege for
      # usage.
      def revoke_tablespace_privileges(tablespaces, privileges, roles, options = {})
        execute PostgreSQLRevokePrivilege.new(self, :tablespace, tablespaces, privileges, roles, options).to_sql
      end

      # Revokes role membership. You can specify multiple
      # roles for both the roles and the role_names parameters using
      # Arrays.
      #
      # ==== Options
      #
      # * <tt>:with_admin_option</tt> - adds the WITH ADMIN OPTION
      #   clause to the command.
      # * <tt>:cascade</tt> - adds the CASCADE option to the command.
      def revoke_role_membership(roles, role_names, options = {})
        sql = 'REVOKE '
        sql << 'ADMIN_OPTION_FOR ' if options[:admin_option_for]
        sql << Array(roles).collect { |r| quote_role(r) }.join(', ')
        sql << ' FROM '
        sql << Array(role_names).collect { |r| quote_role(r) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end
    end

    # This is a base class for PostgreSQLGrantPrivilege and
    # PostgreSQLRevokePrivilege and is not meant to be used directly.
    class PostgreSQLPrivilege
      attr_accessor :base, :type, :objects, :privileges, :roles, :options, :query_options

      def initialize(base, type, objects, privileges, roles, options = {}, query_options = {}) #:nodoc:
        assert_valid_privileges type, privileges
        @base, @type, @objects, @privileges, @roles, @options, @query_options =
          base, type, objects, privileges, roles, options, query_options
      end

      private
        PRIVILEGE_TYPES = {
          :table         => [ 'select', 'insert', 'update', 'delete', 'references', 'trigger', 'all' ],
          :sequence      => [ 'usage', 'select', 'update', 'all' ],
          :database      => [ 'create', 'connect', 'temporary', 'all' ],
          :function      => [ 'execute', 'all' ],
          :language      => [ 'usage', 'all' ],
          :schema        => [ 'create', 'usage', 'all' ],
          :tablespace    => [ 'create', 'all' ]
        }.freeze

        def assert_valid_privileges type, privileges
          check_privileges = Array(privileges).collect(&:to_s) - PRIVILEGE_TYPES[type]
          if !check_privileges.empty?
            raise ActiveRecord::InvalidPrivilegeTypes.new(type, check_privileges)
          end
        end
    end

    # Creates queries for granting PostgreSQL role privileges.
    #
    # This class is meant to be used by the grant_*_privileges methods
    # in the PostgreSQLAdapter. Different database objects have
    # different privileges that you can apply to a role. See the
    # PostgreSQLPrivilege PRIVILEGE_TYPES constant for usage. Generally
    # speaking, you usually don't want to use this class directly, but
    # rather the aforementioned wrapped methods.
    #
    # When using the grant_*_privileges methods, you can specify multiple
    # permissions, objects and roles by using Arrays for the appropriate
    # argument.
    #
    # ==== Examples
    #
    #   grant_table_privileges([ :table1, :table2 ], :select, :joe)
    #   # => GRANT SELECT ON TABLE "table1", "table2" TO "joe"
    #
    #   grant_sequence_privileges(:my_seq, [ :select, :update ], :public)
    #   # => GRANT SELECT, UPDATE ON SEQUENCE "my_seq" TO PUBLIC
    #
    # You can specify the <tt>:with_grant_option</tt> in any of the
    # grant_*_privilege methods to add a WITH GRANT OPTION clause to
    # the command.
    class PostgreSQLGrantPrivilege < PostgreSQLPrivilege
      def to_sql #:nodoc:
        my_query_options = {
          :quote_objects => true
        }.merge query_options

        sql = "GRANT #{Array(privileges).collect(&:to_s).collect(&:upcase).join(', ')} ON #{type.to_s.upcase} "

        sql << Array(objects).collect do |t|
          if my_query_options[:quote_objects]
            if my_query_options[:ignore_schema]
              base.quote_generic_ignore_schema(t)
            else
              base.quote_table_name(t)
            end
          else
            t
          end
        end.join(', ')

        sql << ' TO ' << Array(roles).collect do |r|
          r = r.to_s
          if r.upcase == 'PUBLIC'
            'PUBLIC'
          else
            base.quote_role r
          end
        end.join(', ')

        sql << ' WITH GRANT OPTION' if options[:with_grant_option]
        "#{sql};"
      end
      alias :to_s :to_sql
    end

    # Creates queries for revoking PostgreSQL role privileges.
    #
    # This class is meant to be used by the revoke_*_privileges methods
    # in the PostgreSQLAdapter. Different database objects have
    # different privileges that you can apply to a role. See the
    # PostgreSQLPrivilege PRIVILEGE_TYPES constant for usage. Generally
    # speaking, you usually don't want to use this class directly, but
    # rather the aforementioned wrapped methods.
    #
    # When using the revoke_*_privileges methods, you can specify multiple
    # permissions, objects and roles by using Arrays for the appropriate
    # argument.
    #
    # ==== Examples
    #
    #   revoke_table_privileges([ :table1, :table2 ], :select, :joe)
    #   # => REVOKE SELECT ON TABLE "table1", "table2" FROM "joe"
    #
    #   revoke_sequence_privileges(:my_seq, [ :select, :update ], :public)
    #   # => REVOKE SELECT, UPDATE ON SEQUENCE "my_seq" FROM PUBLIC
    #
    # You can specify the <tt>:grant_option_for</tt> in any of the
    # revoke_*_privilege methods to add a GRANT OPTION FOR clause to
    # the command. Note that this option removes the role's ability to
    # grant the privilege to other roles, but does not remove the
    # privilege itself.
    #
    # You can also specify the <tt>:cascade</tt> option to cause the
    # privilege revocation to cascade down to depedent privileges.
    #
    # The cascading stuff is pretty crazy, so you may want to consult the
    # PostgreSQL docs on the subject.
    class PostgreSQLRevokePrivilege < PostgreSQLPrivilege
      def to_sql #:nodoc:
        my_query_options = {
          :quote_objects => true
        }.merge query_options

        sql = 'REVOKE '
        sql << 'GRANT OPTION FOR ' if options[:grant_option_for]
        sql << "#{Array(privileges).collect(&:to_s).collect(&:upcase).join(', ')} ON #{type.to_s.upcase} "

        sql << Array(objects).collect do |t|
          if my_query_options[:quote_objects]
            if my_query_options[:ignore_schema]
              base.quote_generic_ignore_schema(t)
            else
              base.quote_table_name(t)
            end
          else
            t
          end
        end.join(', ')

        sql << ' FROM ' << Array(roles).collect do |r|
          r = r.to_s
          if r.upcase == 'PUBLIC'
            'PUBLIC'
          else
            base.quote_role r
          end
        end.join(', ')

        sql << ' CASCADE' if options[:cascade]
        "#{sql};"
      end
      alias :to_s :to_sql
    end
  end
end
