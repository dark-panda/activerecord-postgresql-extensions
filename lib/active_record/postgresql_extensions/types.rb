
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      # Returns an Array of available languages.
      def types(name = nil)
        query(PostgreSQLExtensions::Utils.strip_heredoc(<<-SQL), name).map(&:first)
          SELECT t.typname as type
            FROM pg_type t
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
            WHERE (t.typrelid = 0 OR (
              SELECT c.relkind = 'c'
                FROM pg_catalog.pg_class c
                WHERE c.oid = t.typrelid
            )) AND
              NOT EXISTS(
                SELECT 1
                  FROM pg_catalog.pg_type el
                  WHERE el.oid = t.typelem
                    AND el.typarray = t.oid
              ) AND
              n.nspname NOT IN ('information_schema');
        SQL
      end

      def type_exists?(name)
        types.include?(name.to_s)
      end
    end
  end
end
