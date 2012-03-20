
$: << File.dirname(__FILE__)
require 'test_helper'

class TriggerTests < Test::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_trigger # (name, called, events, table, function, options = {})
    ARBC.create_trigger(:foo, :before, :update, :bar, 'do_it', :for_each => :row)

    assert_equal([
      %{CREATE TRIGGER "foo" BEFORE UPDATE ON "bar" FOR EACH ROW EXECUTE PROCEDURE "do_it"();}
    ], ARBC.statements)
  end

  def test_drop_trigger # (name, table, options = {})
    ARBC.drop_trigger(:bar, :foo)
    ARBC.drop_trigger(:bar, :foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP TRIGGER "bar" ON "foo";},
      %{DROP TRIGGER IF EXISTS "bar" ON "foo" CASCADE;}
    ], ARBC.statements)
  end
end
