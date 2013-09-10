
$: << File.dirname(__FILE__)
require 'test_helper'

class ConstraintTests < PostgreSQLExtensionsTestCase
  def setup
    clear_statements!
  end

  def test_create_table_with_unique_constraint_on_table
    Mig.create_table(:foo) do |t|
      t.integer :bar_id
      t.text :name
      t.text :email
      t.unique_constraint [ :id, :bar_id ]
      t.unique_constraint [ :name, :email ], :tablespace => 'fubar'
    end

    assert_equal(strip_heredoc(<<-SQL), statements[0])
      CREATE TABLE "foo" (
        "id" serial primary key,
        "bar_id" integer,
        "name" text,
        "email" text,
        UNIQUE ("id", "bar_id"),
        UNIQUE ("name", "email") USING INDEX TABLESPACE "fubar"
      );
    SQL
  end

  def test_create_table_with_unique_constraint_on_column
    Mig.create_table(:foo) do |t|
      t.integer :bar_id, :unique => true
    end

    assert_equal(strip_heredoc(<<-SQL), statements[0])
      CREATE TABLE "foo" (
        "id" serial primary key,
        "bar_id" integer,
        UNIQUE ("bar_id")
      );
    SQL
  end

  def test_add_unique_constraint
    Mig.add_unique_constraint(:foo, :bar_id)
    Mig.add_unique_constraint(
      :foo,
      :bar_id,
      :tablespace => 'fubar',
      :storage_parameters => 'FILLFACTOR=10',
      :name => 'bar_id_unique'
    )

    assert_equal([
      %{ALTER TABLE "foo" ADD UNIQUE ("bar_id");},
      %{ALTER TABLE "foo" ADD CONSTRAINT "bar_id_unique" UNIQUE ("bar_id") WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar";}
    ], statements)
  end

  def test_foreign_key_in_column_definition
    Mig.create_table('foo') do |t|
      t.integer :foo_id, :references => {
        :table => :foo,
        :on_delete => :set_null,
        :on_update => :cascade
      }

      t.integer :bar_id, :references => :bar

      t.integer :baz_id, :references => [ :baz ]
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "foo_id" integer,
        "bar_id" integer,
        "baz_id" integer,
        FOREIGN KEY ("foo_id") REFERENCES "foo" ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY ("bar_id") REFERENCES "bar",
        FOREIGN KEY ("baz_id") REFERENCES "baz"
      );
    SQL
  end

  def test_foreign_key_in_table_definition
    Mig.create_table('foo') do |t|
      t.integer :schabba_id
      t.integer :doo_id

      t.foreign_key :schabba_id, :bar
      t.foreign_key :doo_id, :baz
      t.foreign_key [ :schabba_id, :doo_id ], :bar, [ :schabba_id, :doo_id ]
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "schabba_id" integer,
        "doo_id" integer,
        FOREIGN KEY ("schabba_id") REFERENCES "bar",
        FOREIGN KEY ("doo_id") REFERENCES "baz",
        FOREIGN KEY ("schabba_id", "doo_id") REFERENCES "bar" ("schabba_id", "doo_id")
      );
    SQL
  end

  def test_add_foreign_key
    Mig.add_foreign_key(:foo, :bar_id, :bar)
    Mig.add_foreign_key(:foo, :bar_id, :bar, :ogc_fid, :name => 'bar_fk')
    Mig.add_foreign_key(:foo, [ :one_id, :bar_id ], :bar, [ :one_id, :bar_id ], :match => 'full')
    Mig.add_foreign_key(:foo, :bar_id, :bar, :on_delete => :cascade, :on_delete => :set_default)
    Mig.add_foreign_key(:foo, :bar_id, :bar, :deferrable => :immediate)

    assert_equal([
      %{ALTER TABLE "foo" ADD FOREIGN KEY ("bar_id") REFERENCES "bar";},
      %{ALTER TABLE "foo" ADD CONSTRAINT "bar_fk" FOREIGN KEY ("bar_id") REFERENCES "bar" ("ogc_fid");},
      %{ALTER TABLE "foo" ADD FOREIGN KEY ("one_id", "bar_id") REFERENCES "bar" ("one_id", "bar_id") MATCH FULL;},
      %{ALTER TABLE "foo" ADD FOREIGN KEY ("bar_id") REFERENCES "bar" ON DELETE SET DEFAULT;},
      %{ALTER TABLE "foo" ADD FOREIGN KEY ("bar_id") REFERENCES "bar" DEFERRABLE INITIALLY IMMEDIATE;}
    ], statements)
  end

  def test_drop_constraint
    Mig.drop_constraint(:foo, :bar)
    Mig.drop_constraint(:foo, :bar, :cascade => true)

    assert_equal([
      %{ALTER TABLE "foo" DROP CONSTRAINT "bar";},
      %{ALTER TABLE "foo" DROP CONSTRAINT "bar" CASCADE;}
    ], statements)
  end

  def test_check_constraint_in_column_definition
    Mig.create_table('foo') do |t|
      t.integer :foo_id, :check => "foo_id != 1"
      t.integer :bar_id, :check => { :expression => "bar_id != 1", :name => "bar_id_not_1" }
      t.integer :baz_id, :check => [ "baz_id != 1", {
        :expression => "baz_id > 10",
        :name => "baz_id_gt_10"
      } ]
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements )
      CREATE TABLE "foo" (
        "id" serial primary key,
        "foo_id" integer,
        "bar_id" integer,
        "baz_id" integer,
        CHECK (foo_id != 1),
        CONSTRAINT "bar_id_not_1" CHECK (bar_id != 1),
        CHECK (baz_id != 1),
        CONSTRAINT "baz_id_gt_10" CHECK (baz_id > 10)
      );
    SQL
  end

  def test_check_constraint_in_table_definition
    Mig.create_table('foo') do |t|
      t.integer :foo_id
      t.integer :bar_id
      t.integer :baz_id

      t.check_constraint "foo_id != 1"
      t.check_constraint "bar_id != 1", :name => "bar_id_not_1"
      t.check_constraint "baz_id != 1"
      t.check_constraint "baz_id > 10", {
        :name => "baz_id_gt_10"
      }
    end

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE TABLE "foo" (
        "id" serial primary key,
        "foo_id" integer,
        "bar_id" integer,
        "baz_id" integer,
        CHECK (foo_id != 1),
        CONSTRAINT "bar_id_not_1" CHECK (bar_id != 1),
        CHECK (baz_id != 1),
        CONSTRAINT "baz_id_gt_10" CHECK (baz_id > 10)
      );
    SQL
  end

  def test_add_check_constraint
    Mig.add_check_constraint(:foo, 'length(name) < 100')
    Mig.add_check_constraint(:foo, 'length(name) < 100', :name => 'name_length_check')

    assert_equal([
      %{ALTER TABLE "foo" ADD CHECK (length(name) < 100);},
      %{ALTER TABLE "foo" ADD CONSTRAINT "name_length_check" CHECK (length(name) < 100);}
    ], statements)
  end

  def test_add_exclude_constraint
    Mig.add_exclude_constraint(:foo, :element => 'length(name)', :with => '=')

    Mig.add_exclude_constraint(:foo, {
      :element => 'length(name)',
      :with => '='
    }, {
      :name => 'exclude_name_length'
    })

    Mig.add_exclude_constraint(:foo, {
      :element => 'length(name)',
      :with => '='
    }, {
      :name => 'exclude_name_length',
      :using => :gist
    })

    Mig.add_exclude_constraint(:foo, [{
      :element => 'length(name)',
      :with => '='
    }, {
      :element => 'length(title)',
      :with => '='
    }])

    Mig.add_exclude_constraint(:foo, {
      :element => 'length(name)',
      :with => '='
    }, {
      :conditions => Foo.send(:sanitize_sql, {
        :id => [1,2,3,4]
      })
    })

    Mig.add_exclude_constraint(:foo, {
      :element => 'length(name)',
      :with => '='
    }, {
      :tablespace => 'fubar',
      :index_parameters => 'FILLFACTOR=10'
    })

    escaped_array = if ActiveRecord::VERSION::STRING >= "3.0"
      "(1, 2, 3, 4)"
    else
      "(1,2,3,4)"
    end

    assert_equal([
      %{ALTER TABLE "foo" ADD EXCLUDE (length(name) WITH =);},
      %{ALTER TABLE "foo" ADD CONSTRAINT "exclude_name_length" EXCLUDE (length(name) WITH =);},
      %{ALTER TABLE "foo" ADD CONSTRAINT "exclude_name_length" EXCLUDE USING "gist" (length(name) WITH =);},
      %{ALTER TABLE "foo" ADD EXCLUDE (length(name) WITH =, length(title) WITH =);},
      %{ALTER TABLE "foo" ADD EXCLUDE (length(name) WITH =) WHERE ("foos"."id" IN #{escaped_array});},
      %{ALTER TABLE "foo" ADD EXCLUDE (length(name) WITH =) WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar";}
    ], statements)
  end

  def test_primary_key_in_column_definition
    Mig.create_table('foo', :id => false) do |t|
      t.integer :foo_id, :primary_key => true
    end

    Mig.create_table('foo', :id => false) do |t|
      t.integer :foo_id, :primary_key => {
        :tablespace => 'fubar',
        :index_parameters => 'FILLFACTOR=10'
      }
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "foo_id" integer,
        PRIMARY KEY ("foo_id")
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "foo_id" integer,
        PRIMARY KEY ("foo_id") WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar"
      );
    SQL

    assert_equal(expected, statements)
  end


  def test_primary_key_in_table_definition
    Mig.create_table('foo', :id => false) do |t|
      t.integer :foo_id
      t.primary_key_constraint :foo_id
    end

    Mig.create_table('foo', :id => false) do |t|
      t.integer :foo_id
      t.primary_key_constraint :foo_id, {
        :tablespace => 'fubar',
        :index_parameters => 'FILLFACTOR=10'
      }
    end

    Mig.create_table('foo', :id => false) do |t|
      t.integer :foo_id
      t.integer :bar_id
      t.primary_key_constraint [ :foo_id, :bar_id ], {
        :tablespace => 'fubar',
        :index_parameters => 'FILLFACTOR=10'
      }
    end

    expected = []

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "foo_id" integer,
        PRIMARY KEY ("foo_id")
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "foo_id" integer,
        PRIMARY KEY ("foo_id") WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar"
      );
    SQL

    expected << strip_heredoc(<<-SQL)
      CREATE TABLE "foo" (
        "foo_id" integer,
        "bar_id" integer,
        PRIMARY KEY ("foo_id", "bar_id") WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar"
      );
    SQL

    assert_equal(expected, statements)
  end

  def test_add_primary_key
    Mig.add_primary_key(:foo, :bar_id)
    Mig.add_primary_key(:foo, [ :bar_id, :baz_id ])
    Mig.add_primary_key(:foo, :bar_id, :name => 'foo_pk')
    Mig.add_primary_key(:foo, :bar_id, :tablespace => 'fubar', :index_parameters => 'FILLFACTOR=10')

    assert_equal([
      %{ALTER TABLE "foo" ADD PRIMARY KEY ("bar_id");},
      %{ALTER TABLE "foo" ADD PRIMARY KEY ("bar_id", "baz_id");},
      %{ALTER TABLE "foo" ADD CONSTRAINT "foo_pk" PRIMARY KEY ("bar_id");},
      %{ALTER TABLE "foo" ADD PRIMARY KEY ("bar_id") WITH (FILLFACTOR=10) USING INDEX TABLESPACE "fubar";}
    ], statements)
  end

  def test_not_valid
    Mig.add_check_constraint(:foo, 'length(name) < 100', :not_valid => true)
    Mig.add_foreign_key(:foo, :bar_id, :bar, :not_valid => true)

    assert_equal([
      %{ALTER TABLE "foo" ADD CHECK (length(name) < 100) NOT VALID;},
      %{ALTER TABLE "foo" ADD FOREIGN KEY ("bar_id") REFERENCES "bar" NOT VALID;}
    ], statements)
  end

  def test_validate_constraint
    Mig.validate_constraint(:foo, :foo_constraint)

    assert_equal([
      %{ALTER TABLE "foo" VALIDATE CONSTRAINT "foo_constraint";}
    ], statements)
  end

  def test_no_inherit
    Mig.add_check_constraint(:foo, 'length(name) < 100', :no_inherit => true)

    assert_equal([
      %{ALTER TABLE "foo" ADD CHECK (length(name) < 100) NO INHERIT;},
    ], statements)
  end
end
