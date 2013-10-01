
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates a new PostgreSQL text search configuration. You must provide
      # either a parser_name or a source_config option as per the PostgreSQL
      # text search docs.
      def create_extension(name, options = {})
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:extensions)

        sql = "CREATE EXTENSION "
        sql << "IF NOT EXISTS " if options[:if_not_exists]
        sql << quote_generic(name)
        sql << " SCHEMA #{quote_generic(options[:schema])}" if options[:schema]
        sql << " VERSION #{quote_generic(options[:version])}" if options[:version]
        sql << " FROM #{quote_generic(options[:old_version])}" if options[:old_version]

        execute("#{sql};")
      end

      # ==== Options
      #
      # * <tt>if_exists</tt> - adds IF EXISTS.
      # * <tt>cascade</tt> - adds CASCADE.
      def drop_extension(*args)
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:extensions)

        options = args.extract_options!

        sql = 'DROP EXTENSION '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << Array.wrap(args).collect { |name| quote_generic(name) }.join(', ')
        sql << ' CASCADE' if options[:cascade]

        execute("#{sql};")
      end

      def update_extension(name, new_version = nil)
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:extensions)

        sql = "ALTER EXTENSION #{quote_generic(name)} UPDATE"
        sql << " TO #{quote_generic(new_version)}" if new_version;
        execute("#{sql};")
      end

      def alter_extension_schema(name, schema)
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:extensions)

        execute "ALTER EXTENSION #{quote_generic(name)} SET SCHEMA #{quote_schema(schema)};"
      end

      # Alters an extension. Can be used with an options Hash or in a bloack.
      # For instance, all of the following examples should produce the
      # same output.
      #
      #   # with options Hash
      #   alter_extension(:foo, :collation => 'en_CA.UTF-8')
      #   alter_extension(:foo, :add_collation => 'en_CA.UTF-8')
      #
      #   # block mode
      #   alter_extension(:foo) do |e|
      #     e.collation 'en_CA.UTF-8'
      #   end
      #
      #   alter_extension(:foo) do |e|
      #     e.add_collation 'en_CA.UTF-8'
      #   end
      #
      #   # All produce
      #   #
      #   # ALTER EXTENSION "foo" ADD COLLATION "en_CA.UTF-8";
      #
      # Three versions of each option are available:
      #
      # * add_OPTION;
      # * drop_OPTION; and
      # * OPTION, which is equiavlent to add_OPTION.
      #
      # See the PostgreSQL docs for a list of all of the available extension
      # options.
      #
      # ==== Per-Option, uh... Options
      #
      # <tt>:cast</tt>, <tt>:operator</tt>, <tt>:operator_class</tt> and
      # <tt>:operator_family</tt> can be set their options as a Hash like so:
      #
      #   # With the options Hash being the actual values:
      #   alter_extension(:foo, :cast => { :hello => :world })
      #
      #   # With the options Hash containing key-values:
      #   alter_extension(:foo, :cast => {
      #     :source => :hello,
      #     :target => :world
      #   })
      #
      #   # Or with an Array thusly:
      #   alter_extension(:foo, :cast => [ :source_type, :target_type ])
      #
      #   # Or with arguments like this here:
      #   alter_extension(:foo) do |e|
      #     e.cast :source_type, :target_type
      #   end
      #
      # The options themselves even have options! It's options all the way
      # down!
      #
      # * <tt>:aggregate</tt> - <tt>:name</tt> and <tt>:types</tt>.
      #
      # * <tt>:cast</tt> - <tt>:source</tt> and <tt>:target</tt>.
      #
      # * <tt>:function</tt> - <tt>:name</tt> and <tt>:arguments</tt>. The
      #   <tt>:arguments</tt> option is just a straight up String like in
      #   the other function manipulation methods.
      #
      # * <tt>:operator</tt> - <tt>:name</tt>, <tt>:left_type</tt> and
      #   <tt>:right_type</tt>.
      #
      # * <tt>:operator_class</tt> and <tt>:operator_family</tt> - <tt>:name</tt>
      #   and <tt>:indexing_method</tt>.
      def alter_extension(name, options = {})
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:extensions)

        alterer = PostgreSQLExtensionAlterer.new(self, name, options)

        if block_given?
          yield alterer
        end

        execute(alterer.to_s) unless alterer.empty?
      end
    end

    class PostgreSQLExtensionAlterer
      def initialize(base, name, options = {}) #:nodoc:
        ActiveRecord::PostgreSQLExtensions::Features.check_feature(:extensions)

        @base, @name, @options = base, name, options
        @sql = options.collect { |k, v| build_statement(k, v) }
      end

      def empty? #:nodoc:
        @sql.empty?
      end

      def to_sql #:nodoc:
        "#{@sql.join(";\n")};"
      end
      alias :to_s :to_sql

      %w{
        aggregate cast collation conversion domain foreign_data_wrapper
        foreign_table function operator operator_class operator_family
        language schema sequence server table
        text_search_configuration text_search_dictionary text_search_parser text_search_template
        type view
      }.each do |f|
        self.class_eval(<<-EOF, __FILE__, __LINE__ + 1)
          def add_#{f}(*args)
            @sql << build_statement(:add_#{f}, *args)
          end
          alias :#{f} :add_#{f}

          def drop_#{f}(*args)
            @sql << build_statement(:drop_#{f}, *args)
          end
        EOF
      end

      private
        ACTIONS = %w{ add drop }.freeze

        def build_statement(k, *args) #:nodoc:
          option = k.to_s

          if option =~ /^(add|drop)_/
            action = $1
            option = option.gsub(/^(add|drop)_/, '')
          else
            action = :add
          end

          assert_valid_action(action)

          sql = "ALTER EXTENSION #{@base.quote_generic(@name || name)} #{action.to_s.upcase} "
          sql << case option
            when 'aggregate'
              name, types = case v = args[0]
                when Hash
                  v.values_at(:name, :types)
                else
                  [ args.shift, args ]
              end

              "AGGREGATE %s (%s)" % [
                @base.quote_generic(name),
                Array.wrap(types).collect { |t|
                  @base.quote_generic(t)
                }.join(', ')
              ]

            when 'cast'
              source, target = extract_hash_or_array_options(args, :source, :target)

              "CAST (#{@base.quote_generic(source)} AS #{@base.quote_generic(target)})"
            when *%w{ collation conversion domain foreign_data_wrapper
              foreign_table language schema sequence server table
              text_search_configuration text_search_dictionary text_search_parser
              text_search_template type view }

              "#{option.upcase.gsub('_', ' ')} #{@base.quote_generic(args[0])}"
            when 'function'
              name, arguments = case v = args[0]
                when Hash
                  v.values_at(:name, :arguments)
                else
                  args.flatten!
                  [ args.shift, *args ]
              end

              "FUNCTION #{@base.quote_function(name)}(#{Array.wrap(arguments).join(', ')})"
            when 'operator'
              name, left_type, right_type =
                extract_hash_or_array_options(args, :name, :left_type, :right_type)

              "OPERATOR #{@base.quote_generic(name)} (#{@base.quote_generic(left_type)}, #{@base.quote_generic(right_type)})"
            when 'operator_class', 'operator_family'
              object_name, indexing_method =
                extract_hash_or_array_options(args, :name, :indexing_method)

              "#{option.upcase.gsub('_', ' ')} #{@base.quote_generic(object_name)} USING #{@base.quote_generic(indexing_method)})"

            else
              raise ArgumentError.new("Unknown operation #{option}")
          end
          sql
        end

        def assert_valid_action(option) #:nodoc:
          if !ACTIONS.include?(option.to_s.downcase)
            raise ArgumentError.new("Excepted :add or :drop for PostgreSQLExtensionAlterer action.")
          end unless option.nil?
        end

        def extract_hash_or_array_options(hash_or_array, *keys) #:nodoc:
          case v = hash_or_array[0]
            when Hash
              if (keys - (sliced = v.slice(*keys)).keys).length == 0
                keys.collect do |k|
                  sliced[k]
                end
              else
                [ v.keys.first, v.values.first ]
              end
            else
              v = hash_or_array.flatten
              [ v.shift, *v ]
          end
        end
    end
  end
end
