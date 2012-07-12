
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      # Creates a new PostgreSQL text search configuration. You must provide
      # either a :parser_name or a :source_config option as per the PostgreSQL
      # text search docs.
      def create_text_search_configuration(name, options = {})
        if options[:parser_name] && options[:source_config]
          raise ArgumentError.new("You can't define both :parser_name and :source_config options.")
        elsif options[:parser_name].blank? && options[:source_config].blank?
          raise ArgumentError.new("You must provide either a :parser_name or a :source_config.")
        end

        sql = "CREATE TEXT SEARCH CONFIGURATION #{quote_generic_with_schema(name)} ("

        ignore_schema do
          sql << if options[:parser_name]
            "PARSER = #{quote_generic_with_schema(options[:parser_name])}"
          else
            "COPY = #{quote_generic_with_schema(options[:source_config])}"
          end
        end

        sql << ")"
        execute("#{sql};")
      end

      def add_text_search_configuration_mapping(name, tokens, dictionaries)
        add_or_alter_text_search_configuration_mapping(name, tokens, dictionaries, :action => :add)
      end

      def alter_text_search_configuration_mapping(name, tokens, dictionaries)
        add_or_alter_text_search_configuration_mapping(name, tokens, dictionaries, :action => :alter)
      end

      # This method is semi-private and should only really be used via
      # add_text_search_configuration_mapping and alter_text_search_configuration_mapping.
      #
      # ==== Options
      #
      # * <tt>:action</tt> - either :add or :alter.
      def add_or_alter_text_search_configuration_mapping(name, tokens, dictionaries, options = {})
        options = {
          :action => :add
        }.merge(options)

        if ![ :add, :alter ].include?(options[:action])
          raise ArgumentError.new(":action option must be eithe :add or :alter.")
        end

        add_or_alter = options[:action].to_s.upcase

        sql = "ALTER TEXT SEARCH CONFIGURATION #{quote_generic_with_schema(name)} #{add_or_alter} MAPPING FOR "
        sql << Array(tokens).collect { |token|
          quote_generic(token)
        }.join(', ')

        sql << ' WITH '

        sql << Array(dictionaries).collect { |dictionary|
          quote_generic(dictionary)
        }.join(', ')

        execute("#{sql};")
      end

      def replace_text_search_configuration_dictionary(name, old_dictionary, new_dictionary)
        sql = "ALTER TEXT SEARCH CONFIGURATION #{quote_generic_with_schema(name)} ALTER MAPPING REPLACE "
        sql << "#{quote_generic(old_dictionary)} WITH #{quote_generic(new_dictionary)}"

        execute("#{sql};")
      end

      def alter_text_search_configuration_mapping_replace_dictionary(name, mappings, old_dictionary, new_dictionary)
        if mappings.blank?
          raise ArgumentError.new("Expected one or more mappings to alter.")
        end

        sql = "ALTER TEXT SEARCH CONFIGURATION #{quote_generic_with_schema(name)} ALTER MAPPING FOR "
        sql << Array(mappings).collect { |token_type|
          quote_generic(token_type)
        }.join(', ')
        sql << " REPLACE #{quote_generic(old_dictionary)} WITH #{quote_generic(new_dictionary)}"

        execute("#{sql};")
      end

      def drop_text_search_configuration_mapping(name, *args)
        options = args.extract_options!
        mappings = args

        if mappings.blank?
          raise ArgumentError.new("Expected one or more mappings to drop.")
        end

        sql = "ALTER TEXT SEARCH CONFIGURATION #{quote_generic_with_schema(name)} DROP MAPPING "

        if options[:if_exists]
          sql << 'IF EXISTS '
        end

        sql << 'FOR '
        sql << mappings.collect { |token_type|
          quote_generic(token_type)
        }.join(', ')

        execute("#{sql};")
      end

      def rename_text_search_configuration(old_name, new_name)
        execute("ALTER TEXT SEARCH CONFIGURATION %s RENAME TO %s;" % [
          quote_generic_with_schema(old_name),
          quote_generic_with_schema(new_name)
        ])
      end

      def alter_text_search_configuration_owner(name, role)
        execute "ALTER TEXT SEARCH CONFIGURATION #{quote_generic_with_schema(name)} OWNER TO #{quote_role(role)};"
      end

      def alter_text_search_configuration_schema(name, schema)
        execute "ALTER TEXT SEARCH CONFIGURATION #{quote_generic_with_schema(name)} SET SCHEMA #{quote_schema(schema)};"
      end

      # Drops a text search configuration.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_text_search_configuration(name, options = {})
        sql = 'DROP TEXT SEARCH CONFIGURATION '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << quote_generic_with_schema(name)
        sql << ' CASCADE' if options[:cascade]

        execute("#{sql};")
      end

      def create_text_search_dictionary(name, template, options = {})
        sql = "CREATE TEXT SEARCH DICTIONARY #{quote_generic_with_schema(name)} ("
        sql << "TEMPLATE = #{quote_generic_with_schema(template)}"

        if !options.blank?
          sql << ', '
          sql << options.collect { |k, v|
            "#{quote_generic(k)} = #{quote(v)}"
          }.join(', ')
        end

        sql << ')'

        execute("#{sql};")
      end

      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_text_search_dictionary(name, options = {})
        sql = 'DROP TEXT SEARCH DICTIONARY '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << quote_generic_with_schema(name)
        sql << ' CASCADE' if options[:cascade]

        execute("#{sql};")
      end

      def alter_text_search_dictionary(name, options)
        if options.blank?
          raise ArgumentError.new("Expected some options to alter.")
        end

        sql = "ALTER TEXT SEARCH DICTIONARY #{quote_generic_with_schema} ("
        sql << options.collect { |k, v|
          "#{quote_generic(k)} = #{quote(v)}"
        }.join(', ')
        sql << ')'

        execute("#{sql};")
      end

      def rename_text_search_dictionary(old_name, new_name)
        execute("ALTER TEXT SEARCH DICTIONARY %s RENAME TO %s;" % [
          quote_generic_with_schema(old_name),
          quote_generic_with_schema(new_name)
        ])
      end

      def alter_text_search_dictionary_owner(name, role)
        execute "ALTER TEXT SEARCH DICTIONARY #{quote_generic_with_schema(name)} OWNER TO #{quote_role(role)};"
      end

      def alter_text_search_dictionary_schema(name, schema)
        execute "ALTER TEXT SEARCH DICTIONARY #{quote_generic_with_schema(name)} SET SCHEMA #{quote_schema(schema)};"
      end


      # ==== Options
      #
      # :lexize - the function used by the template lexer. Required.
      # :init - the initialization function for the template. Optional.
      def create_text_search_template(name, options = {})
        if options[:lexize].blank?
          raise ArgumentError.new("Expected to see a :lexize option.")
        end

        sql = "CREATE TEXT SEARCH TEMPLATE #{quote_generic_with_schema(name)} ("

        if options[:init]
          sql << "INIT = #{quote_function(options[:init])}, "
        end

        sql << "LEXIZE = #{quote_function(options[:lexize])}"
        sql << ')'

        execute("#{sql};")
      end

      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_text_search_template(name, options = {})
        sql = 'DROP TEXT SEARCH TEMPLATE '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << quote_generic_with_schema(name)
        sql << ' CASCADE' if options[:cascade]

        execute("#{sql};")
      end

      def rename_text_search_template(old_name, new_name)
        execute("ALTER TEXT SEARCH TEMPLATE %s RENAME TO %s;" % [
          quote_generic_with_schema(old_name),
          quote_generic_with_schema(new_name)
        ])
      end

      def alter_text_search_template_schema(name, schema)
        execute "ALTER TEXT SEARCH TEMPLATE #{quote_generic_with_schema(name)} SET SCHEMA #{quote_schema(schema)};"
      end



      # The :start, :gettoken, :end and :lextypes options are required as per
      # the PostgreSQL docs, while the :headline option is optional.
      def create_text_search_parser(name, options = {})
        if (missing_options = [ :start, :gettoken, :end, :lextypes ] - options.keys).present?
          raise ArgumentError.new("Missing options: #{missing_options}.")
        end

        sql = "CREATE TEXT SEARCH PARSER #{quote_generic_with_schema(name)} ("
        sql << "START = #{quote_function(options[:start])}, "
        sql << "GETTOKEN = #{quote_function(options[:gettoken])}, "
        sql << "END = #{quote_function(options[:end])}, "
        sql << "LEXTYPES = #{quote_function(options[:lextypes])}"

        if options[:headline]
          sql << ", HEADLINE = #{quote_function(options[:headline])}"
        end

        sql << ')'

        execute("#{sql};")
      end

      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_text_search_parser(name, options = {})
        sql = 'DROP TEXT SEARCH PARSER '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << quote_generic_with_schema(name)
        sql << ' CASCADE' if options[:cascade]

        execute("#{sql};")
      end

      def rename_text_search_parser(old_name, new_name)
        execute("ALTER TEXT SEARCH PARSER %s RENAME TO %s;" % [
          quote_generic_with_schema(old_name),
          quote_generic_with_schema(new_name)
        ])
      end

      def alter_text_search_parser_schema(name, schema)
        execute "ALTER TEXT SEARCH PARSER #{quote_generic_with_schema(name)} SET SCHEMA #{quote_schema(schema)};"
      end

      private
        def extract_hash_or_array_options(hash_or_array, *keys)
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
