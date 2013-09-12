
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/postgresql_extensions/postgis'

module ActiveRecord
  class InvalidGeometryType < ActiveRecordError #:nodoc:
    def initialize(type)
      super("Invalid PostGIS geometry type - #{type}")
    end
  end

  class InvalidSpatialColumnType < ActiveRecordError #:nodoc:
    def initialize(type)
      super("Invalid PostGIS spatial column type - #{type}")
    end
  end

  class InvalidGeometryDimensions < ActiveRecordError #:nodoc:
  end

  module ConnectionAdapters
    class PostgreSQLAdapter
      def native_database_types_with_spatial_types #:nodoc:
        native_database_types_without_spatial_types.merge({
          :geometry => { :name => 'geometry' },
          :geography => { :name => 'geography' }
        })
      end
      alias_method_chain :native_database_types, :spatial_types
    end

    class PostgreSQLGeometryColumnDefinition
    end

    class PostgreSQLTableDefinition < TableDefinition
      # This is a special spatial type for the PostGIS extension's
      # data types. It is used in a table definition to define
      # a spatial column.
      #
      # Depending on the version of PostGIS being used, we'll try to create
      # geometry columns in a post-2.0-ish, typmod-based way or a pre-2.0-ish
      # AddGeometryColumn-based way. We can also add CHECK constraints and
      # create a GiST index on the column all in one go.
      #
      # In versions of PostGIS prior to 2.0, geometry columns are created using
      # the AddGeometryColumn and will created with CHECK constraints where
      # appropriate and entries to the <tt>geometry_columns</tt> will be
      # updated accordingly.
      #
      # In versions of PostGIS after 2.0, geometry columns are creating using
      # typmod specifiers. CHECK constraints can still be created, but their
      # creation must be forced using the <tt>:force_constraints</tt> option.
      #
      # The <tt>geometry</tt> and <tt>geography</tt> methods are shortcuts to
      # calling the <tt>spatial</tt> method with the <tt>:spatial_column_type</tt>
      # option set accordingly.
      #
      # ==== Options
      #
      # * <tt>:spatial_column_type</tt> - the column type. This value can
      #   be one of <tt>:geometry</tt> or <tt>:geography</tt>. This value
      #   doesn't refer to the spatial type used by the column, but rather
      #   by the actual column type itself.
      # * <tt>:geometry_type</tt> - set the geometry type. The actual
      #   data type is either "geometry" or "geography"; this option refers to
      #   the spatial type being used.
      # * <tt>:add_constraints</tt> - automatically creates the CHECK
      #   constraints used to enforce ndims, srid and geometry type.
      #   The default is true.
      # * <tt>:force_constraints</tt> - forces the creation of CHECK
      #   constraints in versions of PostGIS post-2.0.
      # * <tt>:add_geometry_columns_entry</tt> - automatically adds
      #   an entry to the <tt>geometry_columns</tt> table. We will
      #   try to delete any existing match in <tt>geometry_columns</tt>
      #   before inserting. The default is true. This value is ignored in
      #   versions of PostGIS post-2.0.
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
      #   Identifier. The default depends on the version of PostGIS being used
      #   and the spatial column type being used. Refer to the PostGIS docs
      #   for the specifics, but generally this means either a value of -1
      #   for versions of PostGIS prior to 2.0 for geometry columns and a value
      #   of 0 for versions post-2.0 and for all geography columns.
      def spatial(column_name, opts = {})
        opts = {
          :spatial_column_type => :geometry,
          :geometry_type => :geometry,
          :add_constraints => true,
          :force_constraints => false,
          :add_geometry_columns_entry => true,
          :create_gist_index => true,
          :srid => ActiveRecord::PostgreSQLExtensions::PostGIS.UNKNOWN_SRID
        }.merge(opts)

        if opts[:ndims].blank?
          opts[:ndims] = if opts[:geometry_type].to_s.upcase =~ /M$/
            3
          else
            2
          end
        end

        assert_valid_spatial_column_type(opts[:spatial_column_type])
        assert_valid_geometry_type(opts[:geometry_type])
        assert_valid_ndims(opts[:ndims], opts[:geometry_type])

        column_type = if ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] < '2.0'
          opts[:spatial_column_type]
        else
          column_args = [ opts[:geometry_type].to_s.upcase ]

          if ![ 0, -1 ].include?(opts[:srid])
            column_args << opts[:srid]
          end

          "#{opts[:spatial_column_type]}(#{column_args.join(', ')})"
        end

        column = self[column_name] || ColumnDefinition.new(base, column_name, column_type)
        column.default = opts[:default]
        column.null = opts[:null]

        unless @columns.include?(column)
          @columns << column
          if opts[:add_constraints] && (
            ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] < '2.0' ||
            opts[:force_constraints]
          )
            table_constraints << PostgreSQLCheckConstraint.new(
              base,
              "ST_srid(#{base.quote_column_name(column_name)}) = (#{opts[:srid].to_i})",
              :name => "enforce_srid_#{column_name}"
            )

            table_constraints << PostgreSQLCheckConstraint.new(
              base,
              "ST_ndims(#{base.quote_column_name(column_name)}) = #{opts[:ndims].to_i}",
              :name => "enforce_dims_#{column_name}"
            )

            if opts[:geometry_type].to_s.upcase != 'GEOMETRY'
              table_constraints << PostgreSQLCheckConstraint.new(
                base,
                "geometrytype(#{base.quote_column_name(column_name)}) = '#{opts[:geometry_type].to_s.upcase}'::text OR #{base.quote_column_name(column_name)} IS NULL",
                :name => "enforce_geotype_#{column_name}"
              )
            end
          end
        end

        # We want to split up the schema and the table name for the
        # upcoming geometry_columns rows and GiST index.
        current_scoped_schema, current_table_name = if self.table_name.is_a?(Hash)
          [ self.table_name.keys.first, self.table_name.values.first ]
        elsif base.current_scoped_schema
          [ base.current_scoped_schema, self.table_name ]
        else
          schema, table_name = base.extract_schema_and_table_names(self.table_name)
          [ schema || 'public', table_name ]
        end

        if opts[:add_geometry_columns_entry] &&
          opts[:spatial_column_type].to_s != 'geography' &&
          ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] < '2.0'

          self.post_processing << sprintf(
            "DELETE FROM \"geometry_columns\" WHERE f_table_catalog = '' AND " +
            "f_table_schema = %s AND " +
            "f_table_name = %s AND " +
            "f_geometry_column = %s;",
            base.quote(current_scoped_schema.to_s),
            base.quote(current_table_name.to_s),
            base.quote(column_name.to_s)
          )

          self.post_processing << sprintf(
            "INSERT INTO \"geometry_columns\" VALUES ('', %s, %s, %s, %d, %d, %s);",
            base.quote(current_scoped_schema.to_s),
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

          self.post_processing << PostgreSQLIndexDefinition.new(
            base,
            index_name,
            { current_scoped_schema => current_table_name },
            column_name,
            :using => :gist
          ).to_s
        end

        self
      end

      def geometry(column_name, opts = {})
        self.spatial(column_name, opts)
      end

      def geography(column_name, opts = {})
        opts = {
          :srid => ActiveRecord::PostgreSQLExtensions::PostGIS.UNKNOWN_SRIDS[:geography]
        }.merge(opts)

        self.spatial(column_name, opts.merge(
          :spatial_column_type => :geography
        ))
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
          'GEOMETRYM',
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

        SPATIAL_COLUMN_TYPES = [
          'geometry',
          'geography'
        ].freeze

        def assert_valid_geometry_type(type)
          if !GEOMETRY_TYPES.include?(type.to_s.upcase)
            raise ActiveRecord::InvalidGeometryType.new(type)
          end unless type.nil?
        end

        def assert_valid_spatial_column_type(type)
          if !SPATIAL_COLUMN_TYPES.include?(type.to_s)
            raise ActiveRecord::InvalidSpatialColumnType.new(type)
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
