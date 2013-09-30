
$: << File.dirname(__FILE__)
require 'test_helper'

class TypesTests < PostgreSQLExtensionsTestCase
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

  class EnumTests < PostgreSQLExtensionsTestCase
    def setup
      ARBC.real_execute do
        Mig.drop_type(:foo_enum, :if_exists => true)
      end

      super
    end

    def test_create_enum
      Mig.create_enum(:foo_enum)
      Mig.create_enum(:foo_enum, %w{ one two three })
      Mig.create_enum(:foo_enum, :one, :two, :three)

      assert_equal([
        %{CREATE TYPE "foo_enum" AS ENUM ();},
        %{CREATE TYPE "foo_enum" AS ENUM ('one', 'two', 'three');},
        %{CREATE TYPE "foo_enum" AS ENUM ('one', 'two', 'three');}
      ], statements)
    end

    def test_add_enum_value
      Mig.create_enum(:foo_enum)
      Mig.add_enum_value(:foo_enum, :foo)
      Mig.add_enum_value(:foo_enum, :bar, :before => :foo)
      Mig.add_enum_value(:foo_enum, :blort, :after => :foo)

      assert_equal([
        %{CREATE TYPE "foo_enum" AS ENUM ();},
        %{ALTER TYPE "foo_enum" ADD VALUE 'foo';},
        %{ALTER TYPE "foo_enum" ADD VALUE 'bar' BEFORE 'foo';},
        %{ALTER TYPE "foo_enum" ADD VALUE 'blort' AFTER 'foo';}
      ], statements)
    end

    def test_add_enum_value_if_not_exists
      skip unless ActiveRecord::PostgreSQLExtensions.SERVER_VERSION >= '9.3'

      Mig.add_enum_value(:foo_enum, :baz, :if_not_exists => true)

      assert_equal([
        %{ALTER TYPE "foo_enum" ADD VALUE IF NOT EXISTS 'baz';}
      ], statements)
    end

    def test_drop_type
      Mig.drop_type(:foo_enum)
      Mig.drop_type(:foo_enum, :if_exists => true)
      Mig.drop_type(:foo_enum, :cascade => true)
      Mig.drop_type(:foo_enum, :bar_enum)

      assert_equal([
        %{DROP TYPE "foo_enum";},
        %{DROP TYPE IF EXISTS "foo_enum";},
        %{DROP TYPE "foo_enum" CASCADE;},
        %{DROP TYPE "foo_enum", "bar_enum";}
      ], statements)
    end

    def test_enum_values
      ARBC.real_execute do
        Mig.create_enum(:foo_enum, :one, :two, :three)

        assert_equal(%w{ one two three }, ARBC.enum_values(:foo_enum))
      end
    end

    def test_both_before_and_after_add_enum_value
      assert_raises(ActiveRecord::InvalidAddEnumValueOptions) do
        Mig.add_enum_value(:foo_enum, :blort, :after => :foo, :before => :bar)
      end
    end
  end
end
