
$: << File.dirname(__FILE__)
require 'test_helper'

class PermissionsTests < PostgreSQLExtensionsTestCase
  def test_grant_table_privileges
    Mig.grant_table_privileges(:foo, :select, :nobody)
    Mig.grant_table_privileges(:foo, [ :select, :update, :delete, :insert ], [ :nobody, :somebody ])
    Mig.grant_table_privileges(:foo, :select, :nobody, :with_grant_option => true)
    Mig.grant_table_privileges(:foo, :select, :nobody, :cascade => true)
    Mig.grant_table_privileges(:foo, :select, :public, :cascade => true)

    assert_equal([
      %{GRANT SELECT ON TABLE "foo" TO "nobody";},
      %{GRANT SELECT, UPDATE, DELETE, INSERT ON TABLE "foo" TO "nobody", "somebody";},
      %{GRANT SELECT ON TABLE "foo" TO "nobody" WITH GRANT OPTION;},
      %{GRANT SELECT ON TABLE "foo" TO "nobody";},
      %{GRANT SELECT ON TABLE "foo" TO PUBLIC;}
    ], statements)
  end

  def test_grant_table_privileges_all
    skip unless ActiveRecord::PostgreSQLExtensions::Features.modify_mass_privileges?

    Mig.grant_table_privileges(:foo, :select, :nobody, :all => true)

    assert_equal([
      %{GRANT SELECT ON ALL TABLES IN SCHEMA "foo" TO "nobody";}
    ], statements)
  end

  def test_revoke_table_privileges
    Mig.revoke_table_privileges(:foo, :select, :nobody)
    Mig.revoke_table_privileges(:foo, [ :select, :update, :delete, :insert ], [ :nobody, :somebody ])
    Mig.revoke_table_privileges(:foo, :select, :nobody, :with_grant_option => true)
    Mig.revoke_table_privileges(:foo, :select, :nobody, :cascade => true)
    Mig.revoke_table_privileges(:foo, :select, :public, :cascade => true)

    assert_equal([
      %{REVOKE SELECT ON TABLE "foo" FROM "nobody";},
      %{REVOKE SELECT, UPDATE, DELETE, INSERT ON TABLE "foo" FROM "nobody", "somebody";},
      %{REVOKE SELECT ON TABLE "foo" FROM "nobody";},
      %{REVOKE SELECT ON TABLE "foo" FROM "nobody" CASCADE;},
      %{REVOKE SELECT ON TABLE "foo" FROM PUBLIC CASCADE;}
    ], statements)
  end

  def test_revoke_table_privileges_all
    skip unless ActiveRecord::PostgreSQLExtensions::Features.modify_mass_privileges?

    Mig.revoke_table_privileges(:foo, :select, :nobody, :all => true)

    assert_equal([
      %{REVOKE SELECT ON ALL TABLES IN SCHEMA "foo" FROM "nobody";}
    ], statements)
  end

  def test_grant_view_privileges
    Mig.grant_view_privileges(:foo, :select, :nobody)
    Mig.grant_view_privileges(:foo, [ :select, :update, :delete, :insert ], [ :nobody, :somebody ])
    Mig.grant_view_privileges(:foo, :select, :nobody, :with_grant_option => true)
    Mig.grant_view_privileges(:foo, :select, :nobody, :cascade => true)
    Mig.grant_view_privileges(:foo, :select, :public, :cascade => true)

    assert_equal([
      %{GRANT SELECT ON "foo" TO "nobody";},
      %{GRANT SELECT, UPDATE, DELETE, INSERT ON "foo" TO "nobody", "somebody";},
      %{GRANT SELECT ON "foo" TO "nobody" WITH GRANT OPTION;},
      %{GRANT SELECT ON "foo" TO "nobody";},
      %{GRANT SELECT ON "foo" TO PUBLIC;}
    ], statements)
  end

  def test_revoke_view_privileges
    Mig.revoke_view_privileges(:foo, :select, :nobody)
    Mig.revoke_view_privileges(:foo, [ :select, :update, :delete, :insert ], [ :nobody, :somebody ])
    Mig.revoke_view_privileges(:foo, :select, :nobody, :with_grant_option => true)
    Mig.revoke_view_privileges(:foo, :select, :nobody, :cascade => true)
    Mig.revoke_view_privileges(:foo, :select, :public, :cascade => true)

    assert_equal([
      %{REVOKE SELECT ON "foo" FROM "nobody";},
      %{REVOKE SELECT, UPDATE, DELETE, INSERT ON "foo" FROM "nobody", "somebody";},
      %{REVOKE SELECT ON "foo" FROM "nobody";},
      %{REVOKE SELECT ON "foo" FROM "nobody" CASCADE;},
      %{REVOKE SELECT ON "foo" FROM PUBLIC CASCADE;},
    ], statements)
  end

  def test_grant_sequence_privileges
    Mig.grant_sequence_privileges(:foo, :select, :nobody)
    Mig.grant_sequence_privileges(:foo, [ :select, :update ], [ :nobody, :somebody ])

    assert_equal([
      %{GRANT SELECT ON SEQUENCE "foo" TO "nobody";},
      %{GRANT SELECT, UPDATE ON SEQUENCE "foo" TO "nobody", "somebody";}
    ], statements)
  end

  def test_grant_sequence_privileges_all
    skip unless ActiveRecord::PostgreSQLExtensions::Features.modify_mass_privileges?

    Mig.grant_sequence_privileges(:foo, :select, :nobody, :all => true)

    assert_equal([
      %{GRANT SELECT ON ALL SEQUENCES IN SCHEMA "foo" TO "nobody";}
    ], statements)
  end

  def test_revoke_sequence_privileges
    Mig.revoke_sequence_privileges(:foo, :select, :nobody)
    Mig.revoke_sequence_privileges(:foo, [ :select, :update ], [ :nobody, :somebody ])

    assert_equal([
      %{REVOKE SELECT ON SEQUENCE "foo" FROM "nobody";},
      %{REVOKE SELECT, UPDATE ON SEQUENCE "foo" FROM "nobody", "somebody";}
    ], statements)
  end

  def test_revoke_sequence_privileges_all
    skip unless ActiveRecord::PostgreSQLExtensions::Features.modify_mass_privileges?

    Mig.revoke_sequence_privileges(:foo, :select, :nobody, :all => true)

    assert_equal([
      %{REVOKE SELECT ON ALL SEQUENCES IN SCHEMA "foo" FROM "nobody";}
    ], statements)
  end

  def test_grant_function_privileges
    Mig.grant_function_privileges('test(text, integer)', :execute, :nobody)
    Mig.grant_function_privileges('test(text, integer)', :all, [ :nobody, :somebody ])

    assert_equal([
      %{GRANT EXECUTE ON FUNCTION test(text, integer) TO "nobody";},
      %{GRANT ALL ON FUNCTION test(text, integer) TO "nobody", "somebody";}
    ], statements)
  end

  def test_grant_function_privileges_all
    skip unless ActiveRecord::PostgreSQLExtensions::Features.modify_mass_privileges?

    Mig.grant_function_privileges(:foo, :execute, :nobody, :all => true)

    assert_equal([
      %{GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA "foo" TO "nobody";}
    ], statements)
  end

  def test_revoke_function_privileges
    Mig.revoke_function_privileges('test(text, integer)', :execute, :nobody)
    Mig.revoke_function_privileges('test(text, integer)', :all, [ :nobody, :somebody ])

    assert_equal([
      %{REVOKE EXECUTE ON FUNCTION test(text, integer) FROM "nobody";},
      %{REVOKE ALL ON FUNCTION test(text, integer) FROM "nobody", "somebody";}
    ], statements)
  end

  def test_revoke_function_privileges_all
    skip unless ActiveRecord::PostgreSQLExtensions::Features.modify_mass_privileges?

    Mig.revoke_function_privileges(:foo, :execute, :nobody, :all => true)

    assert_equal([
      %{REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA "foo" FROM "nobody";}
    ], statements)
  end

  def test_grant_language_privileges
    Mig.grant_language_privileges('plpgsql', :usage, :nobody)
    Mig.grant_language_privileges('plpgsql', :all, [ :nobody, :somebody ])

    assert_equal([
      %{GRANT USAGE ON LANGUAGE "plpgsql" TO "nobody";},
      %{GRANT ALL ON LANGUAGE "plpgsql" TO "nobody", "somebody";}
    ], statements)
  end

  def test_revoke_language_privileges
    Mig.revoke_language_privileges('plpgsql', :usage, :nobody)
    Mig.revoke_language_privileges('plpgsql', :all, [ :nobody, :somebody ])

    assert_equal([
      %{REVOKE USAGE ON LANGUAGE "plpgsql" FROM "nobody";},
      %{REVOKE ALL ON LANGUAGE "plpgsql" FROM "nobody", "somebody";}
    ], statements)
  end

  def test_grant_schema_privileges
    Mig.grant_schema_privileges(:foo, :usage, :nobody)
    Mig.grant_schema_privileges(:foo, :all, [ :nobody, :somebody ])

    assert_equal([
      %{GRANT USAGE ON SCHEMA "foo" TO "nobody";},
      %{GRANT ALL ON SCHEMA "foo" TO "nobody", "somebody";}
    ], statements)
  end

  def test_revoke_schema_privileges
    Mig.revoke_schema_privileges(:foo, :usage, :nobody)
    Mig.revoke_schema_privileges(:foo, :all, [ :nobody, :somebody ])

    assert_equal([
      %{REVOKE USAGE ON SCHEMA "foo" FROM "nobody";},
      %{REVOKE ALL ON SCHEMA "foo" FROM "nobody", "somebody";}
    ], statements)
  end

  def test_grant_tablespace_privileges
    Mig.grant_tablespace_privileges(:foo, :create, :nobody)
    Mig.grant_tablespace_privileges(:foo, :all, [ :nobody, :somebody ])

    assert_equal([
      %{GRANT CREATE ON TABLESPACE "foo" TO "nobody";},
      %{GRANT ALL ON TABLESPACE "foo" TO "nobody", "somebody";}
    ], statements)
  end

  def test_revoke_tablespace_privileges
    Mig.revoke_tablespace_privileges(:foo, :create, :nobody)
    Mig.revoke_tablespace_privileges(:foo, :all, [ :nobody, :somebody ])

    assert_equal([
      %{REVOKE CREATE ON TABLESPACE "foo" FROM "nobody";},
      %{REVOKE ALL ON TABLESPACE "foo" FROM "nobody", "somebody";}
    ], statements)
  end

  def test_grant_materialized_view_privileges
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.grant_materialized_view_privileges(:foo, :select, :nobody)
    Mig.grant_materialized_view_privileges(:foo, [ :select, :update, :delete, :insert ], [ :nobody, :somebody ])
    Mig.grant_materialized_view_privileges(:foo, :select, :nobody, :with_grant_option => true)
    Mig.grant_materialized_view_privileges(:foo, :select, :nobody, :cascade => true)
    Mig.grant_materialized_view_privileges(:foo, :select, :public, :cascade => true)

    assert_equal([
      %{GRANT SELECT ON "foo" TO "nobody";},
      %{GRANT SELECT, UPDATE, DELETE, INSERT ON "foo" TO "nobody", "somebody";},
      %{GRANT SELECT ON "foo" TO "nobody" WITH GRANT OPTION;},
      %{GRANT SELECT ON "foo" TO "nobody";},
      %{GRANT SELECT ON "foo" TO PUBLIC;}
    ], statements)
  end

  def test_revoke_materialized_view_privileges
    skip unless ActiveRecord::PostgreSQLExtensions::Features.materialized_views?

    Mig.revoke_materialized_view_privileges(:foo, :select, :nobody)
    Mig.revoke_materialized_view_privileges(:foo, [ :select, :update, :delete, :insert ], [ :nobody, :somebody ])
    Mig.revoke_materialized_view_privileges(:foo, :select, :nobody, :with_grant_option => true)
    Mig.revoke_materialized_view_privileges(:foo, :select, :nobody, :cascade => true)
    Mig.revoke_materialized_view_privileges(:foo, :select, :public, :cascade => true)

    assert_equal([
      %{REVOKE SELECT ON "foo" FROM "nobody";},
      %{REVOKE SELECT, UPDATE, DELETE, INSERT ON "foo" FROM "nobody", "somebody";},
      %{REVOKE SELECT ON "foo" FROM "nobody";},
      %{REVOKE SELECT ON "foo" FROM "nobody" CASCADE;},
      %{REVOKE SELECT ON "foo" FROM PUBLIC CASCADE;}
    ], statements)
  end

  def test_grant_role_membership
    Mig.grant_role_membership(:foo, :nobody)
    Mig.grant_role_membership(:foo, [ :nobody, :somebody ])
    Mig.grant_role_membership(:foo, [ :nobody, :somebody ], :with_admin_option => true)

    assert_equal([
      %{GRANT "foo" TO "nobody";},
      %{GRANT "foo" TO "nobody", "somebody";},
      %{GRANT "foo" TO "nobody", "somebody" WITH ADMIN OPTION;}
    ], statements)
  end

  def test_revoke_role_membership
    Mig.revoke_role_membership(:foo, :nobody)
    Mig.revoke_role_membership(:foo, [ :nobody, :somebody ])
    Mig.revoke_role_membership(:foo, [ :nobody, :somebody ], :with_admin_option => true)

    assert_equal([
      %{REVOKE "foo" FROM "nobody";},
      %{REVOKE "foo" FROM "nobody", "somebody";},
      %{REVOKE "foo" FROM "nobody", "somebody";}
    ], statements)
  end
end
