
$: << File.dirname(__FILE__)
require 'test_helper'

class RulesTests < MiniTest::Unit::TestCase
  include PostgreSQLExtensionsTestHelper

  def test_create_rule
    ARBC.create_rule(
      :ignore_root, :update, :foos, :instead, :nothing, :conditions => 'user_id = 0'
    )
    ARBC.create_rule(
      :ignore_root, :update, :foos, :instead, 'SELECT * FROM non_admins', {
        :force => true,
        :conditions => 'user_id > 0'
      }
    )

    assert_equal([
      "CREATE RULE \"ignore_root\" AS ON UPDATE TO \"foos\" WHERE user_id = 0 DO INSTEAD NOTHING;",
      "CREATE  OR REPLACE RULE \"ignore_root\" AS ON UPDATE TO \"foos\" WHERE user_id > 0 DO INSTEAD SELECT * FROM non_admins;"
    ], statements)
  end

  def test_drop_rule
    ARBC.drop_rule(:foo, :bar)

    assert_equal([
      "DROP RULE \"foo\" ON \"bar\";",
    ], statements)
  end
end
