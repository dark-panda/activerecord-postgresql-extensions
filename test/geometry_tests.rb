
$: << File.dirname(__FILE__)
require 'test_helper'

class GeometryTests < PostgreSQLExtensionsTestCase
  include PostgreSQLExtensionsTestHelper

  def setup
    super
    skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?
  end

  def test_update_geometry_srid
    ARBC.update_geometry_srid(:foo, :the_geom, 4326)
    ARBC.update_geometry_srid("foo.bar", :the_geom, 4326)
    ARBC.update_geometry_srid({ :foo => :bar }, :the_geom, 4326)

    expected = [
      %{SELECT UpdateGeometrySRID('foo', 'the_geom', 4326);},
      %{SELECT UpdateGeometrySRID('foo', 'bar', 'the_geom', 4326);},
      %{SELECT UpdateGeometrySRID('foo', 'bar', 'the_geom', 4326);}
    ]

    assert_equal(expected, statements)
  end
end

if (ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] rescue '') >= '2.0'
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
  end
else
  class GeometryTests < Test::Unit::TestCase
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
  end
end
