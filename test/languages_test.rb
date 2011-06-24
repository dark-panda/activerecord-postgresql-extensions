
$: << File.dirname(__FILE__)
require 'test_helper'

class LanguagesTests < Test::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_language
    Mig.create_language(:foo)
    Mig.create_language(
      :foo,
      :trusted => true,
      :call_handler => 'plpgsql',
      :validator => 'test()'
    )

    assert_equal([
      "CREATE PROCEDURAL LANGUAGE \"foo\"",
      "CREATE TRUSTED PROCEDURAL LANGUAGE \"foo\" HANDLER \"plpgsql\" VALIDATOR test()"
    ], statements)
  end

  def test_drop_language
    Mig.drop_language(:foo)
    Mig.drop_language(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      "DROP PROCEDURAL LANGUAGE \"foo\"",
      "DROP PROCEDURAL LANGUAGE IF EXISTS \"foo\" CASCADE"
    ], statements)
  end

  def test_alter_language_name
    Mig.alter_language_name(:foo, :bar)

    assert_equal([
      "ALTER PROCEDURAL LANGUAGE \"foo\" RENAME TO \"bar\""
    ], statements)
  end

  def test_alter_language_owner
    Mig.alter_language_owner(:foo, :bar)

    assert_equal([
      "ALTER PROCEDURAL LANGUAGE \"foo\" OWNER TO \"bar\""
    ], statements)
  end
end
