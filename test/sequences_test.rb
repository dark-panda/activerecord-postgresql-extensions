
require 'test/test_helper'

class SequenceTests < Test::Unit::TestCase
	include PostgreSQLExtensionsTestHelper

	def test_create_sequence
		Mig.create_sequence(
			'what_a_sequence_of_events',
			:start => 10
		)

		Mig.create_sequence(
			'what_a_sequence_of_events',
			:increment => 2,
			:cache => 2,
			:min_value => nil,
			:max_value => 10,
			:owned_by => [ :foo, :id ]
		)

		assert_equal([
			"CREATE SEQUENCE \"what_a_sequence_of_events\" START WITH 10",
			"CREATE SEQUENCE \"what_a_sequence_of_events\" INCREMENT BY 2 NO MINVALUE MAXVALUE 10 CACHE 2 OWNED BY \"foo\".\"id\""
		], statements)
	end

	def test_drop_sequence
		Mig.drop_sequence(
			:foo_id_seq,
			:if_exists => true,
			:cascade => true
		)

		assert_equal([
			"DROP SEQUENCE IF EXISTS \"foo_id_seq\" CASCADE"
		], statements)
	end

	def test_rename_sequence
		Mig.rename_sequence(:foo, :bar)

		assert_equal([
			'ALTER SEQUENCE "foo" RENAME TO "bar"'
		], statements)
	end

	def test_alter_sequence_schema
		Mig.alter_sequence_schema(:foo, :bar)
		Mig.alter_sequence_schema(:foo, :public)

		assert_equal([
			'ALTER SEQUENCE "foo" SET SCHEMA "bar"',
			'ALTER SEQUENCE "foo" SET SCHEMA PUBLIC',
		], statements)
	end

	def test_set_sequence_value
		Mig.set_sequence_value(:foo, 42)
		Mig.set_sequence_value(:foo, 42, :is_called => false)

		assert_equal([
			"SELECT setval('foo', 42, true)",
			"SELECT setval('foo', 42, false)"
		], statements)
	end

	def test_create_sequence
		Mig.alter_sequence(
			'what_a_sequence_of_events',
			:restart_with => 10
		)

		Mig.alter_sequence(
			'what_a_sequence_of_events',
			:start => 10,
			:increment => 2,
			:cache => 2,
			:min_value => nil,
			:max_value => 10,
			:owned_by => [ :foo, :id ]
		)

		assert_equal([
			"ALTER SEQUENCE \"what_a_sequence_of_events\" RESTART WITH 10",
			"ALTER SEQUENCE \"what_a_sequence_of_events\" INCREMENT BY 2 NO MINVALUE MAXVALUE 10 START WITH 10 CACHE 2 OWNED BY \"foo\".\"id\""
		], statements)
	end
end
