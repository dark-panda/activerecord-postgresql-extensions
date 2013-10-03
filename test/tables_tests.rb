
$: << File.dirname(__FILE__)
require 'test_helper'

class TablesTests < PostgreSQLExtensionsTestCase
  def test_default_with_expression
    Mig.create_table('foo') do |t|
      t.integer :foo_id, :default => { :expression => '10 + 20' }
      t.integer :bar_id, :default => '20 + 10'
    end

    if ActiveRecord::VERSION::STRING >= "3.2"
      assert_equal([ strip_heredoc(<<-SQL) ], statements)
        CREATE TABLE "foo" (
          "id" serial primary key,
          "foo_id" integer DEFAULT 10 + 20,
          "bar_id" integer DEFAULT 20
        );
      SQL
    else
      assert_equal([ strip_heredoc(<<-SQL) ], statements)
        CREATE TABLE "foo" (
          "id" serial primary key,
          "foo_id" integer DEFAULT 10 + 20,
          "bar_id" integer DEFAULT '20 + 10'
        );
      SQL
    end
  end

  def test_like
    Mig.create_table('foo') do |t|
      t.like :bar,
        :including => %w{ constraints indexes},
        :excluding => %w{ storage comments }
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
       CREATE TABLE "foo" (
        "id" serial primary key,
        LIKE "bar" INCLUDING CONSTRAINTS INCLUDING INDEXES EXCLUDING STORAGE EXCLUDING COMMENTS
      );
    SQL
  end

  def test_option_unlogged
    Mig.create_table('foo', :unlogged => true)

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE UNLOGGED TABLE "foo" (
        "id" serial primary key
      );
    SQL
  end

  def test_option_temporary
    Mig.create_table('foo', :temporary => true)

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TEMPORARY TABLE "foo" (
        "id" serial primary key
      );
    SQL
  end

  def test_option_if_not_exists
    skip unless ActiveRecord::PostgreSQLExtensions::Features.create_table_if_not_exists?

    Mig.create_table('foo', :if_not_exists => true)

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TABLE IF NOT EXISTS "foo" (
        "id" serial primary key
      );
    SQL
  end

  def test_option_on_commit
    Mig.create_table('foo', :on_commit => :preserve_rows)
    Mig.create_table('foo', :on_commit => :delete_rows)
    Mig.create_table('foo', :on_commit => :drop)

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key
      )
      ON COMMIT PRESERVE ROWS;
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key
      )
      ON COMMIT DELETE ROWS;
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "id" serial primary key
      )
      ON COMMIT DROP;
    SQL

    assert_equal(expected, statements)
  end

  def test_option_inherits
    Mig.create_table('foo', :inherits => 'bar')

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TABLE "foo" (
        "id" serial primary key
      )
      INHERITS ("bar");
    SQL
  end

  def test_option_tablespace
    Mig.create_table('foo', :tablespace => 'bar')

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TABLE "foo" (
        "id" serial primary key
      )
      TABLESPACE "bar";
    SQL
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

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "blort" text,
        CONSTRAINT "exclude_blort_length" EXCLUDE (length(blort) WITH =)
      );
    SQL
  end

  def test_index
    Mig.create_table('foo') do |t|
      t.text :blort
      t.index :foo_blort_idx, :blort, :using => :gist
      t.index :foo_blort_idx, :blort, :index_parameters => {
        :fillfactor => 10
      }
    end

    assert_equal([
      strip_heredoc(%{
        CREATE TABLE "foo" (
          "id" serial primary key,
          "blort" text
        );
      }),

      strip_heredoc(%{
        CREATE INDEX "foo_blort_idx" ON "foo" USING "gist"("blort");
      }),

      strip_heredoc(%{
        CREATE INDEX "foo_blort_idx" ON "foo"("blort") WITH ("fillfactor" = 10);
      })
    ], statements)
  end

  def test_storage_parameters
    Mig.create_table('foo', :storage_parameters => {
      :fillfactor => 10
    })

    Mig.create_table('foo', :storage_parameters => "FILLFACTOR=10")

    assert_equal([
      strip_heredoc(%{
        CREATE TABLE "foo" (
          "id" serial primary key
        )
        WITH ("fillfactor" = 10);
      }),

      strip_heredoc(%{
        CREATE TABLE "foo" (
          "id" serial primary key
        )
        WITH (FILLFACTOR=10);
      })
    ], statements)
  end
end
