
require 'test/test_helper'

class RulesTests < Test::Unit::TestCase
	include PostgreSQLExtensionsTestHelper

	def test_create_rule
		Mig.create_rule(
			:ignore_root, :update, :users, :instead, :nothing, :conditions => 'user_id = 0'
		)
		Mig.create_rule(
			:ignore_root, :update, :users, :instead, 'SELECT * FROM non_admins', {
				:force => true,
				:conditions => 'user_id > 0'
			}
		)

		assert_equal([
			"CREATE RULE \"ignore_root\" AS ON UPDATE TO \"users\" WHERE user_id = 0 DO INSTEAD NOTHING",
			"CREATE  OR REPLACE RULE \"ignore_root\" AS ON UPDATE TO \"users\" WHERE user_id > 0 DO INSTEAD SELECT * FROM non_admins"
		], statements)
	end

	def test_drop_rule
		Mig.drop_rule(:foo, :bar)

		assert_equal([
			"DROP RULE \"foo\" ON \"bar\"",
		], statements)
	end
end
