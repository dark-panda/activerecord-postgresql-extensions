
require 'test/test_helper'

class TablesTests < Test::Unit::TestCase
	include PostgreSQLExtensionsTestHelper

	def test_foreign_key_in_column_definition
		Mig.create_table('foo') do |t|
			t.integer :foo_id, :references => {
				:table => :foo,
				:on_delete => :set_null,
				:on_update => :cascade
			}

			t.integer :bar_id, :references => :bar

			t.integer :baz_id, :references => [ :baz ]

			t.foreign_key [ :schabba_id, :doo_id ], :bar, [ :schabba_id, :doo_id ]
		end

		assert_equal([
			%{CREATE TABLE "foo" (
  "id" serial primary key,
  "foo_id" integer,
  "bar_id" integer,
  "baz_id" integer,
  FOREIGN KEY ("foo_id") REFERENCES "foo" ON DELETE SET NULL ON UPDATE CASCADE,
  FOREIGN KEY ("bar_id") REFERENCES "bar",
  FOREIGN KEY ("baz_id") REFERENCES "baz",
  FOREIGN KEY ("schabba_id", "doo_id") REFERENCES "bar" ("schabba_id", "doo_id")
)} ], statements)
	end
end
