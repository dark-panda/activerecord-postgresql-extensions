
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

      # Updates the definition of a geometry field to a new SRID value.
      def update_geometry_srid(table_name, column_name, srid)
        schema, table = extract_schema_and_table_names(table_name)

        args = [
          quote(table),
          quote(column_name),
          quote(srid)
        ]

        args.unshift(quote(schema)) if schema

        execute(%{SELECT UpdateGeometrySRID(#{args.join(', ')});})
      end
    end

    class PostgreSQLGeometryColumnDefinition < ColumnDefinition
      attr_reader :base, :column_name, :options
      attr_accessor :default, :null

      def initialize(base, column_name, opts)
        @base = base
        @column_name = column_name

        @options = {
          :spatial_column_type => :geometry,
          :geometry_type => :geometry,
          :add_constraints => true,
          :force_constraints => false,
          :add_geometry_columns_entry => true,
          :create_gist_index => true,
          :srid => ActiveRecord::PostgreSQLExtensions::PostGIS.UNKNOWN_SRID
        }.merge(opts)

        if options[:ndims].blank?
          options[:ndims] = if options[:geometry_type].to_s.upcase =~ /M$/
            3
          else
            2
          end
        end

        assert_valid_spatial_column_type(options[:spatial_column_type])
        assert_valid_geometry_type(options[:geometry_type])
        assert_valid_ndims(options[:ndims], options[:geometry_type])

        column_type = if ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] < '2.0'
          options[:spatial_column_type]
        else
          column_args = [ options[:geometry_type].to_s.upcase ]

          if ![ 0, -1 ].include?(options[:srid])
            column_args << options[:srid]
          end

          "#{options[:spatial_column_type]}(#{column_args.join(', ')})"
        end

        super(base, column_name, column_type)

        @default = options[:default]
        @null = options[:null]

        if options[:add_constraints] && (
          ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] < '2.0' ||
          options[:force_constraints]
        )
          table_constraints << PostgreSQLCheckConstraint.new(
            base,
            "ST_srid(#{base.quote_column_name(column_name)}) = (#{options[:srid].to_i})",
            :name => "enforce_srid_#{column_name}"
          )

          table_constraints << PostgreSQLCheckConstraint.new(
            base,
            "ST_ndims(#{base.quote_column_name(column_name)}) = #{options[:ndims].to_i}",
            :name => "enforce_dims_#{column_name}"
          )

          if options[:geometry_type].to_s.upcase != 'GEOMETRY'
            table_constraints << PostgreSQLCheckConstraint.new(
              base,
              "geometrytype(#{base.quote_column_name(column_name)}) = '#{options[:geometry_type].to_s.upcase}'::text OR #{base.quote_column_name(column_name)} IS NULL",
              :name => "enforce_geotype_#{column_name}"
            )
          end
        end
      end

      def geometry_columns_entry(table_name)
        return [] unless options[:add_geometry_columns_entry] &&
          options[:spatial_column_type].to_s != 'geography' &&
          ActiveRecord::PostgreSQLExtensions::PostGIS.VERSION[:lib] < '2.0'

        current_scoped_schema, current_table_name = extract_schema_and_table_names(table_name)

        [
          sprintf(
            "DELETE FROM \"geometry_columns\" WHERE f_table_catalog = '' AND " +
            "f_table_schema = %s AND " +
            "f_table_name = %s AND " +
            "f_geometry_column = %s;",
            base.quote(current_scoped_schema.to_s),
            base.quote(current_table_name.to_s),
            base.quote(column_name.to_s)
          ),

          sprintf(
            "INSERT INTO \"geometry_columns\" VALUES ('', %s, %s, %s, %d, %d, %s);",
            base.quote(current_scoped_schema.to_s),
            base.quote(current_table_name.to_s),
            base.quote(column_name.to_s),
            options[:ndims].to_i,
            options[:srid].to_i,
            base.quote(options[:geometry_type].to_s.upcase)
          )
        ]
      end

      def geometry_column_index(table_name)
        return [] unless options[:create_gist_index]

        current_scoped_schema, current_table_name = extract_schema_and_table_names(table_name)

        index_name = if options[:create_gist_index].is_a?(String)
          options[:create_gist_index]
        else
          "#{current_table_name}_#{column_name}_gist_index"
        end

        [
          PostgreSQLIndexDefinition.new(
            base,
            index_name,
            { current_scoped_schema => current_table_name },
            column_name,
            :using => :gist
          ).to_s
        ]
      end

      def to_sql
        column_sql = "#{base.quote_column_name(name)} #{sql_type}"
        column_options = {}
        column_options[:null] = null unless null.nil?
        column_options[:default] = default unless default.nil?
        add_column_options!(column_sql, column_options) unless type.to_sym == :primary_key
        column_sql
      end

      def table_constraints
        @table_constraints ||= []
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

        def extract_schema_and_table_names(table_name)
          # We want to split up the schema and the table name for the
          # upcoming geometry_columns rows and GiST index.
          if table_name.is_a?(Hash)
            [ table_name.keys.first, table_name.values.first ]
          elsif base.current_scoped_schema
            [ base.current_scoped_schema, table_name ]
          else
            schema, table_name = base.extract_schema_and_table_names(table_name)
            [ schema || 'public', table_name ]
          end
        end
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
      #   the spatial type being used, i.e. "POINT", "POLYGON", ""
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
        column = self[column_name] || PostgreSQLGeometryColumnDefinition.new(base, column_name, opts)

        unless @columns.include?(column)
          @columns << column
        end

        table_constraints.concat(column.table_constraints)
        post_processing.concat(column.geometry_columns_entry(table_name))
        post_processing.concat(column.geometry_column_index(table_name))

        self
      end
      alias_method :geometry, :spatial

      def geography(column_name, opts = {})
        opts = {
          :srid => ActiveRecord::PostgreSQLExtensions::PostGIS.UNKNOWN_SRIDS[:geography]
        }.merge(opts)

        self.spatial(column_name, opts.merge(
          :spatial_column_type => :geography
        ))
      end
    end

    class PostgreSQLTable < Table
      def spatial(column_name, opts = {})
        column = PostgreSQLGeometryColumnDefinition.new(@base, column_name, opts)

        post_processing.concat(column.geometry_columns_entry(@table_name))
        post_processing.concat(column.geometry_column_index(@table_name))

        @base.add_column(@table_name, column_name, column.sql_type, opts)

        column.table_constraints.each do |constraint|
          @base.add_constraint(@table_name, constraint)
        end
      end
      alias_method :geometry, :spatial

      def geography(column_name, opts = {})
        opts = {
          :srid => ActiveRecord::PostgreSQLExtensions::PostGIS.UNKNOWN_SRIDS[:geography]
        }.merge(opts)

        self.spatial(column_name, opts.merge(
          :spatial_column_type => :geography
        ))
      end
    end
  end
end
