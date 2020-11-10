#!/usr/bin/python3
import argparse
import os
import json
import logging
from pathlib import Path
import yaml

verbose = False

##### NO EDITS BELOW THIS LINE ######


def process_data(input_json, output_dir):
    f = open(input_json, "r")
    j = json.load(f)
    no = 0
    for package in j:
        no = no + 1
        source = package["source"]
        binary = package["package"]
        biotools = package["bio.tools"]
        tool_info = {}
        if source == binary:
            if biotools is None:
                pstr = os.path.join(output_dir, source.lower())
                p = Path(pstr)
                if p.is_dir():
                    logging.warning(
                        f"package '{source}' has no bio.tools ref but bio.tools has a cognate one."
                    )
                else:
                    logging.warning(f"package '{source}' has no bio.tools ref.")
            else:
                pstr = os.path.join(output_dir, biotools.lower())
                p = Path(pstr)
                if not p.is_dir():
                    logging.warning(
                        f"package '{source}' has a biotools ref ('{biotools}') but no folder exists."
                    )
                else:
                    doi = package["doi"]
                    if verbose:
                        print(no, source, biotools)
                    out = open(
                        os.path.join(pstr, f"{biotools.lower()}.debian.yaml"), "w"
                    )
                    identifiers = {}
                    if biotools is not None:
                        identifiers["biotools"] = biotools.lower()
                    if doi is not None:
                        identifiers["doi"] = [doi]
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
                    tool_info["description"] = " ".join(
                        package.get("long_description").split()
                    )
                    tool_info["version"] = package.get("version")
                    tool_info["edam"] = {}
                    tool_info["edam"]["version"] = "unknown"
                    if "topics" in package:
                        tool_info["edam"]["topics"] = package["topics"]
                    if package.get("edam_scopes") is not None:
                        tool_info["edam"]["scopes"] = []
                        for scope in package.get("edam_scopes"):
                            tool_function = {
                                "name": scope["name"],
                                "function": scope.get(
                                    "function", scope.get("functions")
                                ),
                            }
                            if scope.get("input") is not None:
                                tool_function["input"] = scope.get("input")
                            if scope.get("output") is not None:
                                tool_function["output"] = scope.get("output")
                            tool_info["edam"]["scopes"].append(tool_function)
                    edam_scopes = package["edam_scopes"]
                    yaml.dump(tool_info, out)


def get_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_json", help="path to the initial JSON file")
    parser.add_argument("output_dir", help="path to the output dir")
    return parser


def main():
    parser = get_parser()
    args = parser.parse_args()
    process_data(args.input_json, args.output_dir)


if __name__ == "__main__":
    main()
