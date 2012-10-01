
$: << File.dirname(__FILE__)
require 'test_helper'

class VacuumTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_vacuum
    ARBC.vacuum
    ARBC.vacuum(:full => true, :freeze => true, :verbose  => true, :analyze => true)
    ARBC.vacuum(:foo, :full => true, :freeze => true, :verbose  => true, :analyze => true)
    ARBC.vacuum(:foo, :columns => :bar)
    ARBC.vacuum(:foo, :columns => [ :bar, :baz ])

    if ActiveRecord::PostgreSQLExtensions.SERVER_VERSION.to_f >= 9.0
      assert_equal([
        %{VACUUM;},
        %{VACUUM (FULL, FREEZE, VERBOSE, ANALYZE);},
        %{VACUUM (FULL, FREEZE, VERBOSE, ANALYZE) "foo";},
        %{VACUUM (ANALYZE) "foo" ("bar");},
        %{VACUUM (ANALYZE) "foo" ("bar", "baz");}
      ], statements)
    else
      assert_equal([
        "VACUUM;",
        %{VACUUM FULL FREEZE VERBOSE ANALYZE;},
        %{VACUUM FULL FREEZE VERBOSE ANALYZE "foo";},
        %{VACUUM ANALYZE "foo" ("bar");},
        %{VACUUM ANALYZE "foo" ("bar", "baz");}
      ], statements)
    end
  end

  def test_vacuum_with_columns_but_no_table
    assert_raises(ArgumentError) do
      ARBC.vacuum(:columns => :bar)
    end
  end
end
