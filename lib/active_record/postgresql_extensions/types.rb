
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      # Returns an Array of available languages.
      def types(name = nil)
        query(%{SELECT typname FROM pg_type;}, name).map { |row| row[0] }
      end

      def type_exists?(name)
        types.include?(name.to_s)
      end
    end
  end
end
