
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/postgresql_extensions/utils'

module ActiveRecord
  class InvalidForeignKeyAction < ActiveRecordError #:nodoc:
    def initialize(action)
      super("Invalid foreign key action - #{action}")
    end
  end

  class InvalidMatchType < ActiveRecordError #:nodoc:
    def initialize(type)
      super("Invalid MATCH type - #{type}")
    end
  end

  class InvalidDeferrableOption < ActiveRecordError #:nodoc:
    def initialize(option)
      super("Invalid DEFERRABLE option - #{option}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Adds a generic constraint.
      def add_constraint(table, constraint)
        execute("ALTER TABLE #{quote_table_name(table)} ADD #{constraint};")
      end

      # Adds a CHECK constraint to the table. See
      # PostgreSQLCheckConstraint for usage.
      def add_check_constraint(table, expression, options = {})
        add_constraint(table, PostgreSQLCheckConstraint.new(self, expression, options))
      end

      # Adds a UNIQUE constraint to the table. See
      # PostgreSQLUniqueConstraint for details.
      def add_unique_constraint(table, columns, options = {})
        add_constraint(table, PostgreSQLUniqueConstraint.new(self, columns, options))
      end

      # Adds a FOREIGN KEY constraint to the table. See
      # PostgreSQLForeignKeyConstraint for details.
      def add_foreign_key_constraint(table, columns, ref_table, *args)
        add_constraint(table, PostgreSQLForeignKeyConstraint.new(self, columns, ref_table, *args))
      end
      alias :add_foreign_key :add_foreign_key_constraint

      # Adds an EXCLUDE constraint to the table. See
      # PostgreSQLExcludeConstraint for details.
      def add_exclude_constraint(table, excludes, options = {})
        add_constraint(table, PostgreSQLExcludeConstraint.new(self, table, excludes, options))
      end

      # Adds a PRIMARY KEY constraint to the table. See
      # PostgreSQLPrimaryKeyConstraint for details.
      def add_primary_key_constraint(table, columns, options = {})
        add_constraint(table, PostgreSQLPrimaryKeyConstraint.new(self, columns, options))
      end
      alias :add_primary_key :add_primary_key_constraint

      # Drops a constraint from the table. Use this to drop CHECK,
      # UNIQUE, EXCLUDE and FOREIGN KEY constraints from a table.
      #
      # Options:
      #
      # * <tt>:cascade</tt> - set to true to add a CASCADE clause to
      #   the command.
      def drop_constraint(table, name, options = {})
        sql = "ALTER TABLE #{quote_table_name(table)} DROP CONSTRAINT #{quote_generic(name)}"
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Validates a constraint and removes the NOT VALID clause from its
      # definition.
      def validate_constraint(table, name)
        execute("ALTER TABLE #{quote_table_name(table)} VALIDATE CONSTRAINT #{quote_generic(name)};")
      end
    end

    # This is a base class for other PostgreSQL constraint classes. It
    # isn't really meant to be used directly.
    class PostgreSQLConstraint
      include ActiveRecord::PostgreSQLExtensions::Utils

      attr_accessor :base, :options

      def initialize(base, options) #:nodoc:
        @base, @options = base, options
      end

      private
        DEFERRABLE_TYPES = [ 'true', 'false', 'immediate', 'deferred' ].freeze
        def assert_valid_deferrable_option option
          if !DEFERRABLE_TYPES.include?(option.to_s.downcase)
            raise ActiveRecord::InvalidDeferrableOption.new(option)
          end unless option.nil?
        end

        def deferrable
          case options[:deferrable]
            when true
              ' DEFERRABLE'
            when false
              ' NOT DEFERRABLE'
            when nil
              ''
            else
              " DEFERRABLE INITIALLY #{options[:deferrable].to_s.upcase}"
          end
        end

        def constraint_name
          if options[:name]
            "CONSTRAINT #{base.quote_generic(options[:name])} "
          end
        end

        def storage_parameters
          if options[:index_parameters] || options[:storage_parameters]
            " WITH (#{options_from_hash_or_string(options[:index_parameters] || options[:storage_parameters])})"
          else
            ''
          end
        end
        alias :index_parameters :storage_parameters

        def using_tablespace
          if options[:tablespace]
            " USING INDEX TABLESPACE #{base.quote_tablespace(options[:tablespace])}"
          else
            ''
          end
        end

        def not_valid
          if options[:not_valid]
            " NOT VALID"
          else
            ''
          end
        end

        def no_inherit
          if options[:no_inherit]
            " NO INHERIT"
          else
            ''
          end
        end
    end

    # Creates CHECK constraints for PostgreSQL tables.
    #
    # This class is meant to be used by PostgreSQL column and table
    # definition and manipulation methods. There are several ways to create
    # a CHECK constraint:
    #
    # * on a column definition
    # * on a table definition
    # * when altering a table
    #
    # === Column Definition
    #
    # When creating a new table via PostgreSQLAdapter#create_table, you
    # can specify CHECK constraints on individual columns during
    # definition.
    #
    # ==== Example
    #
    #   create_table(:foo) do |t|
    #     t.integer :fancy_id, :check => "fancy_id != 10"
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "fancy_id" integer DEFAULT NULL NULL,
    #   #   CHECK (fancy_id != 10)
    #   # );
    #
    # You can also provide an Array to <tt>:check</tt> with multiple CHECK
    # constraints. Each CHECK constraint can be either a String containing
    # the CHECK expression or a Hash containing <tt>:name</tt> and
    # <tt>:expression</tt> values if you want to provide a specific name
    # for the constraint. Otherwise, PostgreSQL will provide a name
    # automatically. Thus, the  following is equivalent to the example
    # above:
    #
    #   create_table(:foo) do |t|
    #     t.integer :fancy_id, :check => [ { :expression => "fancy_id != 10" } ]
    #   end
    #
    # See below for additional options.
    #
    # === Table Definition
    #
    # CHECK constraints can also be applied to the table directly rather
    # than on a column definition.
    #
    # ==== Examples
    #
    #   create_table(:foo) do |t|
    #     t.integer :fancy_id
    #     t.integer :another_fancy_id
    #     t.check_constraint 'fancy_id != another_fancy_id'
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "fancy_id" integer DEFAULT NULL NULL,
    #   #   "another_fancy_id" integer DEFAULT NULL NULL,
    #   #   CHECK (fancy_id != another_fancy_id)
    #   # );
    #
    #   create_table(:foo) do |t|
    #     t.integer :fancy_id
    #     t.integer :another_fancy_id
    #     t.check_constraint 'fancy_id != another_fancy_id', :name => 'my_constraint'
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "fancy_id" integer DEFAULT NULL NULL,
    #   #   "another_fancy_id" integer DEFAULT NULL NULL,
    #   #   CONSTRAINT "my_constraint" CHECK (fancy_id != another_fancy_id)
    #   # );
    #
    # See below for additional options.
    #
    # === Table Manipulation
    #
    # You can also create new CHECK constraints outside of a table
    # definition using PostgreSQLAdapter#add_check_constraint.
    #
    # ==== Example
    #
    #   add_check_constraint(:foo, 'fancy_id != 10')
    #
    #   # Produces:
    #   #
    #   # ALTER TABLE "foo" ADD CHECK (fancy_id != 10);
    #
    # See below for additional options.
    #
    # === CHECK Constraint Options
    #
    # * <tt>:name</tt> - specifies a name for the constraint.
    # * <tt>:expression</tt> - when creating a column definition, you can
    #   supply either a String containing the expression or a Hash to
    #   supply both <tt>:name</tt> and <tt>:expression</tt> values.
    # * <tt>:not_valid</tt> - adds the NOT VALID clause. Only useful when
    #   altering an existing table.
    # * <tt>:no_inherit</tt> - adds the NO INHERIT clause.
    #
    # === Dropping CHECK Constraints
    #
    # Like all PostgreSQL constraints, you can use
    # PostgreSQLAdapter#drop_constraint to remove a constraint from a
    # table.
    class PostgreSQLCheckConstraint < PostgreSQLConstraint
      attr_accessor :expression

      def initialize(base, expression, options = {}) #:nodoc:
        @expression = expression
        super(base, options)
      end

      def to_sql #:nodoc:
        "#{constraint_name}CHECK (#{expression})#{not_valid}#{no_inherit}"
      end
      alias :to_s :to_sql
    end

    # Creates UNIQUE constraints for PostgreSQL tables.
    #
    # This class is meant to be used by PostgreSQL column and table
    # definition and manipulation methods. There are several ways to use
    # this class:
    #
    # * on a column definition
    # * on a table definition
    # * when altering a table
    #
    # In PostgreSQL, a UNIQUE constraint is really just a unique index,
    # so you can alternatively add a UNIQUE constraint using the standard
    # ActiveRecord add_index method with the <tt>:unique</tt> option. You
    # can also use our expanded PostgreSQLAdapter#create_index method,
    # which adds additional PostgreSQL-specific options. See the
    # PostgreSQLIndexDefinition class for details on these extra options.
    #
    # === Column Definition
    #
    # When creating a new table via PostgreSQLAdapter#create_table, you
    # can specify UNIQUE constraints on individual columns during
    # definition.
    #
    # ==== Example
    #
    #   create_table(:foo) do |t|
    #     t.integer :fancy_id, :unique => true
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "fancy_id" integer DEFAULT NULL NULL,
    #   #   UNIQUE ("fancy_id")
    #   # );
    #
    # You can provide additional options to the UNIQUE constraint by
    # passing a Hash instead of true. See below for details on these
    # additional options.
    #
    # === Table Definition
    #
    # UNIQUE constraints can also be applied to the table directly rather
    # than on a column definition. This is useful when you want to add
    # multiple columns to the constraint.
    #
    # ==== Example
    #
    #   create_table(:foo) do |t|
    #     t.integer :fancy_id
    #     t.integer :another_fancy_id
    #     t.unique_constraint [ :fancy_id, :another_fancy_id ]
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "fancy_id" integer DEFAULT NULL NULL,
    #   #   "another_fancy_id" integer DEFAULT NULL NULL,
    #   #   UNIQUE ("fancy_id", "another_fancy_id")
    #   # );
    #
    # See below for additional options.
    #
    # === Table Manipulation
    #
    # You can also create new UNIQUE constraints outside of a table
    # definition using the standard ActiveRecord add_index method.
    # You can also use our custom add_unique_constraint which adds a couple
    # of PostgreSQL-specific options.
    #
    # Additionally, since UNIQUE constraints in PostgreSQL are really just
    # unique indexes, you can also use the the standard ActiveRecord
    # add_index method with the :unique option or our custom
    # PostgreSQLAdapter#create_index method similarly. The create_index
    # method adds a couple of PostgreSQL-specific options if you need them.
    #
    # ==== Examples
    #
    #   # using the constraint method:
    #   add_unique_constraint(:foo, [ :fancy_id, :another_fancy_id ])
    #   # => ALTER TABLE "foo" ADD UNIQUE ("fancy_id", "another_fancy_id");
    #
    #   # using create_index:
    #   create_index('my_index_name', :foo, [ :fancy_id, :another_fancy_id ], :unique => true)
    #   # => CREATE UNIQUE INDEX "my_index_name" ON "foo"("fancy_id", "another_fancy_id");
    #
    #   # using the standard ActiveRecord add_index:
    #   add_index(:foo, [ :fancy_id, :another_fancy_id ], :unique => true)
    #   # => CREATE UNIQUE INDEX "index_foo_on_fancy_id_and_another_fancy_id" ON "foo" ("fancy_id", "another_fancy_id");
    #
    # You'll notice that in create_index we must manually supply a name
    # while add_index can generate one for us automatically. See the
    # create_index documentation for details as to why this mysterious
    # departure from the standard ActiveRecord method is necessary.
    #
    # === Options for UNIQUE Constraints
    #
    # When creating UNIQUE constraints using a column or table definition
    # or when using add_unique_constraint, there are a hanful of
    # PostgreSQL-specific options that you may find useful.
    #
    # * <tt>:name</tt> - specifies a name for the constraint.
    # * <tt>:storage_parameters</tt> - PostgreSQL allows you to add a
    #   couple of additional parameters to indexes to govern disk usage and
    #   such. This option is a simple String or a Hash that lets you insert
    #   these options as necessary. See the PostgreSQL documentation on index
    #   storage parameters for details. <tt>:index_parameters</tt> can also
    #   be used.
    # * <tt>:tablespace</tt> - allows you to specify a tablespace for the
    #   unique index being created. See the PostgreSQL documentation on
    #   tablespaces for details.
    #
    # === Dropping UNIQUE Constraints
    #
    # Like all PostgreSQL constraints, you can use drop_constraint to
    # remove a constraint from a table. Since a UNIQUE constraint is really
    # just a unique index in PostgreSQL, you can also use the standard
    # ActiveRecord remove_index method or our custom
    # PostgreSQLAdapter#drop_index method.
    #
    # With drop_index, you can provide a couple of PostgreSQL-specific
    # options, which may be useful in some situations. See the
    # documentation for PostgreSQLAdapter#drop_index for details.
    class PostgreSQLUniqueConstraint < PostgreSQLConstraint
      attr_accessor :columns

      def initialize(base, columns, options = {}) #:nodoc:
        @columns = columns
        super(base, options)
      end

      def to_sql #:nodoc:
        sql = "#{constraint_name}UNIQUE ("
        sql << Array.wrap(columns).collect { |c| base.quote_column_name(c) }.join(', ')
        sql << ")"
        sql << storage_parameters
        sql << using_tablespace
        sql
      end
      alias :to_s :to_sql
    end

    # Creates FOREIGN KEY constraints for PostgreSQL tables and columns.
    #
    # This class is meant to be used by PostgreSQL column and table
    # definition and manipulation methods. There are several ways to create
    # a FOREIGN KEY constraint:
    #
    # * on a column definition
    # * on a table definition
    # * when altering a table
    #
    # === Column Definition
    #
    # When creating a new table via PostgreSQLAdapter#create_table, you
    # can specify FOREIGN KEY constraints on individual columns during
    # definition.
    #
    # ==== Example
    #
    #   create_table(:foo) do |t|
    #     t.integer :bar_id, :references => { :table => :bar, :column => :id }
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "bar_id" integer DEFAULT NULL NULL,
    #   #   FOREIGN KEY ("bar_id") REFERENCES "bar" ("id")
    #   # );
    #
    # You can leave out the :column option if you are following the Rails
    # standards for foreign key referral, as PostgreSQL automatically
    # assumes that it should be looking for a "column_name_id"-style
    # column when creating references. Alternatively, you can simply
    # specify <tt>:references => :bar</tt> if you don't need to add any
    # additional options.
    #
    # See below for additional options for the <tt>:references</tt> Hash.
    #
    # === Table Definition
    #
    # FOREIGN KEY constraints can also be applied to the table directly
    # rather than on a column definition.
    #
    # ==== Example
    #
    # The following example produces the same result as above:
    #
    #   create_table(:foo) do |t|
    #     t.integer :bar_id
    #     t.foreign_key :bar_id, :bar, :id
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "bar_id" integer DEFAULT NULL NULL,
    #   #   FOREIGN KEY ("bar_id") REFERENCES "bar" ("id")
    #   # );
    #
    # Defining a FOREIGN KEY constraint on the table-level allows you to
    # create multicolumn foreign keys. You can define these super advanced
    # foreign keys thusly:
    #
    #   create_table(:foo) {}
    #
    #   create_table(:bar) do |t|
    #     t.integer :foo_id
    #     t.unique_constraint [ :id, :foo_id ]
    #   end
    #
    #   create_table(:funk) do |t|
    #     t.integer :bar_id
    #     t.foreign_key [ :id, :bar_id ], :bar, [ :id, :foo_id ]
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key
    #   # );
    #   #
    #   # CREATE TABLE "bar" (
    #   #   "id" serial primary key,
    #   #   "foo_id" integer DEFAULT NULL NULL,
    #   #   UNIQUE ("id", "foo_id")
    #   # );
    #   #
    #   # CREATE TABLE "funk" (
    #   #   "id" serial primary key,
    #   #   "bar_id" integer DEFAULT NULL NULL,
    #   #   FOREIGN KEY ("id", "bar_id") REFERENCES "bar" ("id", "foo_id")
    #   # );
    #
    # === Table Manipulation
    #
    # You can also create new FOREIGN KEY constraints outside of a table
    # definition using PostgreSQLAdapter#add_foreign_key.
    #
    # ==== Examples
    #
    #   add_foreign_key(:foo, :bar_id, :bar)
    #   # => ALTER TABLE "foo" ADD FOREIGN KEY ("bar_id") REFERENCES "bar";
    #
    #   add_foreign_key(:foo, :bar_id, :bar, :id)
    #   # => ALTER TABLE "foo" ADD FOREIGN KEY ("bar_id") REFERENCES "bar"("id");
    #
    #   add_foreign_key(:foo, [ :bar_id, :blort_id ], :bar, [ :id, :blort_id ],
    #     :name => 'my_fk', :match => :simple
    #   )
    #   # => ALTER TABLE "foo" ADD CONSTRAINT "my_fk" FOREIGN KEY ("id", "blort_id")
    #   #    REFERENCES "bar" ("id", "blort_id") MATCH SIMPLE;
    #
    # === Options for FOREIGN KEY Constraints
    #
    # * <tt>:deferrable</tt> - sets whether or not the foreign key
    #   constraint check is deferrable during transactions. This value can
    #   be true for DEFERRABLE, false for NOT DEFERRABLE or a String/Symbol
    #   where you can set either <tt>:immediate</tt> or <tt>:deferred</tt>.
    # * <tt>:name</tt> - sets the name of the constraint.
    # * <tt>:match</tt> - sets how multicolumn foreign keys are matched
    #   against their referenced columns. This value can be <tt>:full</tt>
    #   or <tt>:simple</tt>, with PostgreSQL's default being
    #   <tt>:full</tt>.
    # * <tt>:on_delete</tt> and <tt>:on_update</tt> - set the action to
    #   take when the referenced value is updated or deleted. Possible
    #   values are <tt>:no_action</tt>, <tt>:restrict</tt>,
    #   <tt>:cascade</tt>, <tt>:set_null</tt> and <tt>:set_default</tt>.
    #   PostgreSQL's default is <tt>:no_action</tt>.
    # * <tt>:not_valid</tt> - adds the NOT VALID clause. Only useful when
    #   altering an existing table.
    #
    # See the PostgreSQL documentation on foreign keys for details about
    # the <tt>:deferrable</tt>, <tt>:match</tt>, <tt>:on_delete</tt>
    # and <tt>:on_update</tt> options.
    #
    # === Dropping FOREIGN KEY Constraints
    #
    # Like all PostgreSQL constraints, you can use
    # PostgreSQLAdapter#drop_constraint to remove a constraint from a
    # table.
    class PostgreSQLForeignKeyConstraint < PostgreSQLConstraint
      attr_accessor :columns, :ref_table, :ref_columns

      def initialize(base, columns, ref_table, *args) #:nodoc:
        options = args.extract_options!
        ref_columns = args[0] unless args.empty?

        assert_valid_match_type(options[:match]) if options[:match]
        assert_valid_action(options[:on_delete]) if options[:on_delete]
        assert_valid_action(options[:on_update]) if options[:on_update]
        assert_valid_deferrable_option(options[:deferrable])
        @columns, @ref_table, @ref_columns = columns, ref_table, ref_columns
        @schema = base.current_scoped_schema
        super(base, options)
      end

      def to_sql #:nodoc:
        sql = String.new
        base.with_schema(@schema) do
          table = if ref_table.respond_to?(:join)
            ref_table.join
          else
            ref_table
          end

          sql << "#{constraint_name}FOREIGN KEY ("
          sql << Array.wrap(columns).collect { |c| base.quote_column_name(c) }.join(', ')
          sql << ") REFERENCES #{base.quote_table_name(table)}"
          sql << ' (%s)' % Array.wrap(ref_columns).collect { |c| base.quote_column_name(c) }.join(', ') if ref_columns
          sql << " MATCH #{options[:match].to_s.upcase}" if options[:match]
          sql << " ON DELETE #{options[:on_delete].to_s.gsub(/_/, ' ').upcase}" if options[:on_delete]
          sql << " ON UPDATE #{options[:on_update].to_s.gsub(/_/, ' ').upcase}" if options[:on_update]
          sql << not_valid
          sql << deferrable
        end
        sql
      end
      alias :to_s :to_sql

      private
        MATCH_TYPES = %w{ full simple }.freeze
        ACTION_TYPES = %w{ no_action restrict cascade set_null set_default }.freeze

        def assert_valid_match_type(type) #:nodoc:
          if !MATCH_TYPES.include?(type.to_s)
            raise ActiveRecord::InvalidMatchType.new(type)
          end
        end

        def assert_valid_action(type) #:nodoc:
          if !ACTION_TYPES.include?(type.to_s)
            raise ActiveRecord::InvalidForeignKeyAction.new(type)
          end
        end
    end

    # Creates EXCLUDE constraints for PostgreSQL tables and columns.
    #
    # This class is meant to be used by PostgreSQL column and table
    # definition and manipulation methods. There are two ways to create
    # a EXCLUDE constraint:
    #
    # * on a table definition
    # * when altering a table
    #
    # In both cases, a Hash or an Array of Hashes should be used to set the
    # EXCLUDE constraint checks. The Hash(es) should be in the format
    # <tt>{ :element => ..., :with => ... }</tt>, where <tt>:element</tt> is
    # a column name or expression and <tt>:with</tt> is the operator to
    # compare against. The key <tt>:operator</tt> is an alias for <tt>:where</tt>.
    #
    # === Table Definition
    #
    # EXCLUDE constraints can also be applied to the table directly
    # rather than on a column definition.
    #
    # ==== Example
    #
    # The following example produces the same result as above:
    #
    #   create_table('foo') do |t|
    #     t.integer :blort
    #     t.exclude({
    #       :element => 'length(blort)',
    #       :with => '='
    #     }, {
    #       :name => 'exclude_blort_length'
    #     })
    #   end
    #
    #   # Produces:
    #   #
    #   # CREATE TABLE "foo" (
    #   #   "id" serial primary key,
    #   #   "blort" text,
    #   #   CONSTRAINT "exclude_blort_length" EXCLUDE (length(blort) WITH =)
    #   # );
    #
    # === Table Manipulation
    #
    # You can also create new EXCLUDE constraints outside of a table
    # definition using PostgreSQLAdapter#add_exclude_constraint.
    #
    # ==== Examples
    #
    #   add_exclude_constraint(:foo, { :element => :bar_id, :with => '=' })
    #   # => ALTER TABLE "foo" ADD EXCLUDE ("bar_id" WITH =);
    #
    # === Options for EXCLUDE Constraints
    #
    # * <tt>:name</tt> - specifies a name for the constraint.
    # * <tt>:using</tt> - sets the index type to be used. Usually this will
    #   <tt>:gist</tt>, but the default is left blank to allow for the PostgreSQL
    #   default which is <tt>:btree</tt>. See the PostgreSQL docs for details.
    # * <tt>:storage_parameters</tt> - PostgreSQL allows you to add a
    #   couple of additional parameters to indexes to govern disk usage and
    #   such. This option is a simple String or a Hash that lets you insert
    #   these options as necessary. See the PostgreSQL documentation on index
    #   storage parameters for details. <tt>:index_parameters</tt> can also
    #   be used.
    # * <tt>:tablespace</tt> - allows you to specify a tablespace for the
    #   index being created. See the PostgreSQL documentation on
    #   tablespaces for details.
    # * <tt>:conditions</tt> - sets the WHERE conditions for the EXCLUDE
    #   constraint. You can also use the <tt>:where</tt> option.
    #
    # === Dropping EXCLUDE Constraints
    #
    # Like all PostgreSQL constraints, you can use
    # PostgreSQLAdapter#drop_constraint to remove a constraint from a
    # table.
    class PostgreSQLExcludeConstraint < PostgreSQLConstraint
      attr_accessor :excludes

      def initialize(base, table, excludes, options = {}) #:nodoc:
        @excludes = ActiveRecord::PostgreSQLExtensions::Utils.hash_or_array_of_hashes(excludes)

        super(base, options)
      end

      def to_sql #:nodoc:
        sql = String.new
        sql << "#{constraint_name}EXCLUDE "
        sql << "USING #{base.quote_column_name(options[:using])} " if options[:using]
        sql << "(" << excludes.collect { |e|
          "#{e[:element]} WITH #{e[:with] || e[:operator]}"
        }.join(', ')
        sql << ")"
        sql << storage_parameters
        sql << using_tablespace
        sql << " WHERE (#{options[:conditions] || options[:where]})" if options[:conditions] || options[:where]
        sql
      end
      alias :to_s :to_sql
    end

    # Creates PRIMARY KEY constraints for PostgreSQL tables and columns.
    #
    # This class is meant to be used by PostgreSQL column and table
    # definition and manipulation methods. There are several ways to create
    # a PRIMARY KEY constraint:
    #
    # * on a table definition
    # * on a column definition
    # * when altering a table
    #
    # ActiveRecord itself already provides some methods of creating PRIMARY
    # KEYS, but we've added some PostgreSQL-specific extensions here. To
    # override ActiveRecord's built-in PRIMARY KEY generation, add an
    # option for <tt>:id => false</tt> when creating the table via
    # <tt>create_table</tt>.
    #
    # When creating PRIMARY KEYs, you can use an options Hash to add various
    # PostgreSQL-specific options as necessary or simply use a true statement
    # to create a PRIMARY KEY on the column. Composite PRIMARY KEYs can also
    # be created across multiple columns using a table definition or the
    # PostgreSQLAdapter#add_primary_key method.
    #
    # === Column Definition
    #
    # When creating a new table via PostgreSQLAdapter#create_table, you
    # can specify PRIMARY KEY constraints on individual columns during
    # definition.
    #
    # ==== Examples
    #
    #   create_table(:foo, :id => false) do |t|
    #     t.integer :foo_id, :primary_key => true
    #   end
    #
    #   # Produces:
    #   # CREATE TABLE "foo" (
    #   #   "foo_id" integer,
    #   #   PRIMARY KEY ("foo_id")
    #   # );
    #
    #   create_table('foo', :id => false) do |t|
    #     t.integer :foo_id, :primary_key => {
    #       :tablespace => 'fubar',
    #       :index_parameters => 'FILLFACTOR=10'
    #     }
    #   end
    #
    #   # Produces:
    #   # CREATE TABLE "foo" (
    #   #   "foo_id" integer,
    #   #   PRIMARY KEY ("foo_id") WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar"
    #   # );
    #
    # === Table Definition
    #
    # PRIMARY KEY constraints can also be applied to the table directly
    # rather than on a column definition.
    #
    # ==== Examples
    #
    # The following examples produces the same results as above:
    #
    #   create_table('foo', :id => false) do |t|
    #     t.integer :foo_id
    #     t.primary_key_constraint :foo_id
    #   end
    #
    #   create_table('foo', :id => false) do |t|
    #     t.integer :foo_id
    #     t.primary_key_constraint :foo_id, {
    #       :tablespace => 'fubar',
    #       :index_parameters => 'FILLFACTOR=10'
    #     }
    #   end
    #
    # === Table Manipulation
    #
    # You can also create new PRIMARY KEY constraints outside of a table
    # definition using PostgreSQLAdapter#add_primary_key or
    # PostgreSQLAdapter#add_primary_key_constraint.
    #
    # ==== Examples
    #
    #   add_primary_key(:foo, :bar_id)
    #   add_primary_key(:foo, [ :bar_id, :baz_id ])
    #   add_primary_key(:foo, :bar_id, :name => 'foo_pk')
    #   add_primary_key(:foo, :bar_id, :tablespace => 'fubar', :index_parameters => 'FILLFACTOR=10')
    #
    #   # Produces:
    #   # ALTER TABLE "foo" ADD PRIMARY KEY ("bar_id");
    #   # ALTER TABLE "foo" ADD PRIMARY KEY ("bar_id", "baz_id");
    #   # ALTER TABLE "foo" ADD CONSTRAINT "foo_pk" PRIMARY KEY ("bar_id");
    #   # ALTER TABLE "foo" ADD PRIMARY KEY ("bar_id") WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar";
    #
    # === Options for PRIMARY KEY Constraints
    #
    # * <tt>:name</tt> - specifies a name for the constraint.
    # * <tt>:storage_parameters</tt> - PostgreSQL allows you to add a
    #   couple of additional parameters to indexes to govern disk usage and
    #   such. This option is a simple String or a Hash that lets you insert
    #   these options as necessary. See the PostgreSQL documentation on index
    #   storage parameters for details. <tt>:index_parameters</tt> can also
    #   be used.
    # * <tt>:tablespace</tt> - allows you to specify a tablespace for the
    #   index being created. See the PostgreSQL documentation on
    #   tablespaces for details.
    #
    # === Dropping PRIMARY KEY Constraints
    #
    # Like all PostgreSQL constraints, you can use
    # PostgreSQLAdapter#drop_constraint to remove a constraint from a
    # table.
    class PostgreSQLPrimaryKeyConstraint < PostgreSQLConstraint
      attr_accessor :columns

      def initialize(base, columns, options = {}) #:nodoc:
        @columns = columns

        super(base, options)
      end

      def to_sql #:nodoc:
        sql = String.new
        sql << "#{constraint_name}PRIMARY KEY "
        sql << "(" << Array.wrap(columns).collect { |column|
          base.quote_column_name(column)
        }.join(', ')
        sql << ")"
        sql << storage_parameters
        sql << using_tablespace
        sql
      end
      alias :to_s :to_sql
    end
  end
end
