#!/bin/sh
# Create a dataset for EDAM
#
# FIXME:
#       - strip versions to upstream versions
#       - strip "interface::" from interface

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
-- If you want to make the output at source level uncomment this
-- SELECT source, array_agg(package) as packages, distribution, release, component, version, homepage FROM
-- (
  SELECT DISTINCT
         p.package, p.distribution, p.release, p.component, p.version,
         p.source, p.homepage,
          en.description AS description, en.long_description AS long_description,
          interface.tags AS interface, biology.tags AS biology, field.tags AS fields
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
    LEFT OUTER JOIN (
       SELECT package, array_agg(regexp_replace(tag, 'interface::', '')) AS tags
         FROM debtags
        WHERE tag LIKE 'interface::%'
          GROUP BY package
    ) interface ON interface.package = p.package
    LEFT OUTER JOIN (
       SELECT package, array_agg(regexp_replace(tag, 'biology::', '')) AS tags
         FROM debtags
        WHERE tag LIKE 'biology::%'
          GROUP BY package
    ) biology ON biology.package = p.package
    LEFT OUTER JOIN (
       SELECT package, array_agg(regexp_replace(tag, 'field::', '')) AS tags
         FROM debtags
        WHERE tag LIKE 'field::%'
          GROUP BY package
    ) field ON field.package = p.package

   ORDER BY source, package
-- If you want to make the output at source level uncomment this
-- ) tmp
--   GROUP BY source, distribution, release, component, version, homepage
--   ORDER BY source
$JSONEND
;
EOT
