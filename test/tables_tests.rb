
$: << File.dirname(__FILE__)
require 'test_helper'

class TablesTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_default_with_expression
    Mig.create_table('foo') do |t|
      t.integer :foo_id, :default => { :expression => '10 + 20' }
      t.integer :bar_id, :default => '20 + 10'
    end

    if ActiveRecord::VERSION::STRING >= "3.2"
      assert_equal([
      %{CREATE TABLE "foo" (
  "id" serial primary key,
  "foo_id" integer DEFAULT 10 + 20,
  "bar_id" integer DEFAULT 20
);} ], statements)
    else
      assert_equal([
      %{CREATE TABLE "foo" (
  "id" serial primary key,
  "foo_id" integer DEFAULT 10 + 20,
  "bar_id" integer DEFAULT '20 + 10'
);} ], statements)
    end
  end

  def test_like
    Mig.create_table('foo') do |t|
      t.like :bar,
        :including => %w{ constraints indexes},
        :excluding => %w{ storage comments }
    end

    assert_equal([
       %{CREATE TABLE "foo" (
  "id" serial primary key,
  LIKE "bar" INCLUDING CONSTRAINTS INCLUDING INDEXES EXCLUDING STORAGE EXCLUDING COMMENTS
);}
    ], statements)
  end

  def test_option_unlogged
    Mig.create_table('foo', :unlogged => true)

    assert_equal([
      %{CREATE UNLOGGED TABLE "foo" (\n  "id" serial primary key\n);}
    ], statements)
  end

  def test_option_temporary
    Mig.create_table('foo', :temporary => true)

    assert_equal([
      %{CREATE TEMPORARY TABLE "foo" (\n  "id" serial primary key\n);}
    ], statements)
  end

  def test_option_if_not_exists
    Mig.create_table('foo', :if_not_exists => true)

    assert_equal([
      %{CREATE TABLE IF NOT EXISTS "foo" (\n  "id" serial primary key\n);}
    ], statements)
  end

  def test_option_on_commit
    Mig.create_table('foo', :on_commit => :preserve_rows)
    Mig.create_table('foo', :on_commit => :delete_rows)
    Mig.create_table('foo', :on_commit => :drop)

    assert_equal([
      %{CREATE TABLE "foo" (\n  "id" serial primary key\n)\nON COMMIT PRESERVE ROWS;},
      %{CREATE TABLE "foo" (\n  "id" serial primary key\n)\nON COMMIT DELETE ROWS;},
      %{CREATE TABLE "foo" (\n  "id" serial primary key\n)\nON COMMIT DROP;}
    ], statements)
  end

  def test_option_inherits
    Mig.create_table('foo', :inherits => 'bar')

    assert_equal([
      %{CREATE TABLE "foo" (\n  "id" serial primary key\n)\nINHERITS ("bar");}
    ], statements)
  end

  def test_option_tablespace
    Mig.create_table('foo', :tablespace => 'bar')

    assert_equal([
      %{CREATE TABLE "foo" (\n  "id" serial primary key\n)\nTABLESPACE "bar";}
    ], statements)
  end

  def test_option_of_type
    Mig.create_table('foo', :of_type => 'bar')

    assert_equal([
      %{CREATE TABLE "foo" OF "bar";}
    ], statements)

    assert_raises(ArgumentError) do
      Mig.create_table('foo', :of_type => 'bar') do |t|
        t.integer :what
      end
    end

    assert_raises(ArgumentError) do
      Mig.create_table('foo', :of_type => 'bar', :like => :something)
    end

    assert_raises(ArgumentError) do
      Mig.create_table('foo', :of_type => 'bar', :inherits => :something)
    end
  end

  def test_exclude_constraint
    Mig.create_table('foo') do |t|
      t.text :blort
      t.exclude({
        :element => 'length(blort)',
        :with => '='
      }, {
        :name => 'exclude_blort_length'
      })
    end

    assert_equal([
      %{CREATE TABLE "foo" (\n  "id" serial primary key,\n  "blort" text,\n  CONSTRAINT "exclude_blort_length" EXCLUDE (length(blort) WITH =)\n);}
    ], statements)
  end
end
