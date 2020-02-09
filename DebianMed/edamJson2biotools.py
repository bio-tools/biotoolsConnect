#!/usr/bin/python3
import json
from pathlib import Path


indent="  "
destdir="/home/moeller/git/content/data"
f = open("edam.json","r")
j =  json.load(f)
no=0
for package in j:
   no=no+1
   source = package["source"]
   binary = package["package"]
   biotools = package["bio.tools"]
   #url = package["url"]
   if source == binary:
      if biotools is not None:
         pstr=destdir+"/"+biotools.lower()
         p = Path(pstr)
         if p.is_dir():
            doi = package["doi"]
            print(no,source,biotools)
            out=open(pstr+"/"+biotools.lower()+".debian.yaml","w")
            out.write("identifiers:\n")
            out.write(indent+"- biotools: "+biotools.lower()+"\n")
            if package.get("license") is not None:
               license = package["license"]
               if license is not None and "unknown" != license and "<license>" != license:
                  out.write("License: "+license+"\n")
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
            summary=package["description"]
            description=package["long_description"]
            out.write("summary: "+summary+"\n")
            out.write("description: >\n"+indent+description.rstrip().replace("\n","\n"+indent)+"\n")
            version=package["version"]
            out.write("version: "+version+"\n")
            topics=package["topics"]
            if topics is not None:
               out.write("topics:\n")
               for t in topics:
                  out.write(indent+"- "+t+"\n")
            edam=package["edam_scopes"]
            if edam is not None:
               out.write("edam:\n")
               for e in edam:
                  print(e)
                  n = e["name"]
                  if n is None:
                     break
                  out.write(indent+"- scope: "+n+"\n")
                  f = None
                  if e.get("function"):
                     f = e["function"]
                  elif e.get("functions"):
                     f = e["functions"]
                  if f is not None:
                     out.write(indent+"  "+"function:\n")
                     for ee in f:
                        out.write(indent+"  "+indent+"- "+ee+"\n")
                  if e.get("input"):
                     i = e["input"]
                     if i is not None:
                        out.write(indent+"  "+"input:\n")
                        for ii in i:
                           print(ii)
                           out.write(indent+"  "+indent+"- data: "+ii["data"]+"\n")
                           iii = None
                           if ii.get("formats"):
                              iii = ii["formats"]
                           elif ii.get("format"):
                              iii = ii["format"]
                           if iii is not None:
                              out.write(indent+"  "+indent+"  formats: \n")
                              for iiii in iii:
                                 out.write(indent+"  "+indent+"  "+indent+"- "+iiii+"\n")
                  if e.get("output") is not None:
                     o = e["output"]
                     if o is not None:
                        out.write(indent+"  "+"output:\n")
                        for oo in o:
                           out.write(indent+"  "+indent+"- data: "+oo["data"]+"\n")
                           ooo = None
                           if oo.get("formats"):
                              ooo = oo["formats"]
                           elif oo.get("format"):
                              ooo = oo["format"]
                           if ooo is not None:
                              out.write(indent+"  "+indent+"  formats: \n")
                              for oooo in ooo:
                                 out.write(indent+"  "+indent+"  "+indent+"- "+oooo+"\n")
