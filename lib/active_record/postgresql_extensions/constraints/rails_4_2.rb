module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      def add_foreign_key_constraint(table, ref_table, columns, *args)
        sql = "ALTER TABLE #{quote_table_name(table)} ADD "
        sql << ActiveRecord::PostgreSQLExtensions::PostgreSQLForeignKeyConstraint.new(self, columns, ref_table, *args).to_s
        execute("#{sql};")
      end
      alias :add_foreign_key :add_foreign_key_constraint
    end
  end
end
