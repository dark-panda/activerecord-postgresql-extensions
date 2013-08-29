
$: << File.dirname(__FILE__)
require 'test_helper'

class ExtensionsTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_extension
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.create_extension(:foo)
    ARBC.create_extension(:foo, :if_not_exists => true)
    ARBC.create_extension(:foo, :schema => :bar)
    ARBC.create_extension(:foo, :version => '0.0.1')
    ARBC.create_extension(:foo, :old_version => '0.0.1')

    assert_equal([
      %{CREATE EXTENSION "foo";},
      %{CREATE EXTENSION IF NOT EXISTS "foo";},
      %{CREATE EXTENSION "foo" SCHEMA "bar";},
      %{CREATE EXTENSION "foo" VERSION "0.0.1";},
      %{CREATE EXTENSION "foo" FROM "0.0.1";}
    ], statements)
  end

  def test_drop_extension
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.drop_extension(:foo)
    ARBC.drop_extension(:foo, :if_exists => true)
    ARBC.drop_extension(:foo, :cascade => true)
    ARBC.drop_extension(:foo, :bar)

    assert_equal([
      %{DROP EXTENSION "foo";},
      %{DROP EXTENSION IF EXISTS "foo";},
      %{DROP EXTENSION "foo" CASCADE;},
      %{DROP EXTENSION "foo", "bar";}
    ], statements)
  end

  def test_update_extension
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.update_extension(:foo)
    ARBC.update_extension(:foo, '2.0.0')

    assert_equal([
      %{ALTER EXTENSION "foo" UPDATE;},
      %{ALTER EXTENSION "foo" UPDATE TO "2.0.0";}
    ], statements)
  end

  def test_update_schema
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension_schema(:foo, :bar)

    assert_equal([
      %{ALTER EXTENSION "foo" SET SCHEMA "bar";}
    ], statements)
  end

  def test_alter_extension_empty
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo)

    assert_equal([], statements)
  end

  def test_alter_extension_regular_options_with_hashes
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo, {
      :collation => :bar,
      :conversion => :bar,
      :domain => :bar,
      :foreign_data_wrapper => :bar,
      :foreign_table => :bar,
      :schema => :bar,
      :sequence => :bar,
      :server => :bar,
      :table => :bar,
      :text_search_configuration => :bar,
      :text_search_dictionary => :bar,
      :text_search_parser => :bar,
      :text_search_template => :bar,
      :type => :bar,
      :view => :bar
    })

    ARBC.alter_extension(:foo, {
      :add_collation => :bar,
      :add_conversion => :bar,
      :add_domain => :bar,
      :add_foreign_data_wrapper => :bar,
      :add_foreign_table => :bar,
      :add_schema => :bar,
      :add_sequence => :bar,
      :add_server => :bar,
      :add_table => :bar,
      :add_text_search_configuration => :bar,
      :add_text_search_dictionary => :bar,
      :add_text_search_parser => :bar,
      :add_text_search_template => :bar,
      :add_type => :bar,
      :add_view => :bar
    })

    ARBC.alter_extension(:foo, {
      :drop_collation => :bar,
      :drop_conversion => :bar,
      :drop_domain => :bar,
      :drop_foreign_data_wrapper => :bar,
      :drop_foreign_table => :bar,
      :drop_schema => :bar,
      :drop_sequence => :bar,
      :drop_server => :bar,
      :drop_table => :bar,
      :drop_text_search_configuration => :bar,
      :drop_text_search_dictionary => :bar,
      :drop_text_search_parser => :bar,
      :drop_text_search_template => :bar,
      :drop_type => :bar,
      :drop_view => :bar
    })

    assert_equal([
      [
        %{ALTER EXTENSION "foo" ADD COLLATION "bar";},
        %{ALTER EXTENSION "foo" ADD CONVERSION "bar";},
        %{ALTER EXTENSION "foo" ADD DOMAIN "bar";},
        %{ALTER EXTENSION "foo" ADD FOREIGN DATA WRAPPER "bar";},
        %{ALTER EXTENSION "foo" ADD FOREIGN TABLE "bar";},
        %{ALTER EXTENSION "foo" ADD SCHEMA "bar";},
        %{ALTER EXTENSION "foo" ADD SEQUENCE "bar";},
        %{ALTER EXTENSION "foo" ADD SERVER "bar";},
        %{ALTER EXTENSION "foo" ADD TABLE "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH CONFIGURATION "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH DICTIONARY "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH PARSER "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH TEMPLATE "bar";},
        %{ALTER EXTENSION "foo" ADD TYPE "bar";},
        %{ALTER EXTENSION "foo" ADD VIEW "bar";}
      ].sort,

      [
        %{ALTER EXTENSION "foo" ADD COLLATION "bar";},
        %{ALTER EXTENSION "foo" ADD CONVERSION "bar";},
        %{ALTER EXTENSION "foo" ADD DOMAIN "bar";},
        %{ALTER EXTENSION "foo" ADD FOREIGN DATA WRAPPER "bar";},
        %{ALTER EXTENSION "foo" ADD FOREIGN TABLE "bar";},
        %{ALTER EXTENSION "foo" ADD SCHEMA "bar";},
        %{ALTER EXTENSION "foo" ADD SEQUENCE "bar";},
        %{ALTER EXTENSION "foo" ADD SERVER "bar";},
        %{ALTER EXTENSION "foo" ADD TABLE "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH CONFIGURATION "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH DICTIONARY "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH PARSER "bar";},
        %{ALTER EXTENSION "foo" ADD TEXT SEARCH TEMPLATE "bar";},
        %{ALTER EXTENSION "foo" ADD TYPE "bar";},
        %{ALTER EXTENSION "foo" ADD VIEW "bar";}
      ].sort,

      [
        %{ALTER EXTENSION "foo" DROP COLLATION "bar";},
        %{ALTER EXTENSION "foo" DROP CONVERSION "bar";},
        %{ALTER EXTENSION "foo" DROP DOMAIN "bar";},
        %{ALTER EXTENSION "foo" DROP FOREIGN DATA WRAPPER "bar";},
        %{ALTER EXTENSION "foo" DROP FOREIGN TABLE "bar";},
        %{ALTER EXTENSION "foo" DROP SCHEMA "bar";},
        %{ALTER EXTENSION "foo" DROP SEQUENCE "bar";},
        %{ALTER EXTENSION "foo" DROP SERVER "bar";},
        %{ALTER EXTENSION "foo" DROP TABLE "bar";},
        %{ALTER EXTENSION "foo" DROP TEXT SEARCH CONFIGURATION "bar";},
        %{ALTER EXTENSION "foo" DROP TEXT SEARCH DICTIONARY "bar";},
        %{ALTER EXTENSION "foo" DROP TEXT SEARCH PARSER "bar";},
        %{ALTER EXTENSION "foo" DROP TEXT SEARCH TEMPLATE "bar";},
        %{ALTER EXTENSION "foo" DROP TYPE "bar";},
        %{ALTER EXTENSION "foo" DROP VIEW "bar";}
      ].sort
    ], statements.collect { |s|
      s.split(/\n/).sort
    })
  end

  def test_alter_extension_regular_options_with_block
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo) do |e|
      e.drop_collation :bar
      e.add_conversion :bar
      e.domain :bar
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      ALTER EXTENSION "foo" DROP COLLATION "bar";
      ALTER EXTENSION "foo" ADD CONVERSION "bar";
      ALTER EXTENSION "foo" ADD DOMAIN "bar";
    SQL
  end

  def test_alter_extension_cast_option
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo) do |e|
      e.cast :hello => :world
      e.cast [ :hello, :world ]
      e.cast :source => :hello, :target => :world
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      ALTER EXTENSION "foo" ADD CAST ("hello" AS "world");
      ALTER EXTENSION "foo" ADD CAST ("hello" AS "world");
      ALTER EXTENSION "foo" ADD CAST ("hello" AS "world");
    SQL
  end

  def test_alter_extension_aggregate_option
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo) do |e|
      e.aggregate :name => :bar, :types => %w{ type_a type_b type_c }
      e.aggregate :bar, :type_a, :type_b, :type_c
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      ALTER EXTENSION "foo" ADD AGGREGATE "bar" ("type_a", "type_b", "type_c");
      ALTER EXTENSION "foo" ADD AGGREGATE "bar" ("type_a", "type_b", "type_c");
    SQL
  end

  def test_alter_extension_operator_option
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo) do |e|
      e.operator :bar, :hello, :world
      e.operator [ :bar, :hello, :world ]
      e.operator :name => :bar, :left_type => :hello, :right_type => :world
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      ALTER EXTENSION "foo" ADD OPERATOR "bar" ("hello", "world");
      ALTER EXTENSION "foo" ADD OPERATOR "bar" ("hello", "world");
      ALTER EXTENSION "foo" ADD OPERATOR "bar" ("hello", "world");
    SQL
  end

  def test_alter_extension_operator_class_option
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo) do |e|
      e.operator_class :hello => :world
      e.operator_class :hello, :world
      e.operator_class [ :hello, :world ]
      e.operator_class :name => :hello, :indexing_method => :world
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      ALTER EXTENSION "foo" ADD OPERATOR CLASS "hello" USING "world");
      ALTER EXTENSION "foo" ADD OPERATOR CLASS "hello" USING "world");
      ALTER EXTENSION "foo" ADD OPERATOR CLASS "hello" USING "world");
      ALTER EXTENSION "foo" ADD OPERATOR CLASS "hello" USING "world");
    SQL
  end

  def test_alter_extension_operator_family_option
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo) do |e|
      e.operator_family :hello => :world
      e.operator_family :hello, :world
      e.operator_family [ :hello, :world ]
      e.operator_family :name => :hello, :indexing_method => :world
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      ALTER EXTENSION "foo" ADD OPERATOR FAMILY "hello" USING "world");
      ALTER EXTENSION "foo" ADD OPERATOR FAMILY "hello" USING "world");
      ALTER EXTENSION "foo" ADD OPERATOR FAMILY "hello" USING "world");
      ALTER EXTENSION "foo" ADD OPERATOR FAMILY "hello" USING "world");
    SQL
  end

  def test_alter_extension_function_option
    skip if !ActiveRecord::PostgreSQLExtensions::Features.extensions?

    ARBC.alter_extension(:foo) do |e|
      e.function :bar, "VARIADIC hello world"
      e.function [ :bar, "VARIADIC hello world" ]
      e.function :name => :bar, :arguments => "VARIADIC hello world"
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      ALTER EXTENSION "foo" ADD FUNCTION "bar"(VARIADIC hello world);
      ALTER EXTENSION "foo" ADD FUNCTION "bar"(VARIADIC hello world);
      ALTER EXTENSION "foo" ADD FUNCTION "bar"(VARIADIC hello world);
    SQL
  end
end
