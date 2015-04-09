
class GeometryTests < PostgreSQLExtensionsTestCase
  def test_create_geometry
    Mig.create_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "the_geom" geometry,
        CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
        CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';
    SQL

    expected << strip_heredoc(<<-SQL)
      INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');
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
        "the_geom" geometry,
        CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
        CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';
    SQL

    expected << strip_heredoc(<<-SQL)
      INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');
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
        "the_geom" geography,
        CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
        CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
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
        "the_geom" geography,
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
        "the_geom" geometry,
        CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
        CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'shabba' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';
    SQL

    expected << strip_heredoc(<<-SQL)
      INSERT INTO "geometry_columns" VALUES ('', 'shabba', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');
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
        "the_geom" geometry NOT NULL,
        CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
        CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';
    SQL

    expected << strip_heredoc(<<-SQL)
      INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');
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
        "the_geom" geometry,
        CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
        CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2),
        CONSTRAINT "enforce_geotype_the_geom" CHECK (geometrytype("the_geom") = 'POLYGON'::text OR "the_geom" IS NULL)
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';
    SQL

    expected << strip_heredoc(<<-SQL)
      INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'POLYGON');
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
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
      %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_add_geometry_with_spatial
    Mig.change_table(:foo) do |t|
      t.spatial :the_geom, :srid => 4326
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
      %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_spatial_and_spatial_column_type
    Mig.change_table(:foo) do |t|
      t.spatial :the_geom, :srid => 4326, :spatial_column_type => :geography
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geography},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geography
    Mig.change_table(:foo) do |t|
      t.geography :the_geom, :srid => 4326
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geography},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_force_constraints
    Mig.change_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :force_constraints => true
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
      %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_schema
    Mig.change_table('shabba.foo') do |t|
      t.geometry :the_geom, :srid => 4326
    end

    expected = [
      %{ALTER TABLE "shabba"."foo" ADD COLUMN "the_geom" geometry},
      %{ALTER TABLE "shabba"."foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "shabba"."foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'shabba' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
      %{INSERT INTO "geometry_columns" VALUES ('', 'shabba', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
      %{CREATE INDEX "foo_the_geom_gist_index" ON "shabba"."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_not_null
    Mig.change_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :null => false
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry NOT NULL},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
      %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end

  def test_change_table_geometry_with_null_and_type
    Mig.change_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326, :geometry_type => :polygon
    end

    expected = [
      %{ALTER TABLE "foo" ADD COLUMN "the_geom" geometry},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326));},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2);},
      %{ALTER TABLE "foo" ADD CONSTRAINT "enforce_geotype_the_geom" CHECK (geometrytype("the_geom") = 'POLYGON'::text OR "the_geom" IS NULL);},
      %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
      %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'POLYGON');},
      %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
    ]

    assert_equal(expected, statements)
  end
end

