
$: << File.dirname(__FILE__)
require 'test_helper'

class FunctionsTests < PostgreSQLExtensionsTestCase
  def test_create_function
    ARBC.create_function(:test, :integer, :integer, :sql) do
      "select 10;"
    end

    ARBC.create_function(:test, :integer, :integer, :sql, {
      :force => true,
      :delimiter => '$__$',
      :behavior => :immutable,
      :on_null_input => :strict,
      :cost => 1,
      :rows => 10,
      :set => {
        'TIME ZONE' => 'America/Halifax'
      }
    }) do
      "return 10;"
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE FUNCTION "test"(integer) RETURNS integer AS $$
      select 10;
      $$
      LANGUAGE "sql";
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE OR REPLACE FUNCTION "test"(integer) RETURNS integer AS $__$
      return 10;
      $__$
      LANGUAGE "sql"
          IMMUTABLE
          STRICT
          COST 1
          ROWS 10
          SET TIME ZONE "America/Halifax";
    SQL

    assert_equal(expected, statements)
  end

  def test_create_function_with_empty_arguments
    ARBC.create_function(:test, :integer, :sql) do
      "select 10;"
    end

    ARBC.create_function(:test, :integer, :sql, {
      :force => true,
      :delimiter => '$__$',
      :behavior => :immutable,
      :on_null_input => :strict,
      :cost => 1,
      :rows => 10,
      :set => {
        'TIME ZONE' => 'America/Halifax'
      }
    }) do
      "return 10;"
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE FUNCTION "test"() RETURNS integer AS $$
      select 10;
      $$
      LANGUAGE "sql";
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE OR REPLACE FUNCTION "test"() RETURNS integer AS $__$
      return 10;
      $__$
      LANGUAGE "sql"
          IMMUTABLE
          STRICT
          COST 1
          ROWS 10
          SET TIME ZONE "America/Halifax";
    SQL

    assert_equal(expected, statements)
  end

  def test_create_function_with_body_argument
    ARBC.create_function(:test, :integer, :integer, :sql, "select 10;")

    ARBC.create_function(:test, :integer, :integer, :sql, "return 10;", {
      :force => true,
      :delimiter => '$__$',
      :behavior => :immutable,
      :on_null_input => :strict,
      :cost => 1,
      :rows => 10,
      :set => {
        'TIME ZONE' => 'America/Halifax'
      }
    })

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE FUNCTION "test"(integer) RETURNS integer AS $$
      select 10;
      $$
      LANGUAGE "sql";
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE OR REPLACE FUNCTION "test"(integer) RETURNS integer AS $__$
      return 10;
      $__$
      LANGUAGE "sql"
          IMMUTABLE
          STRICT
          COST 1
          ROWS 10
          SET TIME ZONE "America/Halifax";
    SQL

    assert_equal(expected, statements)
  end

  def test_create_function_with_body_argument_and_empty_arguments
    assert_raises(ArgumentError) do
      ARBC.create_function(:test, :integer, :sql, "select 10;")
    end

    assert_raises(ArgumentError) do
      ARBC.create_function(:test, :integer, :sql, "select 10;", {
        :force => true
      })
    end

    assert_raises(ArgumentError) do
      ARBC.create_function(:test, :integer, :sql, {
        :body => "select 20"
      }) do
        "select 30"
      end
    end

    ARBC.create_function(:test, :integer, :sql, :body => "select 20;")
    ARBC.create_function(:test, :integer, :sql, {
      :body => "select 20;",
      :force => true
    })

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE FUNCTION "test"() RETURNS integer AS $$
      select 20;
      $$
      LANGUAGE "sql";
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE OR REPLACE FUNCTION "test"() RETURNS integer AS $$
      select 20;
      $$
      LANGUAGE "sql";
    SQL

    assert_equal(expected, statements)
  end

  def test_drop_function
    ARBC.drop_function(:test, :integer)
    ARBC.drop_function(:test, :integer, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP FUNCTION "test"(integer);},
      %{DROP FUNCTION IF EXISTS "test"(integer) CASCADE;}
    ], statements)
  end

  def test_rename_function
    ARBC.rename_function(:test, 'integer, text', :foo)
    ARBC.rename_function(:test, :foo)

    assert_equal([
      %{ALTER FUNCTION "test"(integer, text) RENAME TO "foo";},
      %{ALTER FUNCTION "test"() RENAME TO "foo";}
    ], statements)
  end

  def test_alter_function_owner
    ARBC.alter_function_owner(:test, 'integer, text', :admin)
    ARBC.alter_function_owner(:test, :admin)

    assert_equal([
      %{ALTER FUNCTION "test"(integer, text) OWNER TO "admin";},
      %{ALTER FUNCTION "test"() OWNER TO "admin";}
    ], statements)
  end

  def test_alter_function_schema
    ARBC.alter_function_schema(:test, 'integer, text', :geospatial)
    ARBC.alter_function_schema(:test, :geospatial)

    assert_equal([
      %{ALTER FUNCTION "test"(integer, text) SET SCHEMA "geospatial";},
      %{ALTER FUNCTION "test"() SET SCHEMA "geospatial";}
    ], statements)
  end

  def test_alter_function
    ARBC.alter_function('my_function', 'integer', :rename_to => 'another_function')
    ARBC.alter_function('my_function', :rename_to => 'another_function')
    ARBC.alter_function('another_function', 'integer', :owner_to => 'jdoe')
    ARBC.alter_function('another_function', :owner_to => 'jdoe')
    ARBC.alter_function('my_function', 'integer') do |f|
      f.rename_to 'another_function'
      f.owner_to 'jdoe'
      f.set_schema 'foo'
      f.behavior 'immutable'
      f.security 'invoker'
      f.cost 10
      f.rows 10
      f.set({
        :log_duration => 0.4
      })
      f.reset :all
      f.reset %w{ debug_assertions trace_notify }
    end

    ARBC.alter_function('my_function') do |f|
      f.rename_to 'another_function'
    end

    expected = [
      %{ALTER FUNCTION "my_function"(integer) RENAME TO "another_function";},
      %{ALTER FUNCTION "my_function"() RENAME TO "another_function";},
      %{ALTER FUNCTION "another_function"(integer) OWNER TO "jdoe";},
      %{ALTER FUNCTION "another_function"() OWNER TO "jdoe";}
    ]

    expected << strip_heredoc(<<-SQL)
      ALTER FUNCTION "my_function"(integer) RENAME TO "another_function";
      ALTER FUNCTION "another_function"(integer) OWNER TO "jdoe";
      ALTER FUNCTION "another_function"(integer) SET SCHEMA "foo";
      ALTER FUNCTION "another_function"(integer) IMMUTABLE;
      ALTER FUNCTION "another_function"(integer) SECURITY INVOKER;
      ALTER FUNCTION "another_function"(integer) COST 10;
      ALTER FUNCTION "another_function"(integer) ROWS 10;
      ALTER FUNCTION "another_function"(integer) SET "log_duration" TO "0.4";
      ALTER FUNCTION "another_function"(integer) RESET ALL;
      ALTER FUNCTION "another_function"(integer) RESET "debug_assertions" RESET "trace_notify";
    SQL

    expected << %{ALTER FUNCTION "my_function"() RENAME TO "another_function";}

    assert_equal(expected, statements)
  end
end
