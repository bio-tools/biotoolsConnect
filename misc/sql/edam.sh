#!/bin/sh
# Gather data needed to replace DebianGIS Package Thermometer available at
#
#   http://pkg-grass.alioth.debian.org/debiangis-status.html

PORT="-p 5452"

SERVICE="service=udd"
#if there is a local UDD clone just use this
if psql $PORT -l 2>/dev/null | grep -qw udd ; then
    SERVICE=udd
fi

# Check UDD connection
if ! psql $PORT $SERVICE -c "" 2>/dev/null ; then
    echo "No local UDD found, use publich mirror."
    PORT="--port=5432"
    export PGPASSWORD="public-udd-mirror"
    SERVICE="--host=public-udd-mirror.xvm.mit.edu --username=public-udd-mirror udd"
fi

EXT=txt
if [ "$1" = "-j" ] ; then
  JSONBEGIN="SELECT array_to_json(array_agg(t)) FROM ("
  JSONEND=") t"
  EXT=json
  OUTPUTFORMAT=--tuples-only
fi

team="'debian-med-packaging@lists.alioth.debian.org'"

psql $PORT $OUTPUTFORMAT $SERVICE >edam.$EXT <<EOT
$JSONBEGIN
  SELECT DISTINCT
         p.package, p.distribution, p.release, p.component, p.version,
         p.source, p.homepage
    FROM (
      SELECT DISTINCT
             package, distribution, release, component, strip_binary_upload(version) AS version,
             maintainer, source, section, homepage, description, description_md5
        FROM packages
       WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med' AND task IN ('bio', 'bio-dev'))
    ) p
    LEFT OUTER JOIN descriptions en ON en.language = 'en' AND en.package = p.package AND en.release = p.release  AND en.description_md5 = p.description_md5
    JOIN (
      -- select packages which have versions outside experimental
      SELECT px.package, strip_binary_upload(px.version) AS version, (SELECT release FROM releases WHERE sort = MAX(rx.sort)) AS release
        FROM (
           -- select highest version which is not in experimental - except if a package resides in experimental only
           SELECT pex.package, CASE WHEN pnoex.version IS NOT NULL THEN pnoex.version ELSE pex.version END AS version FROM
              (SELECT package, MAX(version) AS version FROM packages
                  WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med' AND task IN ('bio', 'bio-dev'))
                  GROUP BY package
              ) pex
              LEFT OUTER JOIN
              (SELECT package, MAX(version) AS version FROM packages
                  WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med' AND task IN ('bio', 'bio-dev'))
                    AND release != 'experimental'
                  GROUP BY package
              ) pnoex ON pex.package = pnoex.package
        ) px
        JOIN (
           -- select the release in which this version is available
           SELECT DISTINCT package, version, release FROM packages
            WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med' AND task IN ('bio', 'bio-dev'))
        ) py ON px.package = py.package AND px.version = py.version
        JOIN releases rx ON py.release = rx.release
        GROUP BY px.package, px.version
       ) pvar ON pvar.package = p.package AND pvar.version = p.version AND pvar.release = p.release

   ORDER BY p.source, p.package
$JSONEND
;
EOT
