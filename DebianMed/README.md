# biotoolsConnect : Debian Med
Adaptor for content exchange between bio.tools and Debian Med.

Run this script on any Linux machine with a psql client. In case you are lacking any such machine but you are a member of the Debian Med team you can do:

rsync edam.sh alioth.debian.org:
ssh alioth.debian.org
./edam.sh


The script queries the Debian "database of everything" (UDD) and retrieves, for all bioinformatics tools inside Debian, information relevant to bio.tools, including EDAM annotations.  The UDD itself includes information from the debian/upstream/edam files which hold EDAM annotation on Debian packages.