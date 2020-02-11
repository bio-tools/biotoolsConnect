#!/usr/bin/python3
import json
from pathlib import Path


indent="  "
destdir="/home/moeller/git/content/data"
jsonfile="edam.json"
verbose=False

##### NO EDITS BELOW THIS LINE ######

f = open(jsonfile,"r")

j =  json.load(f)
no=0

for package in j:
   no=no+1
   source = package["source"]
   binary = package["package"]
   biotools = package["bio.tools"]
   #url = package["url"]
   if source == binary:
      if biotools is None:
         pstr=destdir+"/"+source
         p = Path(pstr)
         if p.is_dir():
            print("I: package '"+source+"' has no bio.tools ref but bio.tools has a cognate one.")
         else:
            print("I: package '"+source+"' has no bio.tools ref.")
      else:
         pstr=destdir+"/"+biotools.lower()
         p = Path(pstr)
         if not p.is_dir():
            print("I: package '"+source+"' has biotools ref ('"+biotools+"')but no folder exists.")
         else:
            doi = package["doi"]
            if verbose:
               print(no,source,biotools)
            out=open(pstr+"/"+biotools.lower()+".debian.yaml","w")
            out.write("identifiers:\n")
            out.write(indent+"- biotools: "+biotools.lower()+"\n")
            if doi is not None:
               out.write(indent+"- doi: "+doi+"\n")
            out.write(indent+"- debian: "+source+"\n")
            bioconda = package["bioconda"]
            if bioconda is not None:
               out.write(indent+"- bioconda: "+bioconda+"\n")
            scicrunch = package["SciCrunch"]
            if scicrunch is not None:
               out.write(indent+"- scicrunch: "+scicrunch+"\n")
            omictools = package["OMICtools"]
            if omictools is not None:
               out.write(indent+"- omictools: "+omictools+"\n")
            if package.get("biii") is not None:
               biii = package["biii"]
               if biii is not None:
                  out.write(indent+"- biii: "+biii+"\n")

            homepage = package["homepage"]
            if homepage is not None:
               out.write("homepage: "+homepage+"\n")
            if package.get("license") is not None:
               license = package["license"]
               if license is not None and "unknown" != license and "<license>" != license:
                  out.write("License: "+license+"\n")
            summary=package["description"]
            description=package["long_description"]
            out.write("summary: "+summary+"\n")
            out.write("description: >\n"+indent+description.rstrip().lstrip().replace("\n ","\n").replace("\n","\n"+indent)+"\n")
            version=package["version"]
            out.write("version: "+version+"\n")
            topics=package["topics"]
            edam=package["edam_scopes"]
            if topics is not None or edam is not None:
               out.write("edam:\n")
               out.write(indent+"version: unknown\n") # Andreas said he would add this to the UDD
               if topics is not None:
                  out.write(indent+"topics:\n")
                  for t in topics:
                     out.write(indent+indent+"- "+t+"\n")
               if edam is not None:
                  out.write(indent+"scopes:\n")
                  for scope in edam:
                     n = scope["name"]
                     if n is None:
                        break
                     out.write(indent+indent+"- name: "+n+"\n")
                     f = None
                     if scope.get("function"):
                        f = scope["function"]
                     elif scope.get("functions"):
                        f = scope["functions"]
                     if f is not None:
                        out.write(indent+indent+"  "+"function:\n")
                        for ee in f:
                           out.write(indent+indent+"  "+indent+"- "+ee+"\n")
                     if scope.get("input"):
                        i = scope["input"]
                        if i is not None:
                           out.write(indent+indent+"  "+"input:\n")
                           for ii in i:
                              out.write(indent+indent+"  "+indent+"- data: "+ii["data"]+"\n")
                              iii = None
                              if ii.get("formats"):
                                 iii = ii["formats"]
                              elif ii.get("format"):
                                 iii = ii["format"]
                              if iii is not None:
                                 out.write(indent+indent+"  "+indent+"  formats:\n")
                                 for iiii in iii:
                                    out.write(indent+indent+"  "+indent+"  "+indent+"- "+iiii+"\n")
                     if scope.get("output") is not None:
                        o = scope["output"]
                        if o is not None:
                           out.write(indent+indent+"  "+"output:\n")
                           for oo in o:
                              out.write(indent+indent+"  "+indent+"- data: "+oo["data"]+"\n")
                              ooo = None
                              if oo.get("formats"):
                                 ooo = oo["formats"]
                              elif oo.get("format"):
                                 ooo = oo["format"]
                              if ooo is not None:
                                 out.write(indent+indent+"  "+indent+"  formats:\n")
                                 for oooo in ooo:
                                    out.write(indent+indent+"  "+indent+"  "+indent+"- "+oooo+"\n")
