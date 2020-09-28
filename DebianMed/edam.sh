#!/bin/sh
# Create a dataset for EDAM
#
# FIXME:
#        * Upstream-Contact
#        * Proper license information in packages - needs to be imported to UDD
#        * Version of EDAM ontology that is referenced

usage() {
cat >/dev/stderr <<EOT
Usage: $0 [option]
      -h print this help screen
      -j JSON export
      -m forcing public mirror over local one

Description:
 Query local or public UDD for information that could be useful for EDAM.

Source:
 This script lives on
  https://salsa.debian.org/blends-team/website/commits/master/misc/sql/edam.sh
 and a redundant copy is held on
  https://github.com/bio-tools/biotoolsConnect.git/DebianMed/edam.sh
  
EOT
}

if ! which psql >/dev/null ; then
   echo "E: postgresql client 'psql' not available"
   if [ -r /etc/debian_version ]; then
     echo "   Try 'sudo apt install postgresql-client-13'."
   fi
   exit
fi

PORT="-p 5452"

SERVICE="service=udd"
#if there is a local UDD clone just use this
if psql $PORT -l 2>/dev/null | grep -qw udd ; then
    SERVICE=udd
fi

# Check UDD connection
if ! psql $PORT $SERVICE -c "" 2>/dev/null ; then
    echo "I: No local UDD found, use public mirror."
    PORT="--port=5432"
    export PGPASSWORD="public-udd-mirror"
    SERVICE="--host=public-udd-mirror.xvm.mit.edu --username=public-udd-mirror udd"
fi

EXT=txt
while getopts "hjm" o; do
    case "${o}" in
        h)
            usage
            exit 0
            ;;
        j)
           JSONBEGIN="SELECT array_to_json(array_agg(t)) FROM ("
           JSONEND=") t"
           EXT=json
           OUTPUTFORMAT=--tuples-only
           ;;
        m)
           PORT="--port=5432"
           export PGPASSWORD="public-udd-mirror"
           SERVICE="--host=public-udd-mirror.xvm.mit.edu --username=public-udd-mirror udd"
           ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

team="'debian-med-packaging@lists.alioth.debian.org'"

psql $PORT $OUTPUTFORMAT $SERVICE >edam.$EXT <<EOT
$JSONBEGIN
-- If you want to make the output at source level uncomment this
-- SELECT source, array_agg(package) as packages, distribution, release, component, version, homepage FROM
-- (
  SELECT DISTINCT
         p.package, p.distribution, p.release, p.component,
         regexp_replace(regexp_replace(regexp_replace(regexp_replace(p.version, '-[.\d]+$', ''), '\+dfsg.*$', '') , '\+lgpl.*$', ''), '-\d*biolinux\d*$', '') AS version, -- strip Debian revision and other extensions to upstream version
         p.source, p.homepage, p.license as license, p.blend as blend,
          en.description AS description, en.long_description AS long_description,
          interface.tags AS interface, biology.tags AS biology, field.tags AS fields, use.tags AS use,
          pop.vote || ' / ' || pop.recent || ' / ' || pop.insts as popcon,
          bibdoi.value as doi,
          edam.topics  as topics,
          edam.scopes  as edam_scopes,
          biotools.entry  as "bio.tools",
          omictools.entry as "OMICtools",
          seqwiki.entry   as "SEQwiki",
          scicrunch.entry as "SciCrunch",
          bioconda.entry  as "bioconda",
          biii.entry      as "biii"
    FROM (
      SELECT * FROM (
        SELECT DISTINCT
             package, distribution, release, component, strip_binary_upload(version) AS version,
             source, homepage, description, description_md5, 'unknown' as license, 'debian-med' as blend
        FROM packages
        WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med')
        UNION
        SELECT DISTINCT
             package, 'prospective' AS distribution, 'vcs' AS release, component, strip_binary_upload(chlog_version) AS version,
             source, homepage, description, description_md5, license, blend
        FROM blends_prospectivepackages
        WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med')
       ) AS tmp
    ) AS p
    LEFT OUTER JOIN (
       SELECT package, description, long_description, release, description_md5, 'unknown' as license, 'debian-med' as blend
        FROM descriptions
       WHERE language = 'en'
         AND package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med')
       UNION
       SELECT package, description, long_description, 'vcs' AS release, description_md5, license, blend
        FROM blends_prospectivepackages 
    ) AS en ON en.package = p.package AND (en.release = p.release OR p.release = 'vcs')  AND (en.description_md5 = p.description_md5 OR en.description_md5 IS NULL)
    JOIN (
      -- select packages which have versions outside experimental
      SELECT px.package, strip_binary_upload(px.version) AS version,
             (SELECT release FROM ( SELECT release, sort FROM releases
                                     UNION
                                    SELECT 'vcs' AS release, 10000 AS sort
                                  ) reltmp WHERE sort = MAX(rx.sort)) AS release
        FROM (
           -- select highest version which is not in experimental - except if a package resides in experimental only
           SELECT pex.package, CASE WHEN pnoex.version IS NOT NULL THEN pnoex.version ELSE pex.version END AS version FROM
              (SELECT package, MAX(version) AS version FROM packages
                  WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med')
                  GROUP BY package
              ) pex
              LEFT OUTER JOIN
              (SELECT package, MAX(version) AS version FROM packages
                  WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med')
                    AND release != 'experimental'
                  GROUP BY package
              ) pnoex ON pex.package = pnoex.package
           UNION
           SELECT DISTINCT package, strip_binary_upload(chlog_version) AS version FROM blends_prospectivepackages
        ) px
        JOIN (
           -- select the release in which this version is available
           SELECT DISTINCT package, version, release FROM packages
            WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med')
           UNION
           SELECT DISTINCT package, chlog_version AS version, 'vcs' AS release FROM blends_prospectivepackages
            WHERE package IN
                      (SELECT DISTINCT package FROM blends_dependencies WHERE blend = 'debian-med')
        ) py ON px.package = py.package AND px.version = py.version
        JOIN ( SELECT release, sort FROM releases
               UNION 
               SELECT 'vcs' AS release, 10000 AS sort
             ) rx ON py.release = rx.release
        GROUP BY px.package, px.version
       ) AS pvar ON pvar.package = p.package AND pvar.version = p.version AND pvar.release = p.release
    LEFT OUTER JOIN (
       SELECT package, array_agg(regexp_replace(tag, 'interface::', '')) AS tags
         FROM debtags
        WHERE tag LIKE 'interface::%'
          GROUP BY package
    ) AS interface ON interface.package = p.package
    LEFT OUTER JOIN (
       SELECT package, array_agg(regexp_replace(tag, 'biology::', '')) AS tags
         FROM debtags
        WHERE tag LIKE 'biology::%'
          GROUP BY package
    ) AS biology ON biology.package = p.package
    LEFT OUTER JOIN (
       SELECT package, array_agg(regexp_replace(tag, 'field::', '')) AS tags
         FROM debtags
        WHERE tag LIKE 'field::%'
          GROUP BY package
    ) AS field ON field.package = p.package
    LEFT OUTER JOIN (
       SELECT package, array_agg(regexp_replace(tag, 'use::', '')) AS tags
         FROM debtags
        WHERE tag LIKE 'use::%'
          GROUP BY package
    ) AS use ON use.package = p.package
    LEFT OUTER JOIN bibref bibdoi      ON p.source = bibdoi.source     AND bibdoi.rank = 0     AND bibdoi.key     = 'doi'     AND bibdoi.package = ''
    LEFT OUTER JOIN popcon pop         ON p.package = pop.package
    LEFT OUTER JOIN edam   edam        ON p.source = edam.source       AND p.package = edam.package
    LEFT OUTER JOIN registry biotools  ON p.source = biotools.source   AND biotools.name  = 'bio.tools'
    LEFT OUTER JOIN registry omictools ON p.source = omictools.source  AND omictools.name = 'OMICtools'
    LEFT OUTER JOIN registry seqwiki   ON p.source = seqwiki.source    AND seqwiki.name   = 'SEQwiki'
    LEFT OUTER JOIN registry scicrunch ON p.source = scicrunch.source  AND scicrunch.name = 'SciCrunch'
    LEFT OUTER JOIN registry bioconda  ON p.source = bioconda.source   AND bioconda.name  = 'conda:bioconda'
    LEFT OUTER JOIN registry biii      ON p.source = biii.source       AND biii.name  = 'biii'
   ORDER BY source, package
-- If you want to make the output at source level uncomment this
-- ) tmp
--   GROUP BY source, distribution, release, component, version, homepage
--   ORDER BY source
$JSONEND
;
EOT
