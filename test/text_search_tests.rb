
$: << File.dirname(__FILE__)
require 'test_helper'

class TextSearchTests < PostgreSQLExtensionsTestCase
  def test_create_text_search_configuration
    ARBC.create_text_search_configuration(:foo, :parser_name => 'bar')
    ARBC.create_text_search_configuration(:foo, :source_config => 'bar')
    ARBC.create_text_search_configuration(:foo, :source_config => { :pg_catalog => 'english' })

    assert_equal([
      %{CREATE TEXT SEARCH CONFIGURATION "foo" (PARSER = "bar");},
      %{CREATE TEXT SEARCH CONFIGURATION "foo" (COPY = "bar");},
      %{CREATE TEXT SEARCH CONFIGURATION "foo" (COPY = "pg_catalog"."english");}
    ], statements)

    assert_raises(ArgumentError) do
      ARBC.create_text_search_configuration(:foo)
    end

    assert_raises(ArgumentError) do
      ARBC.create_text_search_configuration(:foo, :parser_name => 'bar', :source_config => 'lolwut')
    end
  end

  def test_add_text_search_configuration_mapping
    ARBC.add_text_search_configuration_mapping(:foo, :asciiword, :bar)
    ARBC.add_text_search_configuration_mapping(:foo, [ :asciiword, :word ], [ :bar, :up ])

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" ADD MAPPING FOR "asciiword" WITH "bar";},
      %{ALTER TEXT SEARCH CONFIGURATION "foo" ADD MAPPING FOR "asciiword", "word" WITH "bar", "up";}
    ], statements)
  end

  def test_alter_text_search_configuration_mapping
    ARBC.alter_text_search_configuration_mapping(:foo, :asciiword, :bar)
    ARBC.alter_text_search_configuration_mapping(:foo, [ :asciiword, :word ], [ :bar, :up ])

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" ALTER MAPPING FOR "asciiword" WITH "bar";},
      %{ALTER TEXT SEARCH CONFIGURATION "foo" ALTER MAPPING FOR "asciiword", "word" WITH "bar", "up";}
    ], statements)
  end

  def test_replace_text_search_configuration_dictionary
    ARBC.replace_text_search_configuration_dictionary(:foo, :bar, :ometer)

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" ALTER MAPPING REPLACE "bar" WITH "ometer";}
    ], statements)
  end

  def test_alter_text_search_configuration_mapping_replace_dictionary
    ARBC.alter_text_search_configuration_mapping_replace_dictionary(:foo, :bar, :old, :new)
    ARBC.alter_text_search_configuration_mapping_replace_dictionary(:foo, [ :hello, :world ], :old, :new)

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" ALTER MAPPING FOR "bar" REPLACE "old" WITH "new";},
      %{ALTER TEXT SEARCH CONFIGURATION "foo" ALTER MAPPING FOR "hello", "world" REPLACE "old" WITH "new";}
    ], statements)
  end

  def test_drop_text_search_configuration_mapping
    ARBC.drop_text_search_configuration_mapping(:foo, :bar)
    ARBC.drop_text_search_configuration_mapping(:foo, :bar, :blort)
    ARBC.drop_text_search_configuration_mapping(:foo, :bar, :if_exists => true)

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" DROP MAPPING FOR "bar";},
      %{ALTER TEXT SEARCH CONFIGURATION "foo" DROP MAPPING FOR "bar", "blort";},
      %{ALTER TEXT SEARCH CONFIGURATION "foo" DROP MAPPING IF EXISTS FOR "bar";}
    ], statements)

    assert_raises(ArgumentError) do
      ARBC.drop_text_search_configuration_mapping(:foo)
    end

    assert_raises(ArgumentError) do
      ARBC.drop_text_search_configuration_mapping(:foo, :if_exists => true)
    end
  end

  def test_rename_text_search_configuration
    ARBC.rename_text_search_configuration(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" RENAME TO "bar";}
    ], statements)
  end

  def test_alter_text_search_configuration_owner
    ARBC.alter_text_search_configuration_owner(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" OWNER TO "bar";}
    ], statements)
  end

  def test_alter_text_search_configuration_schema
    ARBC.alter_text_search_configuration_schema(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH CONFIGURATION "foo" SET SCHEMA "bar";}
    ], statements)
  end

  def test_drop_text_search_configuration
    ARBC.drop_text_search_configuration(:foo)
    ARBC.drop_text_search_configuration(:foo => :bar)
    ARBC.drop_text_search_configuration(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP TEXT SEARCH CONFIGURATION "foo";},
      %{DROP TEXT SEARCH CONFIGURATION "foo"."bar";},
      %{DROP TEXT SEARCH CONFIGURATION IF EXISTS "foo" CASCADE;}
    ], statements)
  end

  def test_create_text_search_dictionary
    ARBC.create_text_search_dictionary(:foo, :bar, :language => 'english')
    ARBC.create_text_search_dictionary(:foo, { :pg_catalog => :snowball }, { :language => 'english' })

    assert_equal([
      %{CREATE TEXT SEARCH DICTIONARY "foo" (TEMPLATE = "bar", "language" = 'english');},
      %{CREATE TEXT SEARCH DICTIONARY "foo" (TEMPLATE = "pg_catalog"."snowball", "language" = 'english');}
    ], statements)
  end

  def test_drop_text_search_dictionary
    ARBC.drop_text_search_dictionary(:foo)
    ARBC.drop_text_search_dictionary(:foo => :bar)
    ARBC.drop_text_search_dictionary(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP TEXT SEARCH DICTIONARY "foo";},
      %{DROP TEXT SEARCH DICTIONARY "foo"."bar";},
      %{DROP TEXT SEARCH DICTIONARY IF EXISTS "foo" CASCADE;}
    ], statements)
  end

  def test_rename_text_search_dictionary
    ARBC.rename_text_search_dictionary(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH DICTIONARY "foo" RENAME TO "bar";}
    ], statements)
  end

  def test_alter_text_search_dictionary_owner
    ARBC.alter_text_search_dictionary_owner(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH DICTIONARY "foo" OWNER TO "bar";}
    ], statements)
  end

  def test_alter_text_search_dictionary_schema
    ARBC.alter_text_search_dictionary_schema(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH DICTIONARY "foo" SET SCHEMA "bar";}
    ], statements)
  end

  def test_create_text_search_template
    ARBC.create_text_search_template(:foo, :lexize => 'bar')
    ARBC.create_text_search_template(:foo, :lexize => 'bar', :init => 'lol')

    assert_equal([
      %{CREATE TEXT SEARCH TEMPLATE "foo" (LEXIZE = "bar");},
      %{CREATE TEXT SEARCH TEMPLATE "foo" (INIT = "lol", LEXIZE = "bar");}
    ], statements)

    assert_raises(ArgumentError) do
      ARBC.create_text_search_template(:foo)
    end
  end

  def test_drop_text_search_template
    ARBC.drop_text_search_template(:foo)
    ARBC.drop_text_search_template(:foo => :bar)
    ARBC.drop_text_search_template(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP TEXT SEARCH TEMPLATE "foo";},
      %{DROP TEXT SEARCH TEMPLATE "foo"."bar";},
      %{DROP TEXT SEARCH TEMPLATE IF EXISTS "foo" CASCADE;}
    ], statements)
  end

  def test_rename_text_search_template
    ARBC.rename_text_search_template(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH TEMPLATE "foo" RENAME TO "bar";}
    ], statements)
  end

  def test_alter_text_search_template_schema
    ARBC.alter_text_search_template_schema(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH TEMPLATE "foo" SET SCHEMA "bar";}
    ], statements)
  end

  def test_create_text_search_parser
    ARBC.create_text_search_parser(:foo, {
      :start => 'start',
      :gettoken => 'gettoken',
      :end => 'end',
      :lextypes => 'lextypes'
    })

    ARBC.create_text_search_parser(:foo, {
      :start => 'start',
      :gettoken => 'gettoken',
      :end => 'end',
      :lextypes => 'lextypes',
      :headline => 'headline'
    })

    assert_equal([
      %{CREATE TEXT SEARCH PARSER "foo" (START = "start", GETTOKEN = "gettoken", END = "end", LEXTYPES = "lextypes");},
      %{CREATE TEXT SEARCH PARSER "foo" (START = "start", GETTOKEN = "gettoken", END = "end", LEXTYPES = "lextypes", HEADLINE = "headline");}
    ], statements)

    assert_raises(ArgumentError) do
      ARBC.create_text_search_parser(:foo)
    end
  end

  def test_drop_text_search_parser
    ARBC.drop_text_search_parser(:foo)
    ARBC.drop_text_search_parser(:foo => :bar)
    ARBC.drop_text_search_parser(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP TEXT SEARCH PARSER "foo";},
      %{DROP TEXT SEARCH PARSER "foo"."bar";},
      %{DROP TEXT SEARCH PARSER IF EXISTS "foo" CASCADE;}
    ], statements)
  end

  def test_rename_text_search_parser
    ARBC.rename_text_search_parser(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH PARSER "foo" RENAME TO "bar";}
    ], statements)
  end

  def test_alter_text_search_parser_schema
    ARBC.alter_text_search_parser_schema(:foo, :bar)

    assert_equal([
      %{ALTER TEXT SEARCH PARSER "foo" SET SCHEMA "bar";}
    ], statements)
  end
end
