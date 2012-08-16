
$: << File.dirname(__FILE__)
require 'test_helper'

class TriggerTests < Test::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_enable_triggers
    Foo.enable_triggers
    Foo.enable_triggers(:bar)
    Foo.enable_triggers(:bar, :baz)

    assert_equal([
      %{ALTER TABLE "foos" ENABLE TRIGGER ALL;},
      %{ALTER TABLE "foos" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" ENABLE TRIGGER "baz";}
    ], statements)
  end

  def test_disable_triggers
    Foo.disable_triggers
    Foo.disable_triggers(:bar)
    Foo.disable_triggers(:bar, :baz)

    assert_equal([
      %{ALTER TABLE "foos" DISABLE TRIGGER ALL;},
      %{ALTER TABLE "foos" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" DISABLE TRIGGER "baz";}
    ], statements)
  end

  def test_without_triggers
    begin
      Foo.without_triggers do
        raise "WHAT HAPPEN"
      end
    rescue
    end

    begin
      Foo.without_triggers(:bar) do
        raise "WHAT HAPPEN"
      end
    rescue
    end

    begin
      Foo.without_triggers(:bar, :baz) do
        raise "WHAT HAPPEN"
      end
    rescue
    end

    assert_equal([
      %{ALTER TABLE "foos" DISABLE TRIGGER ALL;},
      %{ALTER TABLE "foos" ENABLE TRIGGER ALL;},
      %{ALTER TABLE "foos" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" DISABLE TRIGGER "baz";},
      %{ALTER TABLE "foos" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foos" ENABLE TRIGGER "baz";}
    ], statements)
  end

  def test_create_trigger # (name, called, events, table, function, options = {})
    ARBC.create_trigger(:foo, :before, :update, :bar, 'do_it', :for_each => :row)

    assert_equal([
      %{CREATE TRIGGER "foo" BEFORE UPDATE ON "bar" FOR EACH ROW EXECUTE PROCEDURE "do_it"();}
    ], statements)
  end

  def test_drop_trigger # (name, table, options = {})
    ARBC.drop_trigger(:bar, :foo)
    ARBC.drop_trigger(:bar, :foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP TRIGGER "bar" ON "foo";},
      %{DROP TRIGGER IF EXISTS "bar" ON "foo" CASCADE;}
    ], statements)
  end
end
