# biotoolsConnect : Debian Med
Adaptor for content exchange between bio.tools and Debian Med.

The script queries the Debian "database of everything" (UDD) and retrieves, for all bioinformatics tools inside Debian, information relevant to bio.tools, including EDAM annotations.  The UDD itself includes information from the  files:
 * debian/upstream/edam: holds EDAM annotation on Debian packages.
 * debian/upstream/metadata: assigns Debian packages to Registry like bio.tools

Run this script on any Linux machine with a psql client and redirect into a file:
```
./edam.sh -mj > edam.json
```
