
$: << File.dirname(__FILE__)
require 'test_helper'

class TablespaceTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_tablespace
    Mig.create_tablespace('foo', '/tmp/foo')
    Mig.create_tablespace('foo', '/tmp/foo', :owner => :bar)

    assert_equal([
      %{CREATE TABLESPACE "foo" LOCATION '/tmp/foo';},
      %{CREATE TABLESPACE "foo" OWNER "bar" LOCATION '/tmp/foo';}
    ], statements)
  end

  def test_drop_tablespace
    Mig.drop_tablespace('foo')
    Mig.drop_tablespace('foo', :if_exists => true)

    assert_equal([
      %{DROP TABLESPACE "foo";},
      %{DROP TABLESPACE IF EXISTS "foo";}
    ], statements)
  end

  def test_rename_tablespace
    Mig.rename_tablespace('foo', 'bar')

    assert_equal([
      %{ALTER TABLESPACE "foo" RENAME TO "bar";}
    ], statements)
  end

  def test_alter_tablespace_owner
    Mig.alter_tablespace_owner('foo', 'bar')

    assert_equal([
      %{ALTER TABLESPACE "foo" OWNER TO "bar";}
    ], statements)
  end

  def test_alter_tablespace_paramters
    Mig.alter_tablespace_parameters('foo', :seq_page_cost => 2.0, :random_page_cost => 5.0)

    assert_equal([
      %{ALTER TABLESPACE "foo" SET (
  "seq_page_cost" = 2.0,
  "random_page_cost" = 5.0
);} ], statements)
  end

  def test_reset_tablespace_paramters
    Mig.reset_tablespace_parameters('foo', :seq_page_cost, :random_page_cost)

    assert_equal([
      %{ALTER TABLESPACE "foo" RESET (
  "seq_page_cost",
  "random_page_cost"
);} ], statements)
  end
end
