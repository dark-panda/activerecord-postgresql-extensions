module ActiveRecord
  class Migration
    class << self
      def method_missing(name, *args, &block)
        if name == :add_foreign_key
          args[1], args[2] = args[2], args[1]
        end

        (delegate || superclass.delegate).send(name, *args, &block)
      end
    end
  end
end
