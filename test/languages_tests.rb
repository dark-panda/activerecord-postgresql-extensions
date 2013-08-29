
$: << File.dirname(__FILE__)
require 'test_helper'

class LanguagesTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_language
    ARBC.create_language(:foo)
    ARBC.create_language(
      :foo,
      :trusted => true,
      :call_handler => 'plpgsql',
      :validator => 'test()'
    )

    assert_equal([
      %{CREATE PROCEDURAL LANGUAGE "foo";},
      %{CREATE TRUSTED PROCEDURAL LANGUAGE "foo" HANDLER "plpgsql" VALIDATOR test();}
    ], statements)
  end

  def test_drop_language
    ARBC.drop_language(:foo)
    ARBC.drop_language(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP PROCEDURAL LANGUAGE "foo";},
      %{DROP PROCEDURAL LANGUAGE IF EXISTS "foo" CASCADE;}
    ], statements)
  end

  def test_alter_language_name
    ARBC.alter_language_name(:foo, :bar)

    assert_equal([
      %{ALTER PROCEDURAL LANGUAGE "foo" RENAME TO "bar";}
    ], statements)
  end

  def test_alter_language_owner
    ARBC.alter_language_owner(:foo, :bar)

    assert_equal([
      %{ALTER PROCEDURAL LANGUAGE "foo" OWNER TO "bar";}
    ], statements)
  end
end
