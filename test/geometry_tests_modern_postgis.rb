
class GeometryTests < PostgreSQLExtensionsTestCase
  def test_create_geometry
    Mig.create_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geometry(GEOMETRY, 4326)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_create_geometry_with_spatial
    Mig.create_table(:foo) do |t|
      t.spatial :the_geom, :srid => 4326
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geometry(GEOMETRY, 4326)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_create_geometry_with_spatial_and_spatial_column_type
    Mig.create_table(:foo) do |t|
      t.spatial :the_geom, :srid => 4326, :spatial_column_type => :geography
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geography(GEOMETRY, 4326)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_create_geography
    Mig.create_table(:foo) do |t|
      t.geography :the_geom, :srid => 4326
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geography(GEOMETRY, 4326)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_create_geometry_with_force_constraints
    Mig.create_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :force_constraints => true
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geometry(GEOMETRY, 4326),
        CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
        CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_create_geometry_with_schema
    Mig.create_table('shabba.foo') do |t|
      t.geometry :the_geom, :srid => 4326
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "shabba"."foo" (
        "id" serial primary key,
        "the_geom" geometry(GEOMETRY, 4326)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON "shabba"."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_create_geometry_with_not_null
    Mig.create_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :null => false
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geometry(GEOMETRY, 4326) NOT NULL
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_create_geometry_with_null_and_type
    Mig.create_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :geometry_type => :polygon
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geometry(POLYGON, 4326)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");
    SQL

    assert_equal(expected, statements)
  end

  def test_change_table_add_geometry
    Mig.change_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry(GEOMETRY, 4326)},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_add_geometry_with_spatial
    Mig.change_table(:foo) do |t|
      t.spatial :the_geom, :srid => 4326
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry(GEOMETRY, 4326)},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_spatial_and_spatial_column_type
    Mig.change_table(:foo) do |t|
      t.spatial :the_geom, :srid => 4326, :spatial_column_type => :geography
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geography(GEOMETRY, 4326)},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geography
    Mig.change_table(:foo) do |t|
      t.geography :the_geom, :srid => 4326
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geography(GEOMETRY, 4326)},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_force_constraints
    Mig.change_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :force_constraints => true
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry(GEOMETRY, 4326)},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_schema
    Mig.change_table('shabba.foo') do |t|
      t.geometry :the_geom, :srid => 4326
    end

    expected = [
      %{ALTER TABLE "shabba"."foo" ADD COLUMN "the_geom" geometry(GEOMETRY, 4326)},
      %{CREATE INDEX "foo_the_geom_gist_index" ON "shabba"."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_not_null
    Mig.change_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :null => false
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry(GEOMETRY, 4326) NOT NULL},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_null_and_type
    Mig.change_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :geometry_type => :polygon
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry(POLYGON, 4326)},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end
end

