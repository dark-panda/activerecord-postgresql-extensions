
require 'test/test_helper'

class AdapterExtensionTests < Test::Unit::TestCase
	include PostgreSQLExtensionsTestHelper

	ARBC = ActiveRecord::Base.connection

	def setup
		clear_statements!
	end

	def test_quote_table_name_with_schema_string
		assert_equal(%{"foo"."bar"}, ARBC.quote_table_name('foo.bar'))
	end

	def test_quote_table_name_with_schema_hash
		assert_equal(%{"foo"."bar"}, ARBC.quote_table_name(:foo => :bar))
	end

	def test_quote_table_name_with_current_schema
		assert_equal(%{"foo"."bar"}, ARBC.with_schema(:foo) {
			ARBC.quote_table_name(:bar)
		})
	end

	def test_quote_table_name_with_current_schema_ignored
		assert_equal(%{"bar"}, ARBC.with_schema(:foo) {
			ARBC.ignore_schema {
				ARBC.quote_table_name(:bar)
			}
		})
	end

	def test_quote_schema
		assert_equal('PUBLIC', ARBC.quote_schema(:public))
		assert_equal(%{"foo"}, ARBC.quote_schema(:foo))
	end

	def test_other_quoting
		assert_equal(%{"foo"}, ARBC.quote_generic(:foo))
		assert_equal(%{"foo"}, ARBC.quote_role(:foo))
		assert_equal(%{"foo"}, ARBC.quote_rule(:foo))
		assert_equal(%{"foo"}, ARBC.quote_language(:foo))
		assert_equal(%{"foo"}, ARBC.quote_sequence(:foo))
		assert_equal(%{"foo"}, ARBC.quote_function(:foo))
		assert_equal(%{"foo"}, ARBC.quote_view_name(:foo))
		assert_equal(%{"foo"}, ARBC.quote_tablespace(:foo))
	end
end
