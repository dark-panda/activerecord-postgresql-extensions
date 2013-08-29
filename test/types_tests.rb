
$: << File.dirname(__FILE__)
require 'test_helper'

class TypesTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_types
    types = ARBC.real_execute do
      ARBC.types
    end

    assert_kind_of(Array, types)
    assert_includes(types, 'oid')
  end

  def test_type_exists
    ARBC.real_execute do
      assert(ARBC.type_exists?(:oid))
      assert(ARBC.type_exists?('oid'))
    end
  end
end
