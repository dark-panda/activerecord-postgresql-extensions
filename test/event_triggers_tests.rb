
$: << File.dirname(__FILE__)
require 'test_helper'

class EventTriggerTests < PostgreSQLExtensionsTestCase
  def skip_unless_supported
    skip unless ActiveRecord::PostgreSQLExtensions::Features.event_triggers?
  end

  def test_create_event_trigger
    skip_unless_supported

    Mig.create_event_trigger(:foo_trg, :ddl_command_start, :foo_trg_function)

    assert_equal([
      %{CREATE EVENT TRIGGER "foo_trg" ON "ddl_command_start" EXECUTE PROCEDURE "foo_trg_function"();}
    ], statements)
  end

  def test_create_event_trigger_bad_event
    skip_unless_supported

    assert_raises(ActiveRecord::InvalidEventTriggerEventType) do
      Mig.create_event_trigger(:foo_trg, :blort, :foo_trg_function)
    end
  end

  def test_create_event_trigger_with_when_option
    skip_unless_supported

    Mig.create_event_trigger(:foo_trg, :ddl_command_start, :foo_trg_function,
      :when => {
        :tag => 'CREATE TABLE',
        :toplevel => 'FOOS'
      }
    )

    assert_equal([ strip_heredoc(<<-SQL) ], statements)
      CREATE EVENT TRIGGER "foo_trg" ON "ddl_command_start"
        WHEN "tag" IN ('CREATE TABLE')
        AND "toplevel" IN ('FOOS')
        EXECUTE PROCEDURE "foo_trg_function"();
    SQL
  end

  def test_drop_event_trigger
    skip_unless_supported

    ARBC.drop_event_trigger(:foo)
    ARBC.drop_event_trigger(:foo, :if_exists => true, :cascade => true)

    assert_equal([
      %{DROP EVENT TRIGGER "foo";},
      %{DROP EVENT TRIGGER IF EXISTS "foo" CASCADE;}
    ], statements)
  end

  def test_rename_event_trigger
    skip_unless_supported

    ARBC.rename_event_trigger(:foo, :bar)

    assert_equal([
      %{ALTER EVENT TRIGGER "foo" RENAME TO "bar";}
    ], statements)
  end

  def test_alter_event_trigger_owner
    skip_unless_supported

    ARBC.alter_event_trigger_owner(:foo, :bar)

    assert_equal([
      %{ALTER EVENT TRIGGER "foo" OWNER TO "bar";}
    ], statements)
  end

  def test_enable_event_trigger
    skip_unless_supported

    ARBC.enable_event_trigger(:foo)
    ARBC.enable_event_trigger(:foo, :always => true)
    ARBC.enable_event_trigger(:foo, :replica => true)

    assert_equal([
      %{ALTER EVENT TRIGGER "foo" ENABLE;},
      %{ALTER EVENT TRIGGER "foo" ENABLE ALWAYS;},
      %{ALTER EVENT TRIGGER "foo" ENABLE REPLICA;}
    ], statements)
  end

  def test_enable_event_trigger_with_replica_and_always
    skip_unless_supported

    assert_raises(ArgumentError) do
      ARBC.enable_event_trigger(:foo, :always => true, :replica => true)
    end
  end

  def test_disable_event_trigger
    skip_unless_supported

    ARBC.disable_event_trigger(:foo)

    assert_equal([
      %{ALTER EVENT TRIGGER "foo" DISABLE;}
    ], statements)
  end
end
