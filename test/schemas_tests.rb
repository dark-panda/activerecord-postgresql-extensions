
$: << File.dirname(__FILE__)
require 'test_helper'

class SchemasTests < Test::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_schema
    Mig.create_schema(:foo)
    Mig.create_schema(:foo, :authorization => 'bar')

    assert_equal([
      "CREATE SCHEMA \"foo\";",
      "CREATE SCHEMA \"foo\" AUTHORIZATION \"bar\";"
    ], statements)
  end

  def test_drop_schema
    Mig.drop_schema(:foo)
    Mig.drop_schema(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      "DROP SCHEMA \"foo\";",
      "DROP SCHEMA IF EXISTS \"foo\" CASCADE;"
    ], statements)
  end

  def test_alter_schema_name
    Mig.alter_schema_name(:foo, :bar)

    assert_equal([
      "ALTER SCHEMA \"foo\" RENAME TO \"bar\";"
    ], statements)
  end

  def test_alter_schema_owner
    Mig.alter_schema_owner(:foo, :bar)

    assert_equal([
      "ALTER SCHEMA \"foo\" OWNER TO \"bar\";"
    ], statements)
  end
end
