
$: << File.dirname(__FILE__)
require "test_helper"

class MaterializedViewsTests < PostgreSQLExtensionsTestCase
  def test_create_materialized_view
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.create_materialized_view("foos_view", "SELECT * FROM foos")
    Mig.create_materialized_view("foos_view", "SELECT * FROM foos", :columns => %w{ hello world })
    Mig.create_materialized_view("foos_view", "SELECT * FROM foos", :tablespace => "foo")
    Mig.create_materialized_view("foos_view", "SELECT * FROM foos", :with_data => false)
    Mig.create_materialized_view("foos_view", "SELECT * FROM foos", :with_data => true)
    Mig.create_materialized_view("foos_view", "SELECT * FROM foos", :with_options => {
      :fillfactor => 10
    })
    Mig.create_materialized_view("foos_view", "SELECT * FROM foos", :with_options => "FILLFACTOR=10")
    ARBC.create_materialized_view(
      { :baz => "foos_view" },
      "SELECT * FROM foos"
    )

    assert_equal([
      %{CREATE MATERIALIZED VIEW "foos_view" AS SELECT * FROM foos;},
      %{CREATE MATERIALIZED VIEW "foos_view" ("hello", "world") AS SELECT * FROM foos;},
      %{CREATE MATERIALIZED VIEW "foos_view" TABLESPACE "foo" AS SELECT * FROM foos;},
      %{CREATE MATERIALIZED VIEW "foos_view" AS SELECT * FROM foos WITH NO DATA;},
      %{CREATE MATERIALIZED VIEW "foos_view" AS SELECT * FROM foos;},
      %{CREATE MATERIALIZED VIEW "foos_view" WITH ("fillfactor" = 10) AS SELECT * FROM foos;},
      %{CREATE MATERIALIZED VIEW "foos_view" WITH (FILLFACTOR=10) AS SELECT * FROM foos;},
      %{CREATE MATERIALIZED VIEW "baz"."foos_view" AS SELECT * FROM foos;}
    ], statements)
  end

  def test_drop_materialized_view
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.drop_materialized_view(:foos_view)
    Mig.drop_materialized_view(:foos_view, :bars_view)
    Mig.drop_materialized_view(:foos_view, :if_exists => true)
    Mig.drop_materialized_view(:foos_view, :cascade => true)

    assert_equal([
      %{DROP MATERIALIZED VIEW "foos_view";},
      %{DROP MATERIALIZED VIEW "foos_view", "bars_view";},
      %{DROP MATERIALIZED VIEW IF EXISTS "foos_view";},
      %{DROP MATERIALIZED VIEW "foos_view" CASCADE;}
    ], statements)
  end

  def test_rename_materialized_view
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.rename_materialized_view(:foos_view, :bars_view)
    ARBC.rename_materialized_view({ :baz => :foos_view }, :bars_view)

    ARBC.with_schema(:blort) do
      Mig.rename_materialized_view(:foos_view, :bars_view)
    end

    assert_equal([
      %{ALTER MATERIALIZED VIEW "foos_view" RENAME TO "bars_view";},
      %{ALTER MATERIALIZED VIEW "baz"."foos_view" RENAME TO "bars_view";},
      %{ALTER MATERIALIZED VIEW "blort"."foos_view" RENAME TO "bars_view";}
    ], statements)
  end

  def test_alter_materialized_view_owner
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.alter_materialized_view_owner(:foos, :joe)

    assert_equal([
      %{ALTER MATERIALIZED VIEW "foos" OWNER TO "joe";}
    ], statements)
  end

  def test_alter_materialized_view_schema
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.alter_materialized_view_schema(:foos, :bar)

    assert_equal([
      %{ALTER MATERIALIZED VIEW "foos" SET SCHEMA "bar";}
    ], statements)
  end

  def test_alter_materialized_view_set_options
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.alter_materialized_view_set_options(
      "foos_view",
      "security_barrier = true"
    )

    Mig.alter_materialized_view_set_options(:foos_view,
      :security_barrier => true
    )

    assert_equal([
      %{ALTER MATERIALIZED VIEW "foos_view" SET (security_barrier = true);},
      %{ALTER MATERIALIZED VIEW "foos_view" SET ("security_barrier" = 't');}
    ], statements)
  end

  def test_alter_materialized_view_reset_options
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.alter_materialized_view_reset_options(:foos_view, :security_barrier)
    Mig.alter_materialized_view_reset_options(:foos_view, :security_barrier, :foos)

    assert_equal([
      %{ALTER MATERIALIZED VIEW "foos_view" RESET ("security_barrier");},
      %{ALTER MATERIALIZED VIEW "foos_view" RESET ("security_barrier", "foos");}
    ], statements)
  end

  def test_cluster_materialized_view
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.cluster_materialized_view(:foos_view, :foo)

    assert_equal([
      %{ALTER MATERIALIZED VIEW "foos_view" CLUSTER ON "foo";}
    ], statements)
  end

  def test_remove_cluster_from_materialized_view
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.remove_cluster_from_materialized_view(:foos_view)

    assert_equal([
      %{ALTER MATERIALIZED VIEW "foos_view" SET WITHOUT CLUSTER;}
    ], statements)
  end

  def test_refresh_materialized_view
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.refresh_materialized_view(:foos_view)
    Mig.refresh_materialized_view(:foos_view, :with_data => false)

    assert_equal([
      %{REFRESH MATERIALIZED VIEW "foos_view";},
      %{REFRESH MATERIALIZED VIEW "foos_view" WITH NO DATA;}
    ], statements)
  end
end

