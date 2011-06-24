
$: << File.dirname(__FILE__)
require 'test_helper'

class GeometryTests < Test::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_geometry
    Mig.create_table(:foo) do |t|
      t.geometry :the_geom, :srid => 4326
    end

    assert_equal([
      %{CREATE TABLE "foo" (
  "id" serial primary key,
  "the_geom" geometry,
  CONSTRAINT "enforce_srid_the_geom" CHECK (srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ndims("the_geom") = 2)
)},
  %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom'},
  %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'geometry')},
  %{CREATE INDEX "foo_the_geom_gist_index" ON "foo" USING "gist"("the_geom")}
    ], statements)
  end

  def test_create_geometry_with_schema
    Mig.create_table('public.foo') do |t|
      t.geometry :the_geom, :srid => 4326
    end

    assert_equal([
      %{CREATE TABLE "public"."foo" (
  "id" serial primary key,
  "the_geom" geometry,
  CONSTRAINT "enforce_srid_the_geom" CHECK (srid("the_geom") = (4326)),
  CONSTRAINT "enforce_dims_the_geom" CHECK (ndims("the_geom") = 2)
)},
  %{DELETE FROM "geometry_columns" WHERE f_table_catalog = '' AND f_table_schema = 'public' AND f_table_name = 'foo' AND f_geometry_column = 'the_geom'},
  %{INSERT INTO "geometry_columns" VALUES ('', 'public', 'foo', 'the_geom', 2, 4326, 'geometry')},
  %{CREATE INDEX "foo_the_geom_gist_index" ON "foo" USING "gist"("the_geom")}
    ], statements)
  end
end
