
module ActiveRecord::PostgreSQLExtensions
  module SharedTableDefinition
    extend ActiveSupport::Concern

    included do
      attr_accessor :like_options

      alias_method_chain :column, :constraints
    end

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
      self.like_options = ActiveRecord::PostgreSQLExtensions::PostgreSQLLikeOptions.new(@base, parent_table, options)
    end

    # Add a CHECK constraint to the table. See
    # PostgreSQLCheckConstraint for more details.
    def check_constraint(expression, options = {})
      table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLCheckConstraint.new(@base, expression, options)
    end

    # Add a UNIQUE constraint to the table. See
    # PostgreSQLUniqueConstraint for more details.
    def unique_constraint(columns, options = {})
      table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLUniqueConstraint.new(@base, columns, options)
    end

    # Add a FOREIGN KEY constraint to the table. See
    # PostgreSQLForeignKeyConstraint for more details.
    def foreign_key(columns, ref_table, *args)
      table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLForeignKeyConstraint.new(@base, columns, ref_table, *args)
    end

    # Add an EXCLUDE constraint to the table. See PostgreSQLExcludeConstraint
    # for more details.
    def exclude(excludes, options = {})
      table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLExcludeConstraint.new(@base, table_name, excludes, options)
    end

    def primary_key_constraint(columns, options = {})
      table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLPrimaryKeyConstraint.new(@base, columns, options)
    end

    def column_with_constraints(name, type, *args) #:nodoc:
      options = args.extract_options!
      check = options.delete(:check)
      references = options.delete(:references)
      unique = options.delete(:unique)
      primary_key = options.delete(:primary_key)
      column_without_constraints(name, type, options)

      if check
        check = if !check.is_a?(Array)
          [ check ]
        else
          check
        end

        table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLCheckConstraintCollection.new(@base, check)
      end

      if references
        ref_table, ref_options = if references.is_a?(Hash)
          [ references.delete(:table), references ]
        else
          [ references, {} ]
        end

        table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLForeignKeyConstraint.new(
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
        table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLUniqueConstraint.new(@base, name, unique)
      end

      if primary_key && type != :primary_key
        unless primary_key.is_a?(Hash)
          primary_key = {}
        end
        table_constraints << ActiveRecord::PostgreSQLExtensions::PostgreSQLPrimaryKeyConstraint.new(@base, name, primary_key)
      end

      self
    end

    # Add an INDEX to the table. This INDEX will be added during post
    # processing after the table has been created. See
    # PostgreSQLIndexDefinition for more details.
    def index(name, columns, options = {})
      post_processing << ActiveRecord::PostgreSQLExtensions::PostgreSQLIndexDefinition.new(@base, name, self.table_name, columns, options)
    end

    # Add statements to execute to after a table has been created.
    def post_processing
      @post_processing ||= []
    end

    def table_constraints
      @table_constraints ||= []
    end
  end
end

