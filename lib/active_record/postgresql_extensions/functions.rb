
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidFunctionBehavior < ActiveRecordError #:nodoc:
    def initialize(behavior)
      super("Invalid function behavior - #{behavior}")
    end
  end

  class InvalidFunctionOnNullInputValue < ActiveRecordError #:nodoc:
    def initialize(option)
      super("Invalid function ON NULL INPUT behavior - #{option}")
    end
  end

  class InvalidFunctionSecurityValue < ActiveRecordError #:nodoc:
    def initialize(option)
      super("Invalid function SECURITY value - #{option}")
    end
  end

  class InvalidFunctionAction < ActiveRecordError #:nodoc:
    def initialize(option)
      super("Invalid function SECURITY value - #{option}")
    end
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates a PostgreSQL function/stored procedure.
      #
      # +args+ is a simple String that you can use to represent the
      # function arguments.
      #
      # +returns+ is the return type for the function.
      #
      # +language+ is the procedural language the function is written
      # in. The possible values for this argument will depend on your
      # database set up. See create_language for details on adding
      # new languages to your database.
      #
      # +body+ is the actual function body. When the function language is
      # C, this will be an Array containing two items: the object file
      # the function is found in and the link symbol for the function.
      # In all other cases, this argument will be a String containing
      # the actual function code.
      #
      # ==== Options
      #
      # * <tt>:force</tt> - add an <tt>OR REPLACE</tt> clause to the
      #   statement, thus overwriting any existing function definition
      #   of the same name and arguments.
      # * <tt>:behavior</tt> - one of <tt>:immutable</tt>,
      #   <tt>:stable</tt> or <tt>:volatile</tt>. This option helps
      #   the server when making planning estimates when the function
      #   is called. The default is <tt>:volatile</tt>.
      # * <tt>:on_null_inputs</tt> - one of <tt>:called</tt>,
      #   <tt>:returns</tt> or <tt>:strict</tt>. This indicates to the
      #   server how the function should be called when it receives
      #   NULL inputs. When <tt>:called</tt> is used, the function is
      #   executed even when one or more of its arguments is NULL.
      #   For <tt>:returns</tt> and <tt>:strict</tt> (which are actually
      #   just aliases), function execution is skipped and NULL is
      #   returned immediately.
      # * <tt>:security</tt> - one of <tt>:invoker</tt> or
      #   <tt>:definer</tt>. This option determines what privileges the
      #   function should used when called. The values are pretty
      #   self explanatory. The default is <tt>:invoker</tt>.
      # * <tt>:delimiter</tt> - the delimiter to use for the function
      #   body. The default is '$$'.
      # * <tt>:cost</tt> - a number that determines the approximate
      #   overhead the server can expect when calling this function. This
      #   is used when calculating execution costs in the planner.
      # * <tt>:rows</tt> - a number indicating the estimated number
      #   of rows the function will return. This is used when
      #   calculating execution costs in the planner and only affects
      #   functions that return result sets.
      # * <tt>:set</tt> - allows you to set parameters temporarily
      #   during function execution. This would include things like
      #   +search_path+ or <tt>time zone</tt> and such. This option
      #   can either be a String with the set fragment or a Hash
      #   with the parameters as keys and the values to set as values.
      #   When using a Hash, the value <tt>:from_current</tt> can be
      #   used to specify the actual <tt>FROM CURRENT</tt> clause.
      #
      # You should definitely check out the PostgreSQL documentation
      # on creating stored procedures, because it can get pretty
      # convoluted as evidenced by the plethora of options we're
      # handling here.
      #
      # ==== Example
      #
      #   create_function('tester_function', 'integer',
      #     'integer', 'sql', :behavior => :immutable, :set => { :search_path => :from_current }, :force => true) do
      #     "select $1;"
      #   end
      #
      #   # Produces:
      #   #
      #   # CREATE OR REPLACE FUNCTION "tester_function"(integer) RETURNS integer AS $$
      #   #   select $1;
      #   # $$
      #   # LANGUAGE "sql"
      #   #   IMMUTABLE
      #   #   SET "search_path" FROM CURRENT;
      def create_function(name, args, returns, language, options = {})
        body = yield.to_s
        execute PostgreSQLFunctionDefinition.new(self, name, args, returns, language, body, options).to_s
      end

      # Drops a function.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds an <tt>IF EXISTS</tt> clause.
      # * <tt>:cascade</tt> - cascades the operation on to any objects
      #   referring to the function.
      def drop_function(name, args, options = {})
        sql = 'DROP FUNCTION '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << "#{quote_function(name)}(#{args})"
        sql << ' CASCADE' if options[:cascade]
        execute "#{sql};"
      end

      # Renames a function.
      def rename_function(name, args, rename_to, options = {})
        execute PostgreSQLFunctionAlterer.new(self, name, args, :rename_to => rename_to).to_s
      end

      # Changes the function's owner.
      def alter_function_owner(name, args, owner_to, options = {})
        execute PostgreSQLFunctionAlterer.new(self, name, args, :owner_to => owner_to).to_s
      end

      # Changes the function's schema.
      def alter_function_schema(name, args, set_schema, options = {})
        execute PostgreSQLFunctionAlterer.new(self, name, args, :set_schema => set_schema).to_s
      end

      # Alters a function. There's a ton of stuff you can do here, and
      # there's two ways to do it: with a block or with an options Hash.
      #
      # In both cases, you're going to be using the same options as
      # defined in <tt>create_function</tt> with the exception of
      # <tt>:force</tt> and <tt>:delimiter</tt> and with the addition
      # of <tt>:reset</tt>. The <tt>:reset</tt> option allows you
      # to reset the values of parameters used with <tt>:set</tt> either
      # on an individual basis using an Array or by using <tt>:all</tt>
      # to reset all of them.
      #
      # ==== Examples
      #
      # Both of the following examples should produce the same output.
      #
      #   # with options Hash
      #   alter_function('my_function', 'integer', :rename_to => 'another_function')
      #   alter_function('another_function', 'integer', :owner_to => 'jdoe')
      #
      #   # block mode
      #   alter_function('my_function', 'integer') do |f|
      #     f.rename_to 'another_function'
      #     f.owner_to 'jdoe'
      #   end
      #
      #   # Produces:
      #   #
      #   # ALTER FUNCTION "my_function"(integer) OWNER TO "jdoe";
      #   # ALTER FUNCTION "my_function"(integer) RENAME TO "another_function";
      def alter_function(name, args, options = {})
        alterer = PostgreSQLFunctionAlterer.new(self, name, args, options)

        if block_given?
          yield alterer
        end

        execute alterer.to_s unless alterer.empty?
      end
    end

    # This is a base class for our PostgreSQL function classes. You don't
    # want to be accessing this class directly.
    class PostgreSQLFunction
      attr_accessor :base, :name, :args, :options

      def initialize(base, name, args, options = {}) #:nodoc:
        @base, @name, @args, @options = base, name, args, options
      end

      private
        BEHAVIORS = %w{ immutable stable volatile }.freeze
        ON_NULL_INPUTS = %w{ called returns strict }.freeze
        SECURITIES = %w{ invoker definer }.freeze

        def assert_valid_behavior(option) #:nodoc:
          if !BEHAVIORS.include?(option.to_s.downcase)
            raise ActiveRecord::InvalidFunctionBehavior.new(option)
          end unless option.nil?
        end

        def assert_valid_on_null_input(option) #:nodoc:
          if !ON_NULL_INPUTS.include?(option.to_s.downcase)
            raise ActiveRecord::InvalidFunctionOnNullInputValue.new(option)
          end unless option.nil?
        end

        def assert_valid_security(option) #:nodoc:
          if !SECURITIES.include?(option.to_s.downcase)
            raise ActiveRecord::InvalidFunctionSecurityValue.new(option)
          end unless option.nil?
        end

        def set_options(opts) #:nodoc:
          sql = Array.new
          if opts.is_a?(Hash)
            opts.each do |k, v|
              set_me = if k.to_s.upcase == 'TIME ZONE'
                "SET TIME ZONE #{base.quote_generic(v)}"
              else
                "SET #{base.quote_generic(k)}" + if (v == :from_current)
                  " FROM CURRENT"
                else
                  " TO #{base.quote_generic(v)}"
                end
              end

              sql << set_me
            end
          else
            sql << Array.wrap(opts).collect do |s|
              "SET #{s.to_s}"
            end
          end
          sql
        end
    end

    # Creates a PostgreSQL function definition. You're generally going to
    # want to use the +create_function+ method instead of accessing this
    # class directly.
    class PostgreSQLFunctionDefinition < PostgreSQLFunction
      attr_accessor :language, :returns, :body

      def initialize(base, name, args, returns, language, body, options = {}) #:nodoc:
        assert_valid_behavior(options[:behavior])
        assert_valid_on_null_input(options[:on_null_input])
        assert_valid_security(options[:security])

        @language, @returns, @body = language, returns, body
        options = {
          :delimiter => '$$'
        }.merge options
        super(base, name, args, options)
      end

      def to_sql #:nodoc:
        sql = 'CREATE '
        sql << 'OR REPLACE ' if options[:force]
        sql << "FUNCTION #{base.quote_function(name)}(#{args}) RETURNS #{returns} AS "
        if language == 'C'
          "#{base.quote_function(body[0])}, #{base.quote_generic(body[1])}"
        else
          sql << "#{options[:delimiter]}\n#{body}\n#{options[:delimiter]}\n"
        end
        sql << "LANGUAGE #{base.quote_language(language)}\n"
        sql << "    #{options[:behavior].to_s.upcase}\n" if options[:behavior]
        sql << "    #{options[:on_null_input].to_s.upcase}\n" if options[:on_null_input]
        sql << "    COST #{options[:cost].to_i}\n" if options[:cost]
        sql << "    ROWS #{options[:rows].to_i}\n" if options[:rows]
        sql << "    " << (set_options(options[:set]) * "\n    ") if options[:set]
        "#{sql.strip};"
      end
      alias :to_s :to_sql
    end

    # Alters a function. You'll generally want to be calling the
    # PostgreSQLAdapter#alter_function method rather than risk messing
    # with this class directly. It's a finicky, delicate flower.
    class PostgreSQLFunctionAlterer < PostgreSQLFunction
      def initialize(base, name, args, options = {}) #:nodoc:
        super(base, name, args, options)

        @sql = options.collect { |k, v| build_statement(k, v) }
      end

      def empty? #:nodoc:
        @sql.empty?
      end

      def to_sql #:nodoc:
        "#{@sql.join(";\n")};"
      end
      alias :to_s :to_sql

      [ :rename_to, :owner_to, :set_schema, :behavior,
        :on_null_input, :security, :cost, :rows, :set,
        :reset
      ].each do |f|
        self.class_eval <<-EOF
          def #{f}(v)
            @sql << build_statement(:#{f}, v)
          end
        EOF
      end

      private
        def build_statement(k, v) #:nodoc:
          new_name = if defined?(@new_name) && @new_name
            @new_name
          else
            self.name
          end

          sql = "ALTER FUNCTION #{base.quote_function(new_name)}(#{args}) "
          sql << case k
            when :rename_to
              "RENAME TO #{base.quote_generic_ignore_scoped_schema(v)}".tap { @new_name = v }
            when :owner_to
              "OWNER TO #{base.quote_role(v)}"
            when :set_schema
              "SET SCHEMA #{base.quote_schema(v)}"
            when :behavior
              assert_valid_behavior(v)
              v.to_s.upcase
            when :on_null_input
              assert_valid_on_null_input(v)
              v.to_s.upcase
            when :security
              assert_valid_security(v)
              "SECURITY #{v.to_s.upcase}"
            when :cost
              "COST #{v.to_i}"
            when :rows
              "ROWS #{v.to_i}"
            when :set
              set_options(v) * "\n"
            when :reset
              if v.is_a?(Array)
                v.collect { |vv| "RESET #{base.quote_generic(vv)}" }.join(" ")
              elsif v == :all
                'RESET ALL'
              end
          end
          sql
        end
    end
  end
end
