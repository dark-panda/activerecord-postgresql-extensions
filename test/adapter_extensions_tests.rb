
$: << File.dirname(__FILE__)
require 'test_helper'

class AdapterExtensionTests < PostgreSQLExtensionsTestCase
  def test_quote_table_name_with_schema_string
    assert_equal(%{"foo"."bar"}, ARBC.quote_table_name('foo.bar'))
  end

  def test_quote_table_name_with_schema_hash
    assert_equal(%{"foo"."bar"}, ARBC.quote_table_name(:foo => :bar))
  end

  def test_quote_table_name_with_current_scoped_schema
    assert_equal(%{"foo"."bar"}, ARBC.with_schema(:foo) {
      ARBC.quote_table_name(:bar)
    })
  end

  def test_quote_table_name_with_current_scoped_schema_ignored
    assert_equal(%{"bar"}, ARBC.with_schema(:foo) {
      ARBC.ignore_scoped_schema {
        ARBC.quote_table_name(:bar)
      }
    })
  end

  def test_quote_schema
    assert_equal('PUBLIC', ARBC.quote_schema(:public))
    assert_equal(%{"foo"}, ARBC.quote_schema(:foo))
  end

  def test_other_quoting
    assert_equal(%{"foo"}, ARBC.quote_generic(:foo))
    assert_equal(%{"foo"}, ARBC.quote_role(:foo))
    assert_equal(%{"foo"}, ARBC.quote_rule(:foo))
    assert_equal(%{"foo"}, ARBC.quote_language(:foo))
    assert_equal(%{"foo"}, ARBC.quote_sequence(:foo))
    assert_equal(%{"foo"}, ARBC.quote_function(:foo))
    assert_equal(%{"foo"}, ARBC.quote_view_name(:foo))
    assert_equal(%{"foo"}, ARBC.quote_tablespace(:foo))
  end

  def test_simplified_type
    col = ActiveRecord::ConnectionAdapters::PostgreSQLColumn.new('vector', nil, nil)
    assert_equal(:geometry, col.send(:simplified_type, 'geometry'))
    assert_equal(:tsvector, col.send(:simplified_type, 'tsvector'))
    assert_equal(:integer, col.send(:simplified_type, 'integer'))
    assert_equal(nil, col.send(:simplified_type, 'complete_nonsense'))
  end

  def test_set_role
    ARBC.set_role('foo')
    ARBC.set_role('foo', :duration => :local)
    ARBC.set_role('foo', :duration => :session)

    assert_equal([
      %{SET ROLE "foo";},
      %{SET LOCAL ROLE "foo";},
      %{SET SESSION ROLE "foo";}
    ], statements)

    assert_raises(ArgumentError) do
      ARBC.set_role('foo', :duration => :nonsense)
    end
  end

  def test_reset_role
    ARBC.reset_role
    assert_equal([ 'RESET ROLE;' ], statements)
  end

  def test_current_role
    ARBC.current_role
    ARBC.current_user

    assert_equal([
      'SELECT current_role;',
      'SELECT current_role;'
    ], statements)
  end

  def test_enable_triggers
    ARBC.enable_triggers(:foo)
    ARBC.enable_triggers(:foo, :all)
    ARBC.enable_triggers(:foo, "all")
    ARBC.enable_triggers(:foo, :user)
    ARBC.enable_triggers(:foo, "user")
    ARBC.enable_triggers(:foo, :bar)
    ARBC.enable_triggers(:foo, :bar, :baz)

    assert_equal([
      %{ALTER TABLE "foo" ENABLE TRIGGER ALL;},
      %{ALTER TABLE "foo" ENABLE TRIGGER ALL;},
      %{ALTER TABLE "foo" ENABLE TRIGGER "all";},
      %{ALTER TABLE "foo" ENABLE TRIGGER USER;},
      %{ALTER TABLE "foo" ENABLE TRIGGER "user";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "baz";}
    ], statements)
  end

  def test_disable_triggers
    ARBC.disable_triggers(:foo)
    ARBC.disable_triggers(:foo, :all)
    ARBC.disable_triggers(:foo, "all")
    ARBC.disable_triggers(:foo, :user)
    ARBC.disable_triggers(:foo, "user")
    ARBC.disable_triggers(:foo, :bar)
    ARBC.disable_triggers(:foo, :bar, :baz)

    assert_equal([
      %{ALTER TABLE "foo" DISABLE TRIGGER ALL;},
      %{ALTER TABLE "foo" DISABLE TRIGGER ALL;},
      %{ALTER TABLE "foo" DISABLE TRIGGER "all";},
      %{ALTER TABLE "foo" DISABLE TRIGGER USER;},
      %{ALTER TABLE "foo" DISABLE TRIGGER "user";},
      %{ALTER TABLE "foo" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" DISABLE TRIGGER "baz";}
    ], statements)
  end

  def test_without_triggers
    begin
      ARBC.without_triggers(:foo) do
        raise "WHAT HAPPEN"
      end
    rescue
    end

    begin
      ARBC.without_triggers(:foo, :bar) do
        raise "WHAT HAPPEN"
      end
    rescue
    end

    begin
      ARBC.without_triggers(:foo, :bar, :baz) do
        raise "WHAT HAPPEN"
      end
    rescue
    end

    assert_equal([
      %{ALTER TABLE "foo" DISABLE TRIGGER ALL;},
      %{ALTER TABLE "foo" ENABLE TRIGGER ALL;},
      %{ALTER TABLE "foo" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" DISABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" DISABLE TRIGGER "baz";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "baz";}
    ], statements)
  end

  def test_add_column_with_expression
    Mig.add_column(:foo, :bar, :integer, :default => 100)
    Mig.add_column(:foo, :bar, :integer, :default => {
      :expression => '1 + 1'
    })

    Mig.add_column(:foo, :bar, :integer, :null => false, :default => {
      :expression => '1 + 1'
    })

    if RUBY_PLATFORM == 'java' || ActiveRecord::VERSION::MAJOR <= 2
      assert_equal([
        %{ALTER TABLE "foo" ADD COLUMN "bar" integer},
        %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 100},
        %{ALTER TABLE "foo" ADD COLUMN "bar" integer},
        %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 1 + 1;},
        %{ALTER TABLE "foo" ADD COLUMN "bar" integer},
        %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 1 + 1;},
        %{UPDATE "foo" SET "bar" = 1 + 1 WHERE "bar" IS NULL},
        %{ALTER TABLE "foo" ALTER "bar" SET NOT NULL},
      ], statements)
    else
      assert_equal([
        %{ALTER TABLE "foo" ADD COLUMN "bar" integer DEFAULT 100},
        %{ALTER TABLE "foo" ADD COLUMN "bar" integer DEFAULT 1 + 1},
        %{ALTER TABLE "foo" ADD COLUMN "bar" integer DEFAULT 1 + 1 NOT NULL}
      ], statements)
    end
  end

  def test_change_column_with_expression
    Mig.change_column(:foo, :bar, :integer, :default => 100)
    Mig.change_column(:foo, :bar, :integer, :default => {
      :expression => '1 + 1'
    })

    Mig.change_column(:foo, :bar, :integer, :null => false, :default => {
      :expression => '1 + 1'
    })

    assert_equal([
      %{ALTER TABLE "foo" ALTER COLUMN "bar" TYPE integer},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 100},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" TYPE integer},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 1 + 1;},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" TYPE integer},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 1 + 1;},
      %{UPDATE "foo" SET "bar" = 1 + 1 WHERE "bar" IS NULL},
      %{ALTER TABLE "foo" ALTER "bar" SET NOT NULL},
    ], statements)
  end

  def test_change_column_without_expression
    Mig.change_column(:foo, :bar, :integer, :null => false, :default => 100)
    Mig.change_column(:foo, :bar, :integer, :null => true, :default => 100)

    assert_equal([
      %{ALTER TABLE "foo" ALTER COLUMN "bar" TYPE integer},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 100},
      %{ALTER TABLE "foo" ALTER "bar" SET NOT NULL},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" TYPE integer},
      %{ALTER TABLE "foo" ALTER COLUMN "bar" SET DEFAULT 100},
      %{ALTER TABLE "foo" ALTER "bar" DROP NOT NULL},
    ], statements)
  end

  def stub_copy_from
    if ARBC.raw_connection.respond_to?(:copy_data)
      ARBC.raw_connection.stub(:copy_data, proc { |sql|
        statements << sql
      }) do
        yield
      end
    else
      yield
    end
  end

  def test_copy_from
    stub_copy_from do
      Mig.copy_from(:foo, '/dev/null') rescue nil
      Mig.copy_from(:foo, '/dev/null', :columns => :name) rescue nil
      Mig.copy_from(:foo, '/dev/null', :columns => [ :name, :description ]) rescue nil
      Mig.copy_from(:foo, '/dev/null', :local => true) rescue nil
      Mig.copy_from(:foo, '/dev/null', :binary => true) rescue nil
      Mig.copy_from(:foo, '/dev/null', :csv => true) rescue nil
      Mig.copy_from(:foo, '/dev/null', :csv => { :header => true, :quote => '|', :escape => '&' }) rescue nil
      Mig.copy_from(:foo, '/dev/null', :local => false)
    end

    assert_equal([
      %{COPY "foo" FROM STDIN;},
      %{COPY "foo" ("name") FROM STDIN;},
      %{COPY "foo" ("name", "description") FROM STDIN;},
      %{COPY "foo" FROM STDIN;},
      %{COPY "foo" FROM STDIN BINARY;},
      %{COPY "foo" FROM STDIN CSV;},
      %{COPY "foo" FROM STDIN CSV HEADER QUOTE AS '|' ESCAPE AS '&';},
      %{COPY "foo" FROM '/dev/null';}
    ], statements)
  end

  def test_copy_from_with_freeze_option
    skip unless ActiveRecord::PostgreSQLExtensions::Features.copy_from_freeze?

    stub_copy_from do
      Mig.copy_from(:foo, '/dev/null', :freeze => true) rescue nil
    end

    assert_equal([
      %{COPY "foo" FROM STDIN FREEZE;}
    ], statements)
  end

  def test_copy_from_with_encoding_option
    skip unless ActiveRecord::PostgreSQLExtensions::Features.copy_from_encoding?

    stub_copy_from do
      Mig.copy_from(:foo, '/dev/null', :encoding => 'UTF-8') rescue nil
    end

    assert_equal([
      %{COPY "foo" FROM STDIN ENCODING 'UTF-8';}
    ], statements)
  end

  def test_copy_from_program
    skip unless ActiveRecord::PostgreSQLExtensions::Features.copy_from_program?

    Mig.copy_from(:foo, 'cat /dev/null', :program => true) rescue nil

    assert_equal([
      %{COPY "foo" FROM PROGRAM 'cat /dev/null';}
    ], statements)
  end

  def test_cluster_all
    ARBC.cluster_all
    ARBC.cluster_all(:verbose => true)

    assert_equal([
      %{CLUSTER;},
      %{CLUSTER VERBOSE;}
    ], statements)
  end


  def test_cluster_table
    Mig.cluster(:foo)
    Mig.cluster(:foo, :verbose => true)
    Mig.cluster(:foo, :using => "bar_idx")
    ARBC.cluster(:foo => :bar)

    assert_equal([
      %{CLUSTER "foo";},
      %{CLUSTER VERBOSE "foo";},
      %{CLUSTER "foo" USING "bar_idx";},
      %{CLUSTER "foo"."bar";}
    ], statements)
  end

  def test_extract_schema_name
    assert_equal("foo", ARBC.extract_schema_name(:foo => :bar))
    assert_equal("foo", ARBC.extract_schema_name(%{foo.bar}))
    assert_equal("foo", ARBC.extract_schema_name(%{"foo"."bar"}))
    assert_nil(ARBC.extract_schema_name(%{"bar"}))
  end

  def test_extract_table_name
    assert_equal("bar", ARBC.extract_table_name(:foo => :bar))
    assert_equal("bar", ARBC.extract_table_name(%{foo.bar}))
    assert_equal("bar", ARBC.extract_table_name(%{"foo"."bar"}))
  end

  def test_extract_schema_and_table_names
    assert_equal([ "foo", "bar" ], ARBC.extract_schema_and_table_names(:foo => :bar))
    assert_equal([ "foo", "bar" ], ARBC.extract_schema_and_table_names(%{foo.bar}))
    assert_equal([ "foo", "bar" ], ARBC.extract_schema_and_table_names(%{"foo"."bar"}))
    assert_equal([ nil, "bar" ], ARBC.extract_schema_and_table_names(%{"bar"}))
  end
end
