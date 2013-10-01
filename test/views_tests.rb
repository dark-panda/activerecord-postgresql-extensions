
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
      %{ALTER VIEW "foos_view" RENAME TO "bars_view";},
      %{ALTER VIEW "baz"."foos_view" RENAME TO "bars_view";},
      %{ALTER VIEW "blort"."foos_view" RENAME TO "bars_view";}
    ], statements)
  end

  def test_alter_view_owner
    Mig.alter_view_owner(:foos, :joe)

    assert_equal([
      %{ALTER VIEW "foos" OWNER TO "joe";}
    ], statements)
  end

  def test_alter_view_schema
    Mig.alter_view_schema(:foos, :bar)

    assert_equal([
      %{ALTER VIEW "foos" SET SCHEMA "bar";}
    ], statements)
  end

  def test_if_exists
    tester = proc {
      Mig.rename_view(:foos_view, :bars_view, :if_exists => true)
    }

    if ActiveRecord::PostgreSQLExtensions::Features.view_if_exists?
      tester.call

      assert_equal([
        %{ALTER VIEW IF EXISTS "foos_view" RENAME TO "bars_view";}
      ], statements)
    else
      assert_raises(ActiveRecord::PostgreSQLExtensions::FeatureNotSupportedError) do
        tester.call
      end
    end
  end

  def test_create_view_with_options
    tester = proc {
      Mig.create_view("foos_view", "SELECT * FROM foos",
        :with_options => "security_barrier = true"
      )

      Mig.create_view("foos_view", "SELECT * FROM foos",
        :with_options => {
          :security_barrier => true
        }
      )
    }

    if ActiveRecord::PostgreSQLExtensions::Features.view_set_options?
      tester.call

      assert_equal([
        %{CREATE VIEW "foos_view" WITH (security_barrier = true) AS SELECT * FROM foos;},
        %{CREATE VIEW "foos_view" WITH ("security_barrier" = 't') AS SELECT * FROM foos;}
      ], statements)
    else
      assert_raises(ActiveRecord::PostgreSQLExtensions::FeatureNotSupportedError) do
        tester.call
      end
    end
  end

  def test_alter_view_set_options
    tester = proc {
      Mig.alter_view_set_options(:foos_view, 'security_barrier = true')
      Mig.alter_view_set_options(:foos_view, {
        :security_barrier => true
      })
    }

    if ActiveRecord::PostgreSQLExtensions::Features.view_if_exists?
      tester.call

      assert_equal([
        %{ALTER VIEW "foos_view" SET (security_barrier = true);},
        %{ALTER VIEW "foos_view" SET ("security_barrier" = 't');}
      ], statements)
    else
      assert_raises(ActiveRecord::PostgreSQLExtensions::FeatureNotSupportedError) do
        tester.call
      end
    end
  end

  def test_alter_view_reset_options
    tester = proc {
      Mig.alter_view_reset_options(:foos_view, :security_barrier)
      Mig.alter_view_reset_options(:foos_view, :security_barrier, :foos)
    }

    if ActiveRecord::PostgreSQLExtensions::Features.view_if_exists?
      tester.call

      assert_equal([
        %{ALTER VIEW "foos_view" RESET ("security_barrier");},
        %{ALTER VIEW "foos_view" RESET ("security_barrier", "foos");}
      ], statements)
    else
      assert_raises(ActiveRecord::PostgreSQLExtensions::FeatureNotSupportedError) do
        tester.call
      end
    end
  end

  def test_alter_view_set_column_default
    tester = proc {
      Mig.alter_view_set_column_default(:foos_view, :bar, 20)
      Mig.alter_view_set_column_default(:foos_view, :bar, '100 + foo')
    }

    if ActiveRecord::PostgreSQLExtensions::Features.view_if_exists?
      tester.call

      assert_equal([
        %{ALTER VIEW "foos_view" ALTER COLUMN "bar" SET DEFAULT 20;},
        %{ALTER VIEW "foos_view" ALTER COLUMN "bar" SET DEFAULT 100 + foo;}
      ], statements)
    else
      assert_raises(ActiveRecord::PostgreSQLExtensions::FeatureNotSupportedError) do
        tester.call
      end
    end
  end

  def test_alter_view_drop_column_default
    tester = proc {
      Mig.alter_view_drop_column_default(:foos_view, :bar)
    }

    if ActiveRecord::PostgreSQLExtensions::Features.view_if_exists?
      tester.call

      assert_equal([
        %{ALTER VIEW "foos_view" ALTER COLUMN "bar" DROP DEFAULT;}
      ], statements)
    else
      assert_raises(ActiveRecord::PostgreSQLExtensions::FeatureNotSupportedError) do
        tester.call
      end
    end
  end
end

