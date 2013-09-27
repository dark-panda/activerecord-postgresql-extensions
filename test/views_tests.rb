
$: << File.dirname(__FILE__)
require "test_helper"

class ViewsTests < PostgreSQLExtensionsTestCase
  def test_create_view
    Mig.create_view("foos_view", "SELECT * FROM foos")
    Mig.create_view("foos_view", "SELECT * FROM foos", :replace => true)
    Mig.create_view("foos_view", "SELECT * FROM foos", :temporary => true)
    Mig.create_view("foos_view", "SELECT * FROM foos", :columns => %w{ hello world })
    ARBC.create_view(
      { :baz => "foos_view" },
      "SELECT * FROM foos"
    )

    assert_equal([
      %{CREATE VIEW "foos_view" AS SELECT * FROM foos;},
      %{CREATE OR REPLACE VIEW "foos_view" AS SELECT * FROM foos;},
      %{CREATE TEMPORARY VIEW "foos_view" AS SELECT * FROM foos;},
      %{CREATE VIEW "foos_view" ("hello", "world") AS SELECT * FROM foos;},
      %{CREATE VIEW "baz"."foos_view" AS SELECT * FROM foos;}
    ], statements)
  end

  def test_drop_view
    Mig.drop_view(:foos_view)
    Mig.drop_view(:foos_view, :if_exists => true)
    Mig.drop_view(:foos_view, :cascade => true)

    assert_equal([
      %{DROP VIEW "foos_view";},
      %{DROP VIEW IF EXISTS "foos_view";},
      %{DROP VIEW "foos_view" CASCADE;}
    ], statements)
  end

  def test_rename_view
    Mig.rename_view(:foos_view, :bars_view)
    ARBC.rename_view({ :baz => :foos_view }, :bars_view)

    ARBC.with_schema(:blort) do
      Mig.rename_view(:foos_view, :bars_view)
    end

    assert_equal([
      %{ALTER TABLE "foos_view" RENAME TO "bars_view";},
      %{ALTER TABLE "baz"."foos_view" RENAME TO "bars_view";},
      %{ALTER TABLE "blort"."foos_view" RENAME TO "bars_view";}
    ], statements)
  end

  def test_alter_view_owner
    Mig.alter_view_owner(:foos, :joe)

    assert_equal([
      %{ALTER TABLE "foos" OWNER TO "joe";}
    ], statements)
  end

  def test_alter_view_schema
    Mig.alter_view_schema(:foos, :bar)

    assert_equal([
      %{ALTER TABLE "foos" SET SCHEMA "bar";}
    ], statements)
  end
end

