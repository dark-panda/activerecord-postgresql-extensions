
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidIndexColumnDefinition < ActiveRecordError #:nodoc:
    def initialize(msg, column)
      super("#{msg} - #{column.inspect}")
    end
  end

  class InvalidIndexFillFactory < ActiveRecordError #:nodoc:
    def initialize(fill_factor)
      super("Invalid index fill factor - #{fill_factor}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates an index. This method is an alternative to the standard
      # ActiveRecord add_index method and includes PostgreSQL-specific
      # options. Indexes can be created on tables as well as materialized views
      # starting with PostgreSQL 9.3.
      #
      # === Differences to add_index
      #
      # * With the standard ActiveRecord add_index method, ActiveRecord
      #   will automatically generate an index name. With create_index,
      #   you need to supply a name yourself. This is due to the fact
      #   that PostgreSQL's indexes can include things like expressions
      #   and special index types, so we're not going to try and parse
      #   your expressions for you. You'll have to supply your own
      #   index name.
      # * Several PostgreSQL-specific options are included. See below
      #   for details.
      # * The +columns+ argument supports Hashes to allow for
      #   expressions. See examples below.
      #
      # ==== Options
      #
      # * <tt>:unique</tt> - adds UNIQUE to the index definition.
      # * <tt>:concurrently</tt> - adds CONCURRENTLY to the index
      #   definition. See the PostgreSQL documentation for a discussion
      #   on concurrently reindexing tables.
      # * <tt>:using</tt> - the indexing method to use. PostgreSQL
      #   supports serveral indexing methods out of the box, the default
      #   being a binary tree method. For certain column types,
      #   alternative indexing methods produce better indexing results.
      #   In some cases, a btree index would be pointless given certain
      #   datatypes and queries. For instance, PostGIS' geometry
      #   datatypes should generally be indexed with GiST indexes, while
      #   the tsvector full text search datatype should generally be
      #   indexed with a GiN index. See the PostgreSQL documentation
      #   for details.
      # * <tt>:fill_factor</tt> - sets the FILLFACTOR value for the
      #   index. This option tells PostgreSQL how to pack its index
      #   pages on disk. As indexes grow, they begin to get spread out
      #   over multiple disk pages, thus reducing efficiency. This option
      #   allows you to control some of that behaviour. The default
      #   value for btree indexes is 90, and any value from 10 to
      #   100 can be used. See the PostgreSQL documentation for more
      #   details.
      # * <tt>:tablespace</tt> - sets the tablespace for the index.
      # * <tt>:conditions</tt> - adds an optional WHERE clause to the
      #   index. (You can alternatively use the option <tt>:where</tt>
      #   instead.)
      # * <tt>:index_parameters</tt> - a simple String or Hash used to
      #   assign index storage parameters. See the PostgreSQL docs for
      #   details on the various storage parameters available.
      #
      # ==== Column Options
      #
      # You can specify a handful of options on each index
      # column/expression definition by supplying a Hash for the
      # definition rather than a Symbol/String.
      #
      # * <tt>:column</tt> or <tt>:expression</tt> - you can specify
      #   either <tt>:column</tt> or <tt>:expression</tt> in the column
      #   definition, but not both. When using <tt>:column</tt>, the
      #   column name is quoted properly using PostgreSQL's quoting
      #   rules, while using <tt>:expression</tt> leaves you on your
      #   own.
      # * <tt>:opclass</tt> - an "opclass" (a.k.a. "operator class")
      #   provides hints to the PostgreSQL query planner that allow it
      #   to more effectively take advantage of indexes. An opclass
      #   effectively tells the planner what operators can be used by an
      #   index when searching a column or expression. When creating
      #   an index, PostgreSQL generally uses an opclass equivalent to
      #   the column datatype (i.e. +int4_ops+ for an integer column).
      #   You can override this behaviour when necessary. For instance,
      #   in queries involving the LIKE operator on a text column,
      #   PostgreSQL will usually only take advantage of an index if the
      #   database has been created in the C locale. You can override
      #   this behaviour by forcing the index to be created using the
      #   +text_pattern_ops+ opclass
      # * <tt>:order</tt> - the order to index the column in. This can
      #   be one of <tt>:asc</tt> or <tt>:desc</tt>.
      # * <tt>:nulls</tt> - specify whether NULL values should be placed
      #   <tt>:first</tt> or <tt>:last</tt> in the index.
      #
      # ==== Examples
      #
      #   # using multiple columns
      #   create_index('this_is_my_index', :foo, [ :id, :ref_id ], :using => :gin)
      #   # => CREATE INDEX "this_is_my_index" ON "foo"("id", "ref_id");
      #
      #   # using expressions
      #   create_index('this_is_another_idx', :foo, { :expression => 'COALESCE(ref_id, 0)' })
      #   # => CREATE INDEX "this_is_another_idx" ON "foo"((COALESCE(ref_id, 0)));
      #
      #   # additional options
      #   create_index('search_idx', :foo, :tsvector, :using => :gin)
      #   # => CREATE INDEX "search_idx" ON "foo" USING "gin"("tsvector");
      def create_index(name, object, columns, options = {})
        execute ActiveRecord::PostgreSQLExtensions::PostgreSQLIndexDefinition.new(self, name, object, columns, options).to_s
      end

      # PostgreSQL-specific version of the standard ActiveRecord
      # remove_index method.
      #
      # Unlike remove_index, you'll have to specify an actual index
      # name with drop_index. See create_index for the particulars on
      # why.
      #
      # You can specify multiple INDEXes with an Array when using drop_index,
      # but you may need to use the method directly through the ActiveRecord
      # connection rather than the Migration method, as the Migration method
      # likes to escape the Array to a String.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      # * <tt>:concurrently</tt> - adds the CONCURRENTLY option when dropping
      #   the INDEX. When using the :concurrently option, only one INDEX can
      #   specified and the :cascade option cannot be used. See the PostgreSQL
      #   documentation for details.
      def drop_index(*args)
        options = args.extract_options!
        args.flatten!

        if options[:concurrently] && options[:cascade]
          raise ArgumentError.new("The :concurrently and :cascade options cannot be used together.")
        elsif options[:concurrently] && args.length > 1
          raise ArgumentError.new("The :concurrently option can only be used on a single INDEX.")
        end

        sql = 'DROP INDEX '
        sql << 'CONCURRENTLY ' if options[:concurrently]
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array.wrap(args).collect { |i| quote_generic(i) }.join(', ')
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Renames an index.
      def rename_index(name, new_name, options = {})
        execute "ALTER INDEX #{quote_generic(name)} RENAME TO #{quote_generic(new_name)};"
      end

      # Changes an index's tablespace.
      def alter_index_tablespace(name, tablespace, options = {})
        execute "ALTER INDEX #{quote_generic(name)} SET TABLESPACE #{quote_tablespace(tablespace)};"
      end
    end
  end

  module PostgreSQLExtensions
    # Creates a PostgreSQL index definition. This class isn't really meant
    # to be used directly. Instead, see PostgreSQLAdapter#create_index
    # for usage.
    class PostgreSQLIndexDefinition
      attr_accessor :base, :name, :object, :columns, :options

      def initialize(base, name, object, columns, options = {}) #:nodoc:
        assert_valid_columns(columns)
        assert_valid_fill_factor(options[:fill_factor])

        @base, @name, @object, @columns, @options = base, name, object, columns, options
      end

      def to_sql #:nodoc:
        sql = 'CREATE '
        sql << 'UNIQUE ' if options[:unique]
        sql << 'INDEX '
        sql << 'CONCURRENTLY ' if options[:concurrently]
        sql << "#{base.quote_generic(name)} ON #{base.quote_table_name(object)}"
        sql << " USING #{base.quote_generic(options[:using])}" if options[:using]
        sql << '('
        sql << [ columns ].flatten.collect do |column|
          column_def = String.new
          if column.is_a?(Hash)
            column_def << if column[:column]
              "#{base.quote_column_name(column[:column])}"
            else
              "(#{column[:expression]})"
            end

            column_def << " #{base.quote_generic(column[:opclass])}" if column[:opclass]
            column_def << " #{column[:order].to_s.upcase}" if column[:order]
            column_def << " NULLS #{column[:nulls].to_s.upcase}" if column[:nulls]
            column_def
          else
            base.quote_column_name(column.to_s)
          end
        end.join(', ')
        sql << ')'
        sql << " WITH (FILLFACTOR = #{options[:fill_factor].to_i})" if options[:fill_factor]
        sql << " WITH (#{ActiveRecord::PostgreSQLExtensions::Utils.options_from_hash_or_string(options[:index_parameters], base)})" if options[:index_parameters].present?
        sql << " TABLESPACE #{base.quote_tablespace(options[:tablespace])}" if options[:tablespace]
        sql << " WHERE (#{options[:conditions] || options[:where]})" if options[:conditions] || options[:where]
        "#{sql};"
      end
      alias :to_s :to_sql

      private
        def assert_valid_columns(columns) #:nodoc:
          Array.wrap(columns).each do |column|
            if column.is_a?(Hash)
              if column.has_key?(:column) && column.has_key?(:expression)
                raise ActiveRecord::InvalidIndexColumnDefinition.new("You can't specify both :column and :expression in a column definition", column)
              elsif !(column.has_key?(:column) || column.has_key?(:expression))
                raise ActiveRecord::InvalidIndexColumnDefinition.new("You must specify either :column or :expression in a column definition", column)
              end

              if ![ 'asc', 'desc' ].include?(column[:order].to_s.downcase)
                raise ActiveRecord::InvalidIndexColumnDefinition.new("Invalid :order value", column)
              end if column[:order]

              if ![ 'first', 'last' ].include?(column[:nulls].to_s.downcase)
                raise ActiveRecord::InvalidIndexColumnDefinition.new("Invalid :nulls value", column)
              end if column[:nulls]
            end
          end
        end

        def assert_valid_fill_factor(fill_factor) #:nodoc:
          if !fill_factor.nil?
            ff = fill_factor.to_i
            if ff < 0 || ff > 100
              raise ActiveRecord::InvalidIndexFillFactor.new(fill_factor)
            end
          end
        end
    end
  end
end
