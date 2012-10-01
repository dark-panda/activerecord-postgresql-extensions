
$: << File.dirname(__FILE__)
require 'test_helper'

if (ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] rescue '') >= '2.0'
  class GeometryTests < MiniTest::Unit::TestCase
    include PostgreSQLExtensionsTestHelper

    def test_create_geometry
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geometry :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry(GEOMETRY, 4326)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_spatial
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.spatial :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry(GEOMETRY, 4326)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_spatial_and_spatial_column_type
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.spatial :the_geom, :srid => 4326, :spatial_column_type => :geography
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geography(GEOMETRY, 4326)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geography
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geography :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geography(GEOMETRY, 4326)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_force_constraints
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geometry :the_geom, :srid => 4326, :force_constraints => true
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry(GEOMETRY, 4326),
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_schema
      Mig.create_table('shabba.foo') do |t|
        t.geometry :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "shabba"."foo" (
  "id" serial primary key,
  "the_geom" geometry(GEOMETRY, 4326)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON "shabba"."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_not_null
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geometry :the_geom, :srid => 4326, :null => false
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry(GEOMETRY, 4326) NOT NULL
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_null_and_type
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geometry :the_geom, :srid => 4326, :geometry_type => :polygon
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry(POLYGON, 4326)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end
  end
else
  class GeometryTests < Test::Unit::TestCase
    include PostgreSQLExtensionsTestHelper

    def test_create_geometry
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geometry :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry,
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
);},
        %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
        %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_spatial
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.spatial :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry,
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
);},
        %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
        %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_spatial_and_spatial_column_type
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.spatial :the_geom, :srid => 4326, :spatial_column_type => :geography
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geography,
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geography
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geography :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geography,
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
);},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_schema
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table('shabba.foo') do |t|
        t.geometry :the_geom, :srid => 4326
      end

      assert_equal([
        %{CREATE TABLE "shabba"."foo" (
  "id" serial primary key,
  "the_geom" geometry,
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
);},
        %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'shabba' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
        %{INSERT INTO "geometry_columns" VALUES ('', 'shabba', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
        %{CREATE INDEX "foo_the_geom_gist_index" ON "shabba"."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_not_null
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geometry :the_geom, :srid => 4326, :null => false
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry NOT NULL,
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2)
);},
        %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
        %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'GEOMETRY');},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end

    def test_create_geometry_with_null_and_type
      skip if !ActiveRecord::PostgreSQLExtensions::Features.postgis?

      Mig.create_table(:foo) do |t|
        t.geometry :the_geom, :srid => 4326, :geometry_type => :polygon
      end

      assert_equal([
        %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry,
  CONSTRAINT "enforce_srid_the_geom" CHECK (ST_srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ST_ndims("the_geom") = 2),
  CONSTRAINT "enforce_geotype_the_geom" CHECK (geometrytype("the_geom") = 'POLYGON'::text OR "the_geom" IS NULL)
);},
        %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom';},
        %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'POLYGON');},
        %{CREATE INDEX "foo_the_geom_gist_index" ON PUBLIC."foo" USING "gist"("the_geom");}
      ], statements)
    end
  end
end
