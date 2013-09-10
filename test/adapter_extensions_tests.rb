
$: << File.dirname(__FILE__)
require 'test_helper'

class AdapterExtensionTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

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
    col = ActiveRecord::ConnectionAdapters::PostgreSQLColumn.new('vector', nil)
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
    ARBC.enable_triggers(:foo, :bar)
    ARBC.enable_triggers(:foo, :bar, :baz)

    assert_equal([
      %{ALTER TABLE "foo" ENABLE TRIGGER ALL;},
      %{ALTER TABLE "foo" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "bar";},
      %{ALTER TABLE "foo" ENABLE TRIGGER "baz";}
    ], statements)
  end

  def test_disable_triggers
    ARBC.disable_triggers(:foo)
    ARBC.disable_triggers(:foo, :bar)
    ARBC.disable_triggers(:foo, :bar, :baz)

    assert_equal([
      %{ALTER TABLE "foo" DISABLE TRIGGER ALL;},
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
end
