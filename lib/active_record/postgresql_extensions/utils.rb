
module ActiveRecord
  module PostgreSQLExtensions
    module Utils
      def hash_or_array_of_hashes(arg)
        case arg
          when Hash
            [ arg ]
          when Array
            if arg.detect { |e| !e.is_a?(Hash) }
              raise ArgumentError.new("Expected an Array of Hashes")
            else
              arg
            end
          else
            raise ArgumentError.new("Expected either a Hash or an Array of Hashes")
        end
      end

      def strip_heredoc(str)
        indent = str.scan(/^[ \t]*(?=\S)/).min.try(:size) || 0
        str.gsub(/^[ \t]{#{indent}}/, '').strip
      end

      class << self
        include Utils
      end
    end
  end
end
