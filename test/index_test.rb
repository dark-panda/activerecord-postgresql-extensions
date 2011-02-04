
$: << File.dirname(__FILE__)
require 'test_helper'

class IndexTests < Test::Unit::TestCase
	include PostgreSQLExtensionsTestHelper

	def test_create_index
		Mig.create_index(:foo_names_idx, :foo, [ :first_name, :last_name ])
		Mig.create_index(:foo_bar_id_idx, :foo, :column => :bar_id)
		Mig.create_index(:foo_coalesce_bar_id_idx, :foo, :expression => 'COALESCE(bar_id, 0)')
		Mig.create_index(:foo_search_idx, :foo, :search, :using => :gin)

		Mig.create_index(:foo_names_idx, :foo, {
			:column => :name,
			:opclass => 'text_pattern_ops'
		})

		Mig.create_index(:foo_bar_id_idx, :foo, {
			:column => :bar_id,
			:order => :asc,
			:nulls => :last
		}, {
			:fill_factor => 10,
			:unique => true,
			:concurrently => true,
			:tablespace => 'fubar',
			:conditions => 'bar_id IS NOT NULL'
		})

		assert_equal([
			"CREATE INDEX \"foo_names_idx\" ON \"foo\"(\"first_name\", \"last_name\")",
			"CREATE INDEX \"foo_bar_id_idx\" ON \"foo\"(\"bar_id\")",
			"CREATE INDEX \"foo_coalesce_bar_id_idx\" ON \"foo\"((COALESCE(bar_id, 0)))",
			"CREATE INDEX \"foo_search_idx\" ON \"foo\" USING \"gin\"(\"search\")",
			"CREATE INDEX \"foo_names_idx\" ON \"foo\"(\"name\" \"text_pattern_ops\")",
			"CREATE UNIQUE INDEX CONCURRENTLY \"foo_bar_id_idx\" ON \"foo\"(\"bar_id\" ASC NULLS LAST) WITH (FILLFACTOR = 10) TABLESPACE \"fubar\" WHERE bar_id IS NOT NULL"
		], statements)
	end

	def test_drop_index
		Mig.drop_index(:foo_names_idx)
		Mig.drop_index(:foo_names_idx, :if_exists => true)
		Mig.drop_index(:foo_names_idx, :cascade => true)

		assert_equal([
			"DROP INDEX \"foo_names_idx\"",
			"DROP INDEX IF EXISTS \"foo_names_idx\"",
			"DROP INDEX \"foo_names_idx\" CASCADE"
		], statements)
	end

	def test_rename_index
		Mig.rename_index(:foo_names_idx, :foo_renamed_idx)

		assert_equal([
			"ALTER INDEX \"foo_names_idx\" RENAME TO \"foo_renamed_idx\""
		], statements)
	end

	def test_alter_index_tablespace
		Mig.alter_index_tablespace(:foo_names_idx, :fubar)

		assert_equal([
			"ALTER INDEX \"foo_names_idx\" SET TABLESPACE \"fubar\""
		], statements)
	end
end
