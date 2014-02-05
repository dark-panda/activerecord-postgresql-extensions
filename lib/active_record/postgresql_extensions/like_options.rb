
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/postgresql_extensions/utils'

module ActiveRecord
  class InvalidLikeTypes < ActiveRecordError #:nodoc:
    def initialize(likes)
      super("Invalid LIKE INCLUDING/EXCLUDING types - #{likes.inspect}")
    end
  end

  class PostgreSQLExtensions::PostgreSQLLikeOptions
    attr_accessor :base, :parent_table, :options

    def initialize(base, parent_table, options = {})
      @base, @parent_table, @options = base, parent_table, options

      assert_valid_like_types(options[:includes])
      assert_valid_like_types(options[:excludes])
    end

    def to_sql
      # Huh? Whyfor I dun this?
      # @like = base.with_schema(@schema) { "LIKE #{base.quote_table_name(parent_table)}" }
      sql = "LIKE #{@base.quote_table_name(parent_table)}"

      if options[:including]
        sql << Array.wrap(options[:including]).collect { |l| " INCLUDING #{l.to_s.upcase}" }.join
      end

      if options[:excluding]
        sql << Array.wrap(options[:excluding]).collect { |l| " EXCLUDING #{l.to_s.upcase}" }.join
      end

      sql
    end
    alias :to_s :to_sql

    private
      LIKE_TYPES = %w{ defaults constraints indexes }.freeze

      def assert_valid_like_types(likes) #:nodoc:
        unless likes.blank?
          check_likes = Array.wrap(likes).collect(&:to_s) - LIKE_TYPES
          if !check_likes.empty?
            raise ActiveRecord::InvalidLikeTypes.new(check_likes)
          end
        end
      end
  end
end

