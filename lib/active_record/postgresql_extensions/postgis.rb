
module ActiveRecord
  module PostgreSQLExtensions
    module PostGIS
      class << self
        def VERSION
          return @VERSION if defined?(@VERSION)

          @VERSION = if (version_string = ::ActiveRecord::Base.connection.select_rows("SELECT postgis_full_version()").flatten.first).present?
            hash = {
              :use_stats => version_string =~ /USE_STATS/
            }

            {
              :lib => /POSTGIS="([^"]+)"/,
              :geos => /GEOS="([^"]+)"/,
              :proj => /PROJ="([^"]+)"/,
              :libxml => /LIBXML="([^"]+)"/
            }.each do |k, v|
              hash[k] = version_string.scan(v).flatten.first
            end

            hash.freeze
          else
            nil
          end
        end

        def UNKNOWN_SRIDS
          return @UNKNOWN_SRIDS if defined?(@UNKNOWN_SRIDS)

          @UNKNOWN_SRIDS = if self.VERSION[:lib] >= '2.0'
            {
              :geography => 0,
              :geometry  => 0
            }.freeze
          else
            {
              :geography =>  0,
              :geometry  => -1
            }.freeze
          end
        end

        def UNKNOWN_SRID
          return @UNKNOWN_SRID if defined?(@UNKNOWN_SRID)

          @UNKNOWN_SRID = self.UNKNOWN_SRIDS[:geometry]
        end
      end
    end
  end
end
