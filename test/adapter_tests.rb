
$: << File.dirname(__FILE__)
require 'test_helper'

class AdapterExtensionTests < Test::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

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

  def test_simplified_type
    col = ActiveRecord::ConnectionAdapters::PostgreSQLColumn.new('vector', nil)
    assert_equal(:geometry, col.send(:simplified_type, 'geometry'))
    assert_equal(:tsvector, col.send(:simplified_type, 'tsvector'))
    assert_equal(:integer, col.send(:simplified_type, 'integer'))
    assert_equal(nil, col.send(:simplified_type, 'complete_nonsense'))
  end

  def test_set_role
    ARBC.set_role('foo')
    ARBC.set_role('foo', :duration => :local)
    ARBC.set_role('foo', :duration => :session)

    assert_equal([
      %{SET ROLE "foo";},
      %{SET LOCAL ROLE "foo";},
      %{SET SESSION ROLE "foo";}
    ], ARBC.statements)

    assert_raise(ArgumentError) do
      ARBC.set_role('foo', :duration => :nonsense)
    end
  end

  def test_reset_role
    ARBC.reset_role
    assert_equal([ 'RESET ROLE;' ], ARBC.statements)
  end

  def test_current_role
    ARBC.current_role
    ARBC.current_user

    assert_equal([
      'SELECT current_role;',
      'SELECT current_role;'
    ], ARBC.statements)
  end
end
