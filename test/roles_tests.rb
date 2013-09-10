
$: << File.dirname(__FILE__)
require 'test_helper'

class RolesTests < PostgreSQLExtensionsTestCase
  def test_create_role
    ARBC.create_role('foo')
    ARBC.create_role('foo', {
      :superuser => true,
      :create_db => true,
      :create_role => true,
      :inherit => false,
      :login => true,
      :connection_limit => 10,
      :password => 'testing',
      :encrypted_password => true,
      :valid_until => Date.parse('2011-10-12'),
      :in_role => 'bar',
      :role => 'baz',
      :admin => 'blort'
    })

    assert_equal([
      %{CREATE ROLE "foo";},
      %{CREATE ROLE "foo" SUPERUSER CREATEDB CREATEROLE NOINHERIT LOGIN CONNECTION LIMIT 10 ENCRYPTED PASSWORD 'testing' VALID UNTIL '2011-10-12' IN ROLE "bar" ROLE "baz" ADMIN "blort";}
    ], statements)
  end

  def test_alter_role
    ARBC.alter_role('foo', {
      :superuser => true,
      :create_db => true,
      :create_role => true,
      :inherit => false,
      :login => true,
      :connection_limit => 10,
      :password => 'testing',
      :encrypted_password => true,
      :valid_until => Date.parse('2011-10-12'),
      :in_role => 'bar',
      :role => 'baz',
      :admin => 'blort'
    })

    assert_equal([
      %{ALTER ROLE "foo" SUPERUSER CREATEDB CREATEROLE NOINHERIT LOGIN CONNECTION LIMIT 10 ENCRYPTED PASSWORD 'testing' VALID UNTIL '2011-10-12' IN ROLE "bar" ROLE "baz" ADMIN "blort";}
    ], statements)
  end

  def test_drop_role
    ARBC.drop_role('foo')
    ARBC.drop_role(%w{ foo bar baz })
    ARBC.drop_role(%w{ foo bar baz }, :if_exists => true)

    assert_equal([
      %{DROP ROLE "foo";},
      %{DROP ROLE "foo", "bar", "baz";},
      %{DROP ROLE IF EXISTS "foo", "bar", "baz";}
    ], statements)
  end
end
