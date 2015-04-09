
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
  require 'geometry_tests_modern_postgis'
else
  require 'geometry_tests_legacy_postgis'
end
