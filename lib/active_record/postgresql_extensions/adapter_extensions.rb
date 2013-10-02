
module ActiveRecord
  class InvalidCopyFromOptions < ActiveRecordError #:nodoc:
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # with_schema is kind of like with_scope. It wraps various
      # object names in SQL statements into a PostgreSQL schema. You
      # can have multiple with_schemas wrapped around each other, and
      # hopefully they won't collide with one another.
      #
      # ==== Examples
      #
      #   # should produce '"geospatial"."my_tables"'
      #   with_schema :geospatial do
      #     quote_table_name('my_table')
      #   end
      #
      #   # should produce 'SELECT * FROM "geospatial"."models"'
      #   with_schema :geospatial do
      #     Model.find(:all)
      #   end
      def with_schema(schema)
        scoped_schemas << schema
        begin
          yield
        ensure
          scoped_schemas.pop
        end
      end

      # When using with_schema, you can temporarily ignore the scoped
      # schemas with ignore_block.
      #
      # ==== Example
      #
      #   with_schema :geospatial do
      #     create_table(:test) do |t|
      #       ignore_scoped_schema do
      #         t.integer(
      #           :ref_id,
      #           :references => {
      #             :table => :refs,
      #             :column => :id,
      #             :deferrable => true
      #           }
      #         )
      #       end
      #     end
      #   end
      #
      #   # Produces:
      #   #
      #   # CREATE TABLE "geospatial"."test" (
      #   #   "id" serial primary key,
      #   #   "ref_id" integer DEFAULT NULL NULL,
      #   #   FOREIGN KEY ("ref_id") REFERENCES "refs" ("id")
      #   # )
      #
      # Here we see that we used the geospatial schema when naming the
      # test table and dropped back to not specifying a schema when
      # setting up the foreign key to the refs table. If we had not
      # used ignore_scoped_schema, the foreign key would have been defined
      # thusly:
      #
      #   FOREIGN KEY ("ref_id") REFERENCES "geospatial"."refs" ("id")
      def ignore_scoped_schema
        with_schema nil do
          yield
        end
      end

      # See what the current scoped schemas are. Should be thread-safe
      # if using the PostgreSQL adapter's concurrency mode.
      def scoped_schemas
        scoped_schemas = (Thread.current[:scoped_schemas] ||= {})
        scoped_schemas[self] ||= []
      end

      # Get the current scoped schema.
      def current_scoped_schema
        scoped_schemas.last
      end

      # A generic quoting method for PostgreSQL.
      if RUBY_PLATFORM == 'java'
        def quote_generic(g)
          quote_column_name(g)
        end
      else
        def quote_generic(g)
          PGconn.quote_ident(g.to_s)
        end
      end

      # A generic quoting method for PostgreSQL that specifically ignores
      # any and all schemas.
      def quote_generic_ignore_scoped_schema(g)
        if g.is_a?(Hash)
          quote_generic g.values.first
        else
          quote_generic g
        end
      end

      # A generic quoting method for PostgreSQL with our special schema
      # support.
      def quote_generic_with_schema(g)
        if g.is_a?(Hash)
          "#{quote_schema(g.keys.first)}.#{quote_generic(g.values.first)}"
        else
          if current_scoped_schema
            quote_schema(current_scoped_schema) << '.'
          end.to_s << quote_generic(g)
        end
      end

      # Quoting method for roles.
      def quote_role(role)
        quote_generic(role)
      end

      # Quoting method for rules.
      def quote_rule(rule)
        quote_generic(rule)
      end

      # Quoting method for procedural languages.
      def quote_language(language)
        quote_generic(language)
      end

      # Quoting method for schemas. When the schema is :public or
      # 'public' or some form thereof, we'll convert that to "PUBLIC"
      # without quoting.
      def quote_schema(schema)
        if schema.to_s.upcase == 'PUBLIC'
          'PUBLIC'
        else
          quote_generic(schema)
        end
      end

      # Quoting method for sequences. This really just goes to the
      # quoting method for table names, as sequences can belong to
      # specific schemas.
      def quote_sequence(name)
        quote_generic_with_schema(name)
      end

      # Quoting method for server-side functions.
      def quote_function(name)
        quote_generic_with_schema(name)
      end

      # Quoting method for table names. This method has been extended
      # beyond the standard ActiveRecord quote_table_name to allow for
      #
      # * scoped schema support with with_schema. When using with_schema,
      #   table names will be prefixed with the current scoped schema
      #   name.
      # * you can specify a specific schema using a Hash containing a
      #   single value pair where the key is the schema name and the
      #   key is the table name.
      #
      # Example of using a Hash as a table name:
      #
      #   quote_table_name(:geospatial => :epois) # => "geospatial"."epois"
      #   # => "geospatial"."epois"
      #
      #   quote_table_name(:epois)
      #   # => "epois"
      #
      #   with_schema(:geospatial) { quote_table_name(:epois) }
      #   # => "geospatial"."epois"
      #
      #   with_schema(:geospatial) do
      #     ignore_scoped_schema do
      #       quote_table_name(:epois)
      #     end
      #   end
      #   # => "epois"
      def quote_table_name_with_schemas(name)
        if current_scoped_schema || name.is_a?(Hash)
          quote_generic_with_schema(name)
        else
          quote_table_name_without_schemas(name)
        end
      end
      alias_method_chain :quote_table_name, :schemas

      # Quoting method for view names. This really just goes to the
      # quoting method for table names, as views can belong to specific
      # schemas.
      def quote_view_name(name)
        quote_table_name(name)
      end

      # Quoting method for tablespaces.
      def quote_tablespace(name)
        quote_generic(name)
      end

      def extract_schema_name(name)
        schema, name_part = extract_pg_identifier_from_name(name.to_s)
        schema if name_part
      end

      def extract_table_name(name)
        schema, name_part = extract_pg_identifier_from_name(name.to_s)

        unless name_part
          schema
        else
          table_name, name_part = extract_pg_identifier_from_name(name_part)
          table_name
        end
      end

      def extract_schema_and_table_names(name)
        schema, name_part = extract_pg_identifier_from_name(name.to_s)

        unless name_part
          quote_column_name(schema)
          [ nil, schema ]
        else
          table_name, name_part = extract_pg_identifier_from_name(name_part)
          [ schema, table_name ]
        end
      end

      # Copies the contents of a file into a table. This uses
      # PostgreSQL's COPY FROM command.
      #
      # The COPY FROM command requires the input file to be readable
      # on the server the database is actually running on. In our method,
      # you have the choice of a file on your client's local file system
      # or one on the server's local file system. See the
      # <tt>:local</tt> option below.
      #
      # See the PostgreSQL documentation for details on COPY FROM.
      #
      # ==== Options
      #
      # * <tt>:columns</tt> - allows you to specify column names.
      # * <tt>:binary</tt> - adds the BINARY clause.
      # * <tt>:oids</tt> - adds the OIDS clause.
      # * <tt>:delimiter</tt> - sets the delimiter for the data fields.
      #   The default COPY FROM delimiter in ASCII mode is a tab
      #   character, while in CSV it is a comma.
      # * <tt>:null</tt> - allows you to set a default value for null
      #   fields. The default for this option is unset.
      # * <tt>:local</tt> - allows you to specify that the file to be
      #   copied from is on a file system that is directly accessible
      #   from the database server itself. The default is true, i.e.
      #   the file is local to the client. See below for a more thorough
      #   explanation.
      # * <tt>:csv</tt> - allows you to specify a CSV file. This option
      #   can be set to true, in which case you'll be using the server
      #   defaults for its CSV imports, or a Hash, in which case you can
      #   modify various CSV options like quote and escape characters.
      #
      # ===== CSV Options
      #
      # * <tt>:header</tt> - uses the first line as a CSV header row and
      #   skips over it.
      # * <tt>:quote</tt> - the character to use for quoting. The default
      #   is a double-quote.
      # * <tt>:escape</tt> - the character to use when escaping a quote
      #   character. Usually this is another double-quote.
      # * <tt>:not_null</tt> - allows you to specify one or more columns
      #   to be inserted with a default value rather than NULL for any
      #   missing values.
      # * <tt>:freeze</tt> - a performance enhancement added in PostgreSQL 9.3.
      #   See the PostgreSQL documentation for details.
      # * <tt>:encoding</tt> - set the encoding of the input. Available in
      #   PostgreSQL 9.1+.
      #
      # ==== Local Server Files vs. Local Client Files vs. PROGRAM
      #
      # The copy_from method allows you to import rows from a file
      # that exists on either your client's file system or on the
      # database server's file system using the <tt>:local</tt> option.
      #
      # PostgreSQL 9.3 additionally introduced the PROGRAM option to COPY
      # FROM that allows you to pipe the output of a shell command to
      # STDIN. This option requires that the COPY FROM command be run from on
      # the server and as such may be limited by server restrictions such as
      # access controls and permissions.
      #
      # To process a file on the remote database server's file system:
      #
      # * the file must be given as an absolute path or as a valid shell
      #   command if using the PROGRAM option;
      # * must be readable by the user that the actual PostgreSQL
      #   database server runs under; and
      # * the COPY FROM command itself can only be performed by database
      #   superusers.
      #
      # In comparison, reading the file from the local client does not
      # have restrictions enforced by PostgreSQL and can be performed on
      # the client machine. When using a local file, the file itself is
      # actually opened in Ruby and pushed into the database via a
      # "COPY FROM STDIN" command. Thus, the file must be readable by
      # the user your Ruby process is running as. PostgreSQL will not
      # enforce the superuser restriction in this case since you are not
      # touching the database server's local file system.
      #
      # Some considerations:
      #
      # * A copy from the database's local file system is faster than a
      #   local copy, as the data need not be read into Ruby and dumped
      #   across the network or UNIX socket to the database server.
      # * A local copy is generally more flexible as it bypasses some of
      #   PostgreSQL's security considerations.
      # * Copies from the server's file system require that the file
      #   exists on the file system accessible to the database server,
      #   something that you may not even have access to in the first
      #   place.
      def copy_from(table_name, file, options = {})
        options = {
          :local => true
        }.merge(options)

        assert_valid_copy_from_options(options)

        sql = "COPY #{quote_table_name(table_name)}"

        unless options[:columns].blank?
          sql << ' (' << Array.wrap(options[:columns]).collect { |c| quote_column_name(c) }.join(', ') << ')'
        end

        if options[:program]
          sql << " FROM PROGRAM #{quote(file)}"
        elsif options[:local]
          sql << " FROM STDIN"
        else
          sql << " FROM #{quote(file)}"
        end

        sql << ' FREEZE' if options[:freeze]
        sql << ' BINARY' if options[:binary]
        sql << ' OIDS' if options[:oids]
        sql << " DELIMITER AS #{quote(options[:delimiter])}" if options[:delimiter]
        sql << " NULL AS #{quote(options[:null_as])}" if options[:null]
        sql << " ENCODING #{quote(options[:encoding])}" if options[:encoding]

        if options[:csv]
          sql << ' CSV'
          if options[:csv].is_a?(Hash)
            sql << ' HEADER' if options[:csv][:header]
            sql << " QUOTE AS #{quote(options[:csv][:quote])}" if options[:csv][:quote]
            sql << " ESCAPE AS #{quote(options[:csv][:escape])}" if options[:csv][:escape]
            sql << ' FORCE NOT NULL ' << Array.wrap(options[:csv][:not_null]).collect do |c|
              quote_column_name(c)
            end.join(', ') if options[:csv][:not_null]
          end
        end

        sql << ';'

        if options[:program] || !options[:local]
          execute sql
        else
          fp = File.open(file, 'r')

          if self.raw_connection.respond_to?(:copy_data)
            self.raw_connection.copy_data(sql) do
              fp.each do |l|
                self.raw_connection.put_copy_data(l)
              end
            end
          else
            execute sql
            fp.each do |l|
              self.raw_connection.put_copy_data(l)
            end
            self.raw_connection.put_copy_end
          end
        end
      end
      alias :copy_from_file :copy_from

      # Returns an Array of database views.
      def views(name = nil)
        query(PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL), name).map { |row| row[0] }
          SELECT viewname
          FROM pg_views
          WHERE schemaname = ANY (current_schemas(false))
        SQL
      end

      def view_exists?(name)
        name         = name.to_s
        schema, view = name.split('.', 2)

        unless view # A view was provided without a schema
          view  = schema
          schema = nil
        end

        if name =~ /^"/ # Handle quoted view names
          view  = name
          schema = nil
        end

        query(PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL)).first[0].to_i > 0
          SELECT COUNT(*)
          FROM pg_views
          WHERE viewname = '#{view.gsub(/(^"|"$)/,'')}'
          #{schema ? "AND schemaname = '#{schema}'" : ''}
        SQL
      end

      def roles(name = nil)
        query(PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL), name).map { |row| row[0] }
          SELECT rolname
          FROM pg_roles
        SQL
      end

      def role_exists?(name)
        roles.include?(name)
      end

      # Sets the current database role/user. The :duration option can be set to
      # :session or :local as described in the PostgreSQL docs.
      def set_role(role, options = {})
        duration = if options[:duration]
          if [ :session, :local ].include?(options[:duration])
            options[:duration].to_s.upcase
          else
            raise ArgumentError.new("The :duration option must be one of :session or :local.")
          end
        end

        sql = 'SET '
        sql << "#{duration} " if duration
        sql << "ROLE #{quote_role(role)};"
        execute(sql, "Setting current role")
      end

      def reset_role
        execute('RESET ROLE;')
      end

      def current_role
        execute('SELECT current_role;')
      end
      alias :current_user :current_role

      # Returns an Array of tables to ignore.
      def ignored_tables(name = nil)
        query(PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL), name).map { |row| row[0] }
          SELECT tablename
          FROM pg_tables
          WHERE schemaname IN ('pg_catalog');
        SQL
      end

      def tables_with_views(name = nil) #:nodoc:
        tables_without_views(name) + views(name)
      end
      alias_method_chain :tables, :views

      unless RUBY_PLATFORM == "java"
        # There seems to be a bug in ActiveRecord where it isn't setting
        # the schema search path properly because it's using ',' as a
        # separator rather than /,\s+/.
        def schema_search_path_with_csv_fix=(schema_csv) #:nodoc:
          self.schema_search_path_without_csv_fix = schema_csv.gsub(/,\s+/, ',') if schema_csv
        end
        alias_method_chain :schema_search_path=, :csv_fix

        # Fix ActiveRecord bug when grabbing the current search_path.
        def schema_search_path_with_csv_fix
          @schema_search_path ||= query('SHOW search_path;')[0][0].gsub(/,\s+/, ',')
        end
        alias_method_chain :schema_search_path, :csv_fix
      end

      def disable_referential_integrity_with_views #:nodoc:
        if supports_disable_referential_integrity? then
          execute(tables_without_views.collect { |name|
            "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL"
          }.join(";"))
        end
        yield
      ensure
        if supports_disable_referential_integrity? then
          execute(tables_without_views.collect { |name|
            "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL"
          }.join(";"))
        end
      end
      alias_method_chain :disable_referential_integrity, :views

      # Enable triggers. If no triggers are specified, all triggers will
      # be enabled.
      def enable_triggers(table, *triggers)
        quoted_table_name = quote_table_name(table)
        triggers = if triggers.present?
          triggers.collect { |trigger|
            quote_generic(trigger)
          }
        else
          'ALL'
        end

        Array.wrap(triggers).each do |trigger|
          execute("ALTER TABLE #{quoted_table_name} ENABLE TRIGGER #{trigger};")
        end
      end

      # Disable triggers. If no triggers are specified, all triggers will
      # be disabled.
      def disable_triggers(table, *triggers)
        quoted_table_name = quote_table_name(table)
        triggers = if triggers.present?
          triggers.collect { |trigger|
            quote_generic(trigger)
          }
        else
          'ALL'
        end

        Array.wrap(triggers).each do |trigger|
          execute("ALTER TABLE #{quoted_table_name} DISABLE TRIGGER #{trigger};")
        end
      end

      # Temporarily disable triggers. If no triggers are specified, all
      # triggers will be disabled.
      def without_triggers(table, *triggers)
        disable_triggers(table, *triggers)
        yield
      ensure
        enable_triggers(table, *triggers)
      end

      # Returns an Array of foreign keys for a particular table. The
      # Array itself is an Array of Arrays, where each particular Array
      # contains the table being referenced, the foreign key and the
      # name of the column in the referenced table.
      def foreign_keys(table_name, name = nil)
        sql = PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL)
          SELECT
            confrelid::regclass AS referenced_table_name,
            a.attname AS foreign_key,
            af.attname AS referenced_column
          FROM
            pg_attribute af,
            pg_attribute a,
            pg_class c, (
              SELECT
                conrelid,
                confrelid,
                conkey[i] AS conkey,
                confkey[i] AS confkey
              FROM (
                SELECT
                  conrelid,
                  confrelid,
                  conkey,
                  confkey,
                  generate_series(1, array_upper(conkey, 1)) AS i
                FROM
                  pg_constraint
                WHERE
                  contype = 'f'
              ) ss
            ) ss2
          WHERE
            c.oid = conrelid
              AND
            c.relname = #{quote(table_name)}
              AND
            af.attnum = confkey
              AND
            af.attrelid = confrelid
              AND
            a.attnum = conkey
              AND
            a.attrelid = conrelid
          ;
        SQL

        query(sql, name).inject([]) do |memo, (tbl, column, referenced_column)|
          memo.tap {
            memo << {
              :table => tbl,
              :column => column,
              :referenced_column => referenced_column
            }
          }
        end
      end

      # Returns an Array of foreign keys that point to a particular
      # table. The Array itself is an Array of Arrays, where each
      # particular Array contains the referencing table, the foreign key
      # and the name of the column in the referenced table.
      def referenced_foreign_keys(table_name, name = nil)
        sql = PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL)
          SELECT
            c2.relname AS table_name,
            a.attname AS foreign_key,
            af.attname AS referenced_column
          FROM
            pg_attribute af,
            pg_attribute a,
            pg_class c1,
            pg_class c2, (
              SELECT
                conrelid,
                confrelid,
                conkey[i] AS conkey,
                confkey[i] AS confkey
              FROM (
                SELECT
                  conrelid,
                  confrelid,
                  conkey,
                  confkey,
                  generate_series(1, array_upper(conkey, 1)) AS i
                FROM
                  pg_constraint
                WHERE
                  contype = 'f'
              ) ss
            ) ss2
          WHERE
            confrelid = c1.oid
              AND
            conrelid = c2.oid
              AND
            c1.relname = #{quote(table_name)}
              AND
            af.attnum = confkey
              AND
            af.attrelid = confrelid
              AND
            a.attnum = conkey
              AND
            a.attrelid = conrelid
          ;
        SQL

        query(sql, name).inject([]) do |memo, (tbl, column, referenced_column)|
          memo.tap {
            memo << {
              :table => tbl,
              :column => column,
              :referenced_column => referenced_column
            }
          }
        end
      end

      # Run the CLUSTER command on all previously clustered tables available
      # to be clustered by the current user.
      #
      # ==== Options
      #
      # * <tt>:verbose</tt> - Adds the VERBOSE clause.
      def cluster_all(options = {})
        sql = 'CLUSTER'
        sql << ' VERBOSE' if options[:verbose]

        execute "#{sql};"
      end

      # Cluster a table or materialized view on an index.
      #
      # ==== Options
      #
      # * <tt>:using</tt> - adds a USING clause to cluster on. If no
      #   <tt>:using</tt> option is provided, the object itself will be
      #   re-clustered.
      # * <tt>:verbose</tt> - Adds the VERBOSE clause.
      def cluster(name, options = {})
        sql = 'CLUSTER '
        sql << 'VERBOSE ' if options[:verbose]
        sql << quote_table_name(name)
        sql << " USING #{quote_generic(options[:using])}" if options[:using]

        execute "#{sql};"
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

      def change_column_default_with_expression(table_name, column_name, default) #:nodoc:
        if default.is_a?(Hash) && default.has_key?(:expression)
          execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{default[:expression]};"
        else
          change_column_default_without_expression(table_name, column_name, default)
        end
      end
      alias_method_chain :change_column_default, :expression

      def change_column_null_with_expression(table_name, column_name, null, default = nil) #:nodoc:
        if default.is_a?(Hash) && default.has_key?(:expression)
          unless null
            execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)} = #{default[:expression]} WHERE #{quote_column_name(column_name)} IS NULL")
          end
          execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL")
        else
          change_column_null_without_expression(table_name, column_name, null, default = nil)
        end
      end
      alias_method_chain :change_column_null, :expression

      private
        def assert_valid_copy_from_options(options)
          if options[:program] && !ActiveRecord::PostgreSQLExtensions::Features.copy_from_program?
            raise InvalidCopyFromOptions.new("The :program option is only available in PostgreSQL 9.3+.")
          end

          if options[:freeze] && !ActiveRecord::PostgreSQLExtensions::Features.copy_from_freeze?
            raise InvalidCopyFromOptions.new("The :freeze option is only available in PostgreSQL 9.3+.")
          end

          if options[:encoding] && !ActiveRecord::PostgreSQLExtensions::Features.copy_from_encoding?
            raise InvalidCopyFromOptions.new("The :encoding option is only available in PostgreSQL 9.1+.")
          end
        end
    end

    class PostgreSQLColumn
      def simplified_type_with_additional_types(field_type)
        case field_type
          when 'geometry'
            :geometry
          when 'geography'
            :geography
          when 'tsvector'
            :tsvector
          else
            simplified_type_without_additional_types(field_type)
        end
      end
      alias_method_chain :simplified_type, :additional_types
    end
  end
end

module ActiveRecord
  class Base
    class << self
      def with_schema(schema)
        self.connection.with_schema(schema) { |*block_args|
          yield(*block_args)
        }
      end

      def ignore_scoped_schema
        self.connection.ignore_scoped_schema { |*block_args|
          yield(*block_args)
        }
      end

      def scoped_schemas
        self.connection.scope_schemas
      end

      def current_scoped_schema
        self.connection.current_scoped_schema
      end

      def sequence_exists?
        !!(connection.sequence_exists?(sequence_name) if connection.respond_to?(:sequence_exists?))
      end

      def view_exists?
        connection.view_exists?(table_name)
      end
    end
  end
end

