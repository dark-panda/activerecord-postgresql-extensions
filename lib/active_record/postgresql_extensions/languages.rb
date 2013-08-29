
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      # Creates a PostgreSQL procedural language.
      #
      # Note that you can grant privileges on languages using the
      # grant_language_privileges method and revoke them using
      # revoke_language_privileges.
      #
      # ==== Options
      #
      # * <tt>:trusted</tt> - adds a TRUSTED clause. Trusted languages
      #   in PostgreSQL are given a couple of extra abilities that
      #   their untrusted counterparts lust for, such as the ability
      #   to touch the server's local file system. This can be rather
      #   important if you need to access external libraries in your
      #   language's functions, such as importing CPAN libraries in
      #   plperl. The default is untrusted.
      # * <tt>:handler</tt> - this option is used to point the server
      #   in the direction of the procedural language's hooks and such.
      #   It's generally not required now unless you for some reason
      #   need to access a langauge that isn't currently held in the
      #   <tt>pg_pltemplate</tt> system table.
      # * <tt>:validator</tt> - this option provides a previously
      #   declared test function that will be used to test the
      #   functionality of the newly-installed procedural language.
      #
      # You don't often see people using the <tt>:handler</tt> and
      # <tt>:validator</tt> options, and they're really just kind of
      # here for the sake of completeness.
      def create_language(language, options = {})
        sql = 'CREATE '
        sql << 'TRUSTED ' if options[:trusted]
        sql << "PROCEDURAL LANGUAGE #{quote_language(language)}"
        sql << " HANDLER #{quote_language(options[:call_handler])}" if options[:call_handler]
        sql << " VALIDATOR #{options[:validator]}" if options[:validator]
        execute("#{sql};")
      end

      # Drops a language.
      #
      # ==== Options
      #
      # * <tt>:if_exists</tt> - adds IF EXISTS.
      # * <tt>:cascade</tt> - adds CASCADE.
      def drop_language(language, options = {})
        sql = 'DROP PROCEDURAL LANGUAGE '
        sql << 'IF EXISTS ' if options[:if_exists]
        sql << quote_language(language)
        sql << ' CASCADE' if options[:cascade]
        execute("#{sql};")
      end

      # Renames a language.
      def alter_language_name(old_language, new_language, options = {})
        execute "ALTER PROCEDURAL LANGUAGE #{quote_language(old_language)} RENAME TO #{quote_language(new_language)};"
      end

      # Changes a language's owner.
      def alter_language_owner(language, role, options = {})
        execute "ALTER PROCEDURAL LANGUAGE #{quote_language(language)} OWNER TO #{quote_role(role)};"
      end

      # Returns an Array of available languages.
      def languages(name = nil)
        query(PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL), name).map { |row| row[0] }
          SELECT lanname
          FROM pg_language;
        SQL
      end

      def language_exists?(name)
        languages.include?(name.to_s)
      end
    end
  end
end
