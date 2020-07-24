#!/usr/bin/python3
import json
import logging
from pathlib import Path
import yaml

indent="  "
destdir="/tmp"
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
   tool_info = {}
   #url = package["url"]
   if source == binary:
      if biotools is None:
         pstr=destdir+"/"+source
         p = Path(pstr)
         if p.is_dir():
            logging.warning(f"package '{source}' has no bio.tools ref but bio.tools has a cognate one.")
         else:
            logging.warning(f"package '{source}' has no bio.tools ref.")
      else:
         pstr=destdir+"/"+biotools.lower()
         pstr=destdir
         p = Path(pstr)
         if not p.is_dir():
            logging.warning(f"package '{source}' has a biotools ref ('{biotools}') but no folder exists.")
         else:
            doi = package["doi"]
            if verbose:
               print(no,source,biotools)
            out=open(pstr+"/"+biotools.lower()+".debian.yaml","w")
            identifiers = {}
            if biotools is not None:
                identifiers["biotools"] = biotools.lower()
            if doi is not None:
                identifiers["doi"] = doi
            if source is not None:
                identifiers["debian"] = source
            bioconda = package["bioconda"]
            if bioconda is not None:
                identifiers["bioconda"] = bioconda
            scicrunch = package["SciCrunch"]
            if scicrunch is not None:
                identifiers["scicrunch"] = scicrunch
            omictools = package["OMICtools"]
            if omictools is not None:
                identifiers["omictools"] = omictools
            if package.get("biii") is not None:
                identifiers["biii"] = package.get("biii")
            if bool(identifiers):
                tool_info["identifiers"] = identifiers
            tool_info["homepage"] = package["homepage"]
            if package.get("license") not in [None, "unknown", "<license>"]:
                tool_info["license"] = package.get("license")
            tool_info["summary"] = package.get("description")
            tool_info["description"] = ' '.join(package.get("long_description").split())
            tool_info["version"] = package.get("version")
            tool_info["edam"] = {}
            tool_info["edam"]["version"] = ""
            if "topics" in package:
                tool_info["edam"]["topics"] = package["topics"]
            if package.get("edam_scopes") is not None:
                tool_info["edam"]["scopes"] = []
                for scope in package.get("edam_scopes"):
                    tool_function = {
                                     "name": scope["name"],
                                     "function": scope.get("function", scope.get("functions")),
                                     "input": scope.get("input"),
                                     "output": scope.get("output")
                                    }
                    tool_info["edam"]["scopes"].append(tool_function)
            edam_scopes = package["edam_scopes"]
            yaml.dump(tool_info, out)
