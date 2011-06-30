
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  class InvalidGeometryType < ActiveRecordError #:nodoc:
    def initialize(type)
      super("Invalid PostGIS geometry type - #{type}")
    end
  end

  class InvalidGeometryDimensions < ActiveRecordError #:nodoc:
  end

  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      def native_database_types_with_geometry #:nodoc:
        native_database_types_without_geometry.merge({
          :geometry => { :name => 'geometry' }
        })
      end
      alias_method_chain :native_database_types, :geometry
    end

    class PostgreSQLTableDefinition < TableDefinition
      attr_reader :geometry_columns

      # This is a special geometry type for the PostGIS extension's
      # geometry data type. It is used in a table definition to define
      # a geometry column.
      #
      # Essentially this method works like a wrapper around the PostGIS
      # AddGeometryColumn function. It can create the geometry column,
      # add CHECK constraints and create a GiST index on the column
      # all in one go.
      #
      # ==== Options
      #
      # * <tt>:geometry_type</tt> - set the geometry type. The actual
      #   data type is always "geometry"; this option is used in the
      #   <tt>geometry_columns</tt> table and on the CHECK constraints
      #   to enforce the geometry type allowed in the field. The default
      #   is "GEOMETRY". See the PostGIS documentation for valid types,
      #   or check out the GEOMETRY_TYPES constant in this extension.
      # * <tt>:add_constraints</tt> - automatically creates the CHECK
      #   constraints used to enforce ndims, srid and geometry type.
      #   The default is true.
      # * <tt>:add_geometry_columns_entry</tt> - automatically adds
      #   an entry to the <tt>geometry_columns</tt> table. We will
      #   try to delete any existing match in <tt>geometry_columns</tt>
      #   before inserting. The default is true.
      # * <tt>:create_gist_index</tt> - automatically creates a GiST
      #   index for the new geometry column. This option accepts either
      #   a true/false expression or a String. If the value is a String,
      #   we'll use it as the index name. The default is true.
      # * <tt>:ndims</tt> - the number of dimensions to allow in the
      #   geometry. This value is either 2 or 3 by default depending on
      #   the value of the <tt>:geometry_type</tt> option. If the
      #   <tt>:geometry_type</tt> ends in an "m" (for "measured
      #   geometries" the default is 3); for everything else, it is 2.
      # * <tt>:srid</tt> - the SRID, a.k.a. the Spatial Reference
      #   Identifier. The default is -1, which is a special SRID
      #   PostGIS in lieu of a real SRID.
      def geometry(column_name, opts = {})
        opts = {
          :geometry_type => :geometry,
          :add_constraints => true,
          :add_geometry_columns_entry => true,
          :create_gist_index => true,
          :srid => -1
        }.merge(opts)

        if opts[:ndims].blank?
          opts[:ndims] = if opts[:geometry_type].to_s.upcase =~ /M$/
            3
          else
            2
          end
        end

        assert_valid_geometry_type(opts[:geometry_type])
        assert_valid_ndims(opts[:ndims], opts[:geometry_type])

        column = self[column_name] || ColumnDefinition.new(base, column_name, :geometry)
        column.default = opts[:default]
        column.null = opts[:default]

        unless @columns.include?(column)
          @columns << column
          if opts[:add_constraints]
            @table_constraints << PostgreSQLCheckConstraint.new(
              base,
              "srid(#{base.quote_column_name(column_name)}) = (#{opts[:srid].to_i})",
              :name => "enforce_srid_#{column_name}"
            )

            @table_constraints << PostgreSQLCheckConstraint.new(
              base,
              "ndims(#{base.quote_column_name(column_name)}) = #{opts[:ndims].to_i}",
              :name => "enforce_dims_#{column_name}"
            )

            if opts[:geometry_type].to_s.upcase != 'GEOMETRY'
              @table_constraints << PostgreSQLCheckConstraint.new(
                base,
                "geometrytype(#{base.quote_column_name(column_name)}) = '#{opts[:geometry_type].to_s.upcase}'::text OR #{base.quote_column_name(column_name)} IS NULL",
                :name => "enforce_geotype_#{column_name}"
              )
            end
          end
        end

        # We want to split up the schema and the table name for the
        # upcoming geometry_columns rows and GiST index.
        current_schema, current_table_name = if self.table_name.is_a?(Hash)
          [ self.table_name.keys.first, self.table_name.values.first ]
        elsif base.current_schema
          [ base.current_schema, self.table_name ]
        else
          schema, table_name = base.extract_schema_and_table_names(self.table_name)
          [ schema || 'public', table_name ]
        end

        @post_processing ||= Array.new

        if opts[:add_geometry_columns_entry]
          @post_processing << sprintf(
            "DELETE FROM \"geometry_columns\" WHERE f_table_catalog = '' AND " +
            "f_table_schema = %s AND " +
            "f_table_name = %s AND " +
            "f_geometry_column = %s",
            base.quote(current_schema.to_s),
            base.quote(current_table_name.to_s),
            base.quote(column_name.to_s)
          )

          @post_processing << sprintf(
            "INSERT INTO \"geometry_columns\" VALUES ('', %s, %s, %s, %d, %d, %s)",
            base.quote(current_schema.to_s),
            base.quote(current_table_name.to_s),
            base.quote(column_name.to_s),
            opts[:ndims].to_i,
            opts[:srid].to_i,
            base.quote(opts[:geometry_type].to_s.upcase)
          )
        end

        if opts[:create_gist_index]
          index_name = if opts[:create_gist_index].is_a?(String)
            opts[:create_gist_index]
          else
            "#{current_table_name}_#{column_name}_gist_index"
          end

          @post_processing << PostgreSQLIndexDefinition.new(
            base,
            index_name,
            current_table_name,
            column_name,
            :using => :gist
          ).to_s
        end

        self
      end

      private
        GEOMETRY_TYPES = [
          'GEOMETRY',
          'GEOMETRYCOLLECTION',
          'POINT',
          'MULTIPOINT',
          'POLYGON',
          'MULTIPOLYGON',
          'LINESTRING',
          'MULTILINESTRING',
          'GEOMETRYCOLLECTIONM',
          'POINTM',
          'MULTIPOINTM',
          'POLYGONM',
          'MULTIPOLYGONM',
          'LINESTRINGM',
          'MULTILINESTRINGM',
          'CIRCULARSTRING',
          'CIRCULARSTRINGM',
          'COMPOUNDCURVE',
          'COMPOUNDCURVEM',
          'CURVEPOLYGON',
          'CURVEPOLYGONM',
          'MULTICURVE',
          'MULTICURVEM',
          'MULTISURFACE',
          'MULTISURFACEM'
        ].freeze

        def assert_valid_geometry_type(type)
          if !GEOMETRY_TYPES.include?(type.to_s.upcase)
            raise ActiveRecord::InvalidGeometryType.new(type)
          end unless type.nil?
        end

        def assert_valid_ndims(ndims, type)
          if !ndims.blank?
            if type.to_s.upcase =~ /([A-Z]+M)$/ && ndims != 3
              raise ActiveRecord::InvalidGeometryDimensions.new("Invalid PostGIS geometry dimensions (#{$1} requires 3 dimensions)")
            elsif ndims < 0 || ndims > 4
              ralse ActiveRecord::InvalidGeometryDimensions.new("Invalid PostGIS geometry dimensions (should be between 0 and 4 inclusive) - #{ndims}")
            end
          end
        end
    end
  end
end
