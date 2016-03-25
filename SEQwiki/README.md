# biotoolsConnect : SEQwiki
Adaptor for content exchange between bio.tools and SEQwiki.

This is a simple mapper written in Python and wrapped with a bash script. The mapper uses the current EDAM version and maps SeqWIKI concepts to this. Only concepts that are found in EDAM are mapped and therefore mapping confidence is high. To assist the user and annotators various text files are printed e.g. to reveal which SeqWIKI concepts that could not be mapped to EDAM. The final output is a JSON file of the SeqWIKI tools.

It is easy to test the script by following the below guide:

1. Download the python2 script seqwiki2biotools.py and the bash script seqwiki2biotools_mapper.sh.

2. Be connected to the internet and then run seqwiki2biotools_mapper.sh


