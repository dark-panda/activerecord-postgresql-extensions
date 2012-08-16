
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidLikeTypes < ActiveRecordError #:nodoc:
    def initialize(likes)
      super("Invalid LIKE INCLUDING/EXCLUDING types - #{likes.inspect}")
    end
  end

  class InvalidTableOptions < ActiveRecordError #:nodoc:
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Set the schema of a table.
      def alter_table_schema(table_name, schema, options = {})
        execute "ALTER TABLE #{quote_schema(table_name)} SET SCHEMA #{quote_schema(schema)};"
      end

      alias :original_create_table :create_table
      # Creates a new table. We've expanded the capabilities of the
      # standard ActiveRecord create_table method to included a host of
      # PostgreSQL-specific functionality.
      #
      # === PostgreSQL-specific Do-dads
      #
      # PostgreSQL allows for a couple of nifty table creation options
      # that ActiveRecord usually doesn't account for, so we're filling
      # in the blanks here.
      #
      # * <tt>:inherits</tt> - PostgreSQL allows you to create tables
      #   that inherit the properties of another. PostgreSQL is
      #   sometimes referred to as an Object-Relational DBMS rather
      #   than a straight-up RDBMS because of stuff like this.
      # * <tt>:on_commit</tt> - allows you to define the behaviour of
      #   temporary tables. Allowed values are <tt>:preserve_rows</tt>
      #   (the default, which causes the temporary table to retain its
      #   rows at the end of a transaction), <tt>:delete_rows</tt>
      #   (which truncates the table at the end of a transaction) and
      #   <tt>:drop</tt> (which drops the table at the end of a
      #   transaction).
      # * <tt>:tablespace</tt> - allows you to set the tablespace of a
      #   table.
      # * <tt>:force</tt> - force a table to be dropped before trying to
      #   create it. This will pass <tt>:if_exists => true</tt> to the
      #   drop_table method.
      # * <tt>:cascade_drop</tt> - when using the <tt>:force</tt>, this
      #   Jedi mindtrick will pass along the :cascade option to
      #   drop_table.
      # * <tt>:of_type</tt> - for "OF type_name" clauses.
      # * <tt>:if_not_exists</tt> - adds the "IF NOT EXISTS" clause.
      # * <tt>:unlogged</tt> - creates an UNLOGGED table.
      #
      # We're expanding the doors of table definition perception with
      # this exciting new addition to the world of ActiveRecord
      # PostgreSQL adapters.
      #
      # create_table generally behaves like the standard ActiveRecord
      # create_table method with a couple of notable exceptions:
      #
      # * you can add column constraints.
      # * you can add constraints to the table itself.
      # * you can add LIKE and INHERITS clauses to the definition.
      #
      # See the PostgreSQL documentation for more detailed on these
      # sorts of things. Odds are that you'll probably recognize what
      # we're referring to here if you're bothering to use this
      # plugin, eh?
      #
      # Also, do note that you can grant privileges on tables using the
      # grant_table_privileges method and revoke them using
      # revoke_table_privileges.
      #
      # ==== Examples
      #
      #   create_table(:foo, :inherits => :parent) do |t|
      #     t.integer :bar_id, :references => :bar
      #     t.like :base, :including => [ :defaults, :indexes ], :excluding => :constraints
      #     t.check_constraint "bar_id < 100"
      #     t.unique_constraint :bar_id
      #   end
      #
      #   # Produces:
      #   #
      #   # CREATE TABLE "foo" (
      #   #   "id" serial primary key,
      #   #   "bar_id" integer DEFAULT NULL NULL,
      #   #   LIKE "base" INCLUDING DEFAULTS INCLUDING INDEXES EXCLUDING CONSTRAINTS,
      #   #   FOREIGN KEY ("bar_id") REFERENCES "bar",
      #   #   CHECK (bar_id < 100),
      #   #   UNIQUE ("bar_id")
      #   # ) INHERITS ("parent");
      #
      # This is a fairly convoluted example, but there you have it.
      #
      # Beyond these differences, create_table acts like the original
      # ActiveRecord create_table, which you can actually still access
      # using the original_create_table method if you really, really want
      # to.
      #
      # Be sure to refer to the PostgreSQL documentation for details on
      # data definition and such.
      def create_table(table_name, options = {})
        if options[:force]
          drop_table(table_name, { :if_exists => true, :cascade => options[:cascade_drop] })
        end

        table_definition = PostgreSQLTableDefinition.new(self, table_name, options)
        yield table_definition if block_given?

        execute table_definition.to_s
        unless table_definition.post_processing.blank?
          table_definition.post_processing.each do |pp|
            execute pp
          end
        end
      end

      alias :original_drop_table :drop_table
      # Drops a table. This method is expanded beyond the standard
      # ActiveRecord drop_table method to allow for a couple of
      # PostgreSQL-specific options:
      #
      # * <tt>:if_exists</tt> - adds an IF EXISTS clause to the query.
      #   In absence of this option, an exception will be raised if you
      #   try to drop a table that doesn't exist.
      # * <tt>:cascade</tt> - adds a CASCADE clause to the query. This
      #   will cause references to this table like foreign keys to be
      #   dropped as well. See the PostgreSQL documentation for details.
      #
      # You can still access the original method via original_drop_table.
      def drop_table(tables, options = {})
        sql = 'DROP TABLE '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array(tables).collect { |t| quote_table_name(t) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      alias :original_rename_table :rename_table
      # Renames a table. We're overriding the original rename_table so
      # that we can take advantage of our super schema quoting
      # capabilities. You can still access the original method via
      # original_rename_table.
      def rename_table(name, new_name, options = {})
        execute "ALTER TABLE #{quote_table_name(name)} RENAME TO #{quote_generic_ignore_scoped_schema(new_name)};"
      end

      private
        ON_COMMIT_VALUES = [ 'preserve_rows', 'delete_rows', 'drop' ].freeze

        def assert_valid_on_commit(temp, on_commit)
          unless on_commit.nil?
            if !ON_COMMIT_VALUES.include?(on_commit.to_s.downcase)
              raise ActiveRecord::InvalidTableOptions.new("Invalid ON COMMIT value - #{on_commit}")
            elsif !temp
              raise ActiveRecord::InvalidTableOptions.new("ON COMMIT can only be used with temporary tables")
            end
          end
        end
    end

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
    class PostgreSQLTableDefinition < TableDefinition
      attr_accessor :base, :table_name, :options, :post_processing

      def initialize(base, table_name, options = {}) #:nodoc:
        @table_constraints = Array.new
        @table_name, @options = table_name, options
        super(base)

        self.primary_key(
          options[:primary_key] || Base.get_primary_key(table_name)
        ) unless options[:id] == false
      end

      def to_sql #:nodoc:
        sql = 'CREATE '
        sql << 'TEMPORARY ' if options[:temporary]
        sql << 'UNLOGGED ' if options[:unlogged]
        sql << 'TABLE '
        sql << 'IF NOT EXISTS ' if options[:if_not_exists]
        sql << "#{base.quote_table_name(table_name)} "
        sql << "OF #{base.quote_table_name(options[:of_type])} " if options[:of_type]
        sql << "(\n  "

        ary = @columns.collect(&:to_sql)
        ary << @like if defined?(@like) && @like
        ary << @table_constraints unless @table_constraints.empty?
        sql << ary * ",\n  "
        sql << "\n)"

        sql << "\nINHERITS (" << Array(options[:inherits]).collect { |i| base.quote_table_name(i) }.join(', ') << ')' if options[:inherits]
        sql << "\nON COMMIT #{options[:on_commit].to_s.upcase.gsub(/_/, ' ')}" if options[:on_commit]
        sql << "\n#{options[:options]}" if options[:options]
        sql << "\nTABLESPACE #{base.quote_tablespace(options[:tablespace])}" if options[:tablespace]
        "#{sql};"
      end
      alias :to_s :to_sql

      # Creates a LIKE statement for use in a table definition.
      #
      # ==== Options
      #
      # * <tt>:including</tt> and <tt>:excluding</tt> - set options for
      #   the INCLUDING and EXCLUDING clauses in a LIKE statement. Valid
      #   values are <tt>:constraints</tt>, <tt>:defaults</tt> and
      #   <tt>:indexes</tt>. You can set one or more by using an Array.
      #
      # See the PostgreSQL documentation for details on how to use
      # LIKE. Be sure to take note as to how it differs from INHERITS.
      #
      # Also, be sure to note that, like, this LIKE isn't, like, the
      # LIKE you use in a WHERE condition. This is, PostgreSQL's
      # own special LIKE clause for table definitions. Like.
      def like(parent_table, options = {})
        assert_valid_like_types(options[:includes])
        assert_valid_like_types(options[:excludes])

        # Huh? Whyfor I dun this?
        # @like = base.with_schema(@schema) { "LIKE #{base.quote_table_name(parent_table)}" }
        @like = "LIKE #{@base.quote_table_name(parent_table)}"

        if options[:including]
          @like << Array(options[:including]).collect { |l| " INCLUDING #{l.to_s.upcase}" }.join
        end

        if options[:excluding]
          @like << Array(options[:excluding]).collect { |l| " EXCLUDING #{l.to_s.upcase}" }.join
        end
        @like
      end

      # Add a CHECK constraint to the table. See
      # PostgreSQLCheckConstraint for more details.
      def check_constraint(expression, options = {})
        @table_constraints << PostgreSQLCheckConstraint.new(@base, expression, options)
      end

      # Add a UNIQUE constraint to the table. See
      # PostgreSQLUniqueConstraint for more details.
      def unique_constraint(columns, options = {})
        @table_constraints << PostgreSQLUniqueConstraint.new(@base, columns, options)
      end

      # Add a FOREIGN KEY constraint to the table. See
      # PostgreSQLForeignKeyConstraint for more details.
      def foreign_key(columns, ref_table, *args)
        @table_constraints << PostgreSQLForeignKeyConstraint.new(@base, columns, ref_table, *args)
      end

      # Add an EXCLUDE constraint to the table. See PostgreSQLExcludeConstraint
      # for more details.
      def exclude(excludes, options = {})
        @table_constraints << PostgreSQLExcludeConstraint.new(@base, table_name, excludes, options)
      end

      def column_with_constraints(name, type, *args) #:nodoc:
        options = args.extract_options!
        check = options.delete(:check)
        references = options.delete(:references)
        unique = options.delete(:unique)
        column_without_constraints(name, type, options)

        if check
          check = if !check.is_a?(Array)
            [ check ]
          else
            check
          end

          @table_constraints << check.collect do |c|
            if c.is_a?(Hash)
              PostgreSQLCheckConstraint.new(@base, c.delete(:expression), c)
            else
              PostgreSQLCheckConstraint.new(@base, c)
            end
          end
        end

        if references
          ref_table, ref_options = if references.is_a?(Hash)
            [ references.delete(:table), references ]
          else
            [ references, {} ]
          end

          @table_constraints << PostgreSQLForeignKeyConstraint.new(
            @base,
            name,
            ref_table,
            ref_options
          )
        end

        if unique
          unless unique.is_a?(Hash)
            unique = {}
          end
          @table_constraints << PostgreSQLUniqueConstraint.new(@base, name, unique)
        end
        self
      end
      alias_method_chain :column, :constraints

      private
        LIKE_TYPES = %w{ defaults constraints indexes }.freeze

        def assert_valid_like_types(likes) #:nodoc:
          unless likes.blank?
            check_likes = Array(likes).collect(&:to_s) - LIKE_TYPES
            if !check_likes.empty?
              raise ActiveRecord::InvalidLikeTypes.new(check_likes)
            end
          end
        end
    end
  end
end
