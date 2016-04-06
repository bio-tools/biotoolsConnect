import csv
import argparse
import json
import re
import urllib, urllib2
from sys import exit
import os.path
import time
import datetime
import ssl
import requests


def authentication(username, password):
    """
    Returns authentication token.
    """
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    login_info = '{' + '"username": "{}","password": "{}"'.format(username, password) + '}'
    url = 'http://elixir-registry-demo.cbs.dtu.dk/auth/login'
    request = rest_service(url, login_info)

    try:
        handler = urllib2.urlopen(request, context=ctx)
        print('Authentication: Success')

    except urllib2.HTTPError as e:
        print('Authentication: Error {}\t{}'.format(e.code, e.reason))
        exit()
    print(handler.read())

    token = json.loads(handler.read())['token']
    return token


def rest_service(url, data, extra_headers=False):
    """
    Performs most of the rest service and returns a urllib2 request to be handled.
    """

    headers = {'Accept': 'application/json', 'Content-type': 'application/json'}
    if extra_headers:
        headers.update(extra_headers)

    opener = urllib2.build_opener()
    urllib2.install_opener(opener)

    return urllib2.Request(url=url, data=data, headers=headers)


def error_print(error, path):
    """
    Pretty print of error messages.
    """
    if type(error) == type(list()):
        for sub_error in error:
            error_print(sub_error, path)

    elif 'text' in error.keys():
        print('\t{}'.format(path))
        print('\t{}'.format(error['text']))
        for key in error['data'].keys():
            if error['data'][key]:
                print('\t{}\t{}'.format(key, error['data'][key]))
            else:
                print('\t{}\t'.format(key))
    else:
        for key in error.keys():
            new_path = path + key + '/'
            error_print(error[key], new_path)


def import_resource(auth_token, json_string, count):
    """
    Imports a single resource to the elixir database.
    """

    url = 'http://elixir-registry-demo.cbs.dtu.dk/tool'
    auth = 'Token ' + auth_token
    header = {'Authorization': auth}

    request = rest_service(url, json_string, header)

    try:
        urllib2.urlopen(request)
        # handler = urllib2.urlopen(request)
        print('[{}] Resource upload: Success'.format(count))

    # Error handling
    except urllib2.HTTPError as e:
        if e.code == 400:
            error = json.loads(e.read())
            print('[{}] Resource upload: Error'.format(count))
            error_print(error['fields'], '/')
        else:
            print('[{}] Resource upload: Error {}\t{}'.format(count, e.code, e.reason))


# Add keys to a dictionary that map labels (both preferred and synonyms) to the line where the concept was picked up:
def list_syn(label2key, lc, syn_labels):
    for idx, syn in enumerate(syn_labels):
        # If the synonym is already in the dictionary
        # and it is not because the preferred label is also a synomym:
        if syn in label2key.keys() and not (syn == syn_labels[0] and idx > 0):
            # print('Preferred label: {}, Seen both in line: {} and {}'.format(syn, label2key[syn]+2, lc+2))
            # If the index is 0 the label is a preferred label and this has higher precedence:
            if idx == 0:
                label2key[syn] = lc
        else:
            if syn != '':
                label2key[syn] = lc
            else:
                pass

    return(label2key)


# Take a CSV version of the EDAM ontology and return list of labels that can be mapped back to the concepts by the "concept" dictionary:
def fill_label2key(edam_file, t_label2key, o_label2key, d_label2key, f_label2key, concept):
    # Read the EDAM CSV file and extract all its relevant data:
    with open(edam_file) as EDAM_fh:
        EDAMcsv = csv.reader(EDAM_fh, delimiter=',', quotechar='"')
        # Skip first line:
        next(EDAMcsv, None)

        for lc, line in enumerate(EDAMcsv):
            # We skip obsolete entries:
            obs = line[4].lower()
            if str(obs) == 'true':
                continue

            # Extract the url and the labels:
            url = line[0]
            pref_label = line[1]
            syn_labels = line[49].split('|')
            syn_labels = [x.lower() for x in syn_labels]
            # Insert the preferred label as the first in the list of synonyms:
            syn_labels.insert(0, pref_label.lower())

            # Now devide into topic/operation/data/format:
            if 'topic' in url:
                concept[lc] = [url, 'topic', pref_label, obs]
                t_label2key = list_syn(t_label2key, lc, syn_labels)
            elif 'operation' in url:
                concept[lc] = [url, 'operation', pref_label, obs]
                o_label2key = list_syn(o_label2key, lc, syn_labels)
            elif 'data' in url:
                concept[lc] = [url, 'data', pref_label, obs]
                d_label2key = list_syn(d_label2key, lc, syn_labels)
            elif 'format' in url:
                concept[lc] = [url, 'format', pref_label, obs]
                f_label2key = list_syn(f_label2key, lc, syn_labels)
            elif line in ['\n', '\r\n']:
                print('Remove newlines please.')
            else:
                continue  # Skip this error control by now
                print('Check the input! Could not find any topic/operation/data/format.')
                print(line)
                print("Line " + str(lc))

    return(t_label2key, o_label2key, d_label2key, f_label2key, concept)


# Make simple count stats on some of the information fields in the output JSON:
def make_stats(all_resources):
    # All the stats:
    # 0 numb_tools
    # 1 no_ref
    # 2 no_homepage
    # 3 no_platform
    # 4 no_license
    # 5 no_operation
    # 6 no_topic
    # 7 no_email
    # 8 no_language
    # 9 no_interface
    # 9 no_description
    stat_list = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    for tool in sorted(all_resources.keys()):
        stat_list[0] += 1
        if 'publicationsPrimaryID' not in all_resources[tool]['publications'] or not all_resources[tool]['publications']['publicationsPrimaryID']:
            stat_list[1] += 1
        if 'homepage' not in all_resources[tool] or not all_resources[tool]['homepage']:
            stat_list[2] += 1
        if not all_resources[tool]['platform']:
            stat_list[3] += 1
        if 'license' not in all_resources[tool] or not all_resources[tool]['license']:
            stat_list[4] += 1
        if not all_resources[tool]['function'][0]:
            stat_list[5] += 1
        if not all_resources[tool]['topic']:
            stat_list[6] += 1
        if 'contact' not in all_resources[tool] or not all_resources[tool]['contact']:
            stat_list[7] += 1
        if 'language' not in all_resources[tool] or not all_resources[tool]['language']:
            stat_list[8] += 1
        if 'interface' not in all_resources[tool] or not all_resources[tool]['interface']:
            stat_list[9] += 1
        if 'description' not in all_resources[tool] or not all_resources[tool]['description']:
            stat_list[10] += 1

    return(stat_list)


# Make timestamp for the stat report:
def timestamp():
    systime = time.time()
    stamp = datetime.datetime.fromtimestamp(systime).strftime('%Y-%m-%d %H:%M:%S')
    return(stamp)


# Get lists of possible names defined by the biotools schema. Also return a dictionary that maps license names from SeqWIKI to biotools:
def get_namespace():
    SeqWIKI_url_type = ['Homepage', 'Manual', 'Mailing list', 'Binaries', 'Analysis server', 'Source code', 'HOWTO', 'Publication full text', 'Description', 'Related', 'White Paper']
    resouce_type = ["Database", "Tool", "Service", "Workflow", "Platform", "Container", "Library", "Other"]
    possible_interface = ['Command line', 'Web UI', 'Desktop GUI', 'SOAP WS', 'HTTP WS', 'API', 'QL']
    possible_lang = ['ActionScript', 'Ada', 'AppleScript', 'Assembly language', 'Bash', 'C', 'C#', 'C++', 'COBOL', 'ColdFusion', 'D', 'Delphi', 'Dylan', 'Eiffel', 'Forth', 'Fortran', 'Groovy', 'Haskell', 'Icarus', 'Java', 'Javascript', 'LabVIEW', 'Lisp', 'Lua', 'Maple', 'Mathematica', 'MATLAB language', 'MLXTRAN', 'NMTRAN', 'Pascal', 'Perl', 'PHP', 'Prolog', 'Python', 'R', 'Racket', 'REXX', 'Ruby', 'SAS', 'Scala', 'Scheme', 'Shell', 'Smalltalk', 'SQL', 'Turing', 'Verilog', 'VHDL', 'Visual Basic']
    possible_license = ['Apache License 2.0', 'Artistic License 2.0', 'MIT License', 'GNU General Public License v3', 'GNU Lesser General Public License v2.1', 'GNU General Public License v2', 'GNU Affero General Public License v3', 'BSD 3-Clause License (Revised)', 'BSD 2-Clause License', 'Creative Commons Attribution NonCommerical NoDerivs', 'Microsoft Public License', 'Mozilla Public License 2.0', 'Creative Commons Attribution NoDerivs', 'Eclipse Public License 1.0', 'Microsoft Reciprocal License', 'PHP License 3.0', 'Creative Commons Attribution 3.0 Unported', 'Creative Commons Attribution Share Alike', 'Creative Commons Attribution NonCommercial', 'Creative Commons Attribution NonCommercial ShareAlike', 'Apple Public Source License 2.0', 'ISC License', 'IBM Public License', 'GNU Free Documentation License v1.3', 'Common Public Attribution License Version 1.0', 'European Union Public License 1.1', 'ODC Open Database License', 'Simple Public License 2.0', 'Creative Commons Attribution-NonCommercial 2.0 Generic', 'Creative Commons CC0 1.0 Universal', 'Microsoft Shared Source Community License', 'Mozilla Public License 1.1', 'Educational Community License Version 2.0', 'Creative Commons Attribution 4.0 International', 'Open Software Licence 3.0', 'Common Public License 1.0', 'CeCILL v2', 'Adaptive Public License 1.0', 'Non-Profit Open Software License 3.0', 'Reciprocal Public License 1.5', 'Open Public License v1.0', 'ODC Public Domain Dedication and License 1.0']
    license_dict = {'CeCILL': 'CeCILL v2', 'EU-GPL': 'European Union Public License 1.1', 'GNU': 'GNU General Public License v3', 'GPLv2': 'GNU General Public License v2', 'GPLv3': 'GNU General Public License v3', 'BSD License': 'BSD 3-Clause License (Revised)', 'Creative Commons - Attribution-NonCommercial-ShareAlike': 'Creative Commons Attribution NonCommerical NoDerivs', 'Artistic-2.0': 'Artistic License 2.0', 'Creative Commons - Attribution; Non-commercial 2.5': 'Creative Commons Attribution NonCommerical NoDerivs', 'MIT': 'MIT License', 'LGPL 2.1': 'GNU Lesser General Public License v2.1', 'GPL-2 + file LICENSE': 'GNU General Public License v2', 'CeCILL-C   license': 'CeCILL v2', 'Biopython License (MIT/BSD style)': 'MIT License', 'Creative Commons license (Attribution-NonCommerical).': 'Creative Commons Attribution NonCommerical NoDerivs', 'BSD': 'BSD 3-Clause License (Revised)', 'GPL': 'GNU General Public License v3', 'AGPL': 'GNU Affero General Public License v3', 'Artistic License': 'Artistic License 2.0', 'GPL  Boost': 'GNU General Public License v3', 'GPL (>= 3)': 'GNU General Public License v3', 'GPL >=2': 'GNU General Public License v3', 'GPL-3': 'GNU General Public License v3', 'LGPL': 'GNU Lesser General Public License v2.1', 'LGPLv3': 'GNU General Public License v3', 'BSD (3-clause)': 'BSD 3-Clause License (Revised)', 'GPL 2.0+': 'GNU General Public License v3', 'Mozilla Public License': 'Mozilla Public License 2.0'}
    return(SeqWIKI_url_type, resouce_type, possible_interface, possible_lang, possible_license, license_dict)


if __name__ == '__main__':
    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("-tool", help="Tool CSV dump file obtained from http://seqanswers.com/wiki/Software/Dumps", required=True)
    parser.add_argument("-references", help="Reference CSV dump file obtained from http://seqanswers.com/wiki/Software/Dumps", required=True)
    parser.add_argument("-urls", help="URL CSV dump file obtained from http://seqanswers.com/wiki/Software/Dumps", required=True)
    parser.add_argument("-edam", help="EDAM CSV dump file obtained from http://bioportal.bioontology.org/ontologies/EDAM/?p=summary", required=True)
    parser.add_argument("-out", help="Output file name.")
    parser.add_argument("-stats", help="Tool statistics output file name.")
    parser.add_argument("-mix", help="Print mix between operations and topics or formats and data; 0/1.")
    parser.add_argument("-mis", help="Print mismatches between operations/topics/formats seen in SeqWIKI vs. the valid concepts in EDAM; 0/1.")
    parser.add_argument("-nokey", help="Prints the tools from the tools.csv file that are not found in either references.csv or url.csv; 0/1.")
    parser.add_argument("-v", help="Verbose; 0/1.")
    args = parser.parse_args()

    # Get the resticted namespace of EDAM:
    SeqWIKI_url_type, resouce_type, possible_interface, possible_lang, possible_license, license_dict = list(), list(), list(), list(), list(), dict()
    SeqWIKI_url_type, resouce_type, possible_interface, possible_lang, possible_license, license_dict = get_namespace()
    resouce_type_low = [x.lower() for x in resouce_type]
    possible_interface_low = [x.lower() for x in possible_interface]
    possible_lang_low = [x.lower() for x in possible_lang]
    possible_license_low = [x.lower() for x in possible_license]

    # Define the dictionaries to store the keys to the concept dictionary:
    t_label2key = dict()
    o_label2key = dict()
    d_label2key = dict()  # Notice that data type is not part of SeqWIKI. It is left here for completeness
    f_label2key = dict()
    # Line number as key to a list of information about the term:
    concept = dict()
    t_label2key, o_label2key, d_label2key, f_label2key, concept = fill_label2key(args.edam, t_label2key, o_label2key, d_label2key, f_label2key, concept)

    # Convert to lower case:
    all_topics = [x.lower() for x in t_label2key.keys()]
    all_operations = [x.lower() for x in o_label2key.keys()]
    all_data = [x.lower() for x in d_label2key.keys()]
    all_formats = [x.lower() for x in f_label2key.keys()]

    # Find the concepts that are shared between topic/operation and format/data.
    # For these concepts it cannot be determined if there have been a mix between topic/operation or format/data:
    topic_operation_overlap = list(set(all_topics) & set(all_operations))
    format_data_overlap = list(set(all_formats) & set(all_data))

    # Global dictionaries:
    all_resources = dict()                                                                                             # Stores all resources/tools
    tool2case = dict()                                                                                                 # Converts lower case tool name to its original case
    tools2line = dict()                                                                                                # The line in the CSV file where the tool was picked up
    bad_license_name = dict()                                                                                          # The licenses picked up in SeqWIKI that does not match the biotools schema

# In tools:
# 0: name -> "name":
# 2: operations -> "function": [ "functionName": [ uri, term
# 3: topics -> "topic": [ uri, term
# 5: developer -> "credits": { "creditsDeveloper": [
# 6: email -> "contact": [{"contactEmail":
# 7: input format -> "function": [{"input": [{"dataFormat": [{
# 8: institute -> "credits": { "creditsInstitution": [
# 9: interface -> "interface": [{"interfaceType":
# 10: language -> "language": [
# 12: license -> "license":
# 13: maintained -> "maturity":
# 16: operating system -> "platform": [
# 17: output format -> "function": [{"output": [{"dataFormat": [{
# 21: resource type -> "resourceType": [
# 23: summary -> "description":

    # Open tools CSV:
    with open(args.tool, 'rb') as csvfile:
        tools = csv.reader(csvfile, delimiter=',', quotechar='"')
        # Skip first line
        next(tools, None)
        for line_count, row in enumerate(tools):
            # Convert the tool name to lower case but first store the original case name in tool2case dict:
            tool = row[0]
            if tool.lower() in tool2case:
                if args.v:
                    print('Duplicate tool name was detected: {:>40} in line: {:>4} in the tools.csv file'.format(tool, line_count + 2))
            else:
                tool2case[tool.lower()] = tool
            tool = tool.lower()

            # Create the resource dictionary for the given tool:
            resource = dict()
            resource['name'] = tool2case[tool]                                                                         # name

            # If any resource type specified use it, else it is a "Tool":
            resource['resourceType'] = list()                                                                          # resource type
            if row[21] and row[21].lower() in resouce_type_low:
                idx = resouce_type_low.index(row[21].lower())
                resource['resourceType'].append({'term': resouce_type[idx]})
            else:
                resource['resourceType'].append({'term': 'Tool'})

            # We can only deduce one function, so this is created:
            resource['function'] = list()                                                                              # function list
            resource['function'].append(dict())                                                                        # function 1

            # Fill in all the EDAM operations/functions:
            resource['function'][0]['functionName'] = list()                                                           # function name list
            resource['function'][0]['functionDescription'] = ''                                                        # no current function description in SeqWIKI
            for functionName in row[2].split(','):                                                                     # iterate over function names
                functionName = functionName.lower()
                # Make hash lookup to validate the operation:
                if functionName and functionName in all_operations:
                    # Possibly raise a flag here if the concept is obsolete
                    concept_key = o_label2key[functionName]
                    uri = concept[concept_key][0]
                    pref_label = concept[concept_key][2]
                # If the operation is actually a topic, filtered for concept names common for both topics and operations:
                elif functionName and functionName in all_topics and functionName not in topic_operation_overlap:
                    if args.mix:
                        print('Operation in topic for tool: {:>40}    {:<25}{}'.format(tool, 'with wrong operation:', functionName))
                    # concept_key = t_label2key[functionName]
                    # uri = concept[concept_key][0]
                    # pref_label = concept[concept_key][2]
                    continue
                elif not functionName:
                    # If empty then just continue:
                    continue
                else:
                    if args.mis:
                        print('Operation not found in EDAM: {:>45}    for tool: {}'.format(functionName, tool))
                    continue
                resource['function'][0]['functionName'].append({'term': pref_label, 'uri': uri})                       # add function name and uri

            # Determine the maturity from the tool:
            if row[13].lower() == 'yes':                                                                               # maturity
                resource['maturity'] = 'Stable'
            elif row[13].lower() == 'no':                                                                              # maturity
                resource['maturity'] = 'Deprecated'

            # Fill in all the EDAM input formats:
            resource['function'][0]['input'] = list()                                                                  # input list
            for input1 in row[7].split(','):                                                                           # iterate over inputs
                input1 = input1.lower()
                dataFormat = list()                                                                                    # create list for data format
                # Make hash lookup to validate the operation:
                if input1 and input1 in all_formats:
                    # Possibly raise a flag here if the concept is obsolete
                    concept_key = f_label2key[input1]
                    uri = concept[concept_key][0]
                    pref_label = concept[concept_key][2]
                # If the format is actually a data concept, filtered for concept names common for both format and data:
                elif input1 and input1 in all_data and input1 not in format_data_overlap:
                    if args.mix:
                        print('Data comcept in input format for tool: {:>40}    {:<25}{}'.format(tool, 'with wrong format:', input1))
                    # concept_key = d_label2key[input1]
                    # uri = concept[concept_key][0]
                    # pref_label = concept[concept_key][2]
                    continue
                elif not input1:
                    # If empty then just continue:
                    continue
                else:
                    if args.mis:
                        print('Format not found in EDAM: {:>45}    for tool: {}'.format(input1, tool))
                    continue
                dataFormat.append({'term': pref_label, 'uri': uri})                                                    # input EDAM term and uri to data format list
                resource['function'][0]['input'].append({'dataFormat': dataFormat})                                    # add data format list to input list

            # Fill in all the EDAM output formats:
            resource['function'][0]['output'] = list()                                                                 # create output list
            for output1 in row[7].split(','):                                                                          # iterate over outputs
                output1 = output1.lower()
                dataFormat = list()                                                                                    # list for data format
                # Make hash lookup to validate the operation:
                if output1 and output1 in all_formats:
                    # Possibly raise a flag here if the concept is obsolete
                    concept_key = f_label2key[output1]
                    uri = concept[concept_key][0]
                    pref_label = concept[concept_key][2]
                # If the format is actually a data concept, filtered for concept names common for both format and data:
                elif output1 and output1 in all_data and output1 not in format_data_overlap:
                    if args.mix:
                        print('Data concept in output format for tool: {:>40}    {:<25}{}'.format(tool, 'with wrong format:', output1))
                    # concept_key = d_label2key[output1]
                    # uri = concept[concept_key][0]
                    # pref_label = concept[concept_key][2]
                    continue
                elif not output1:
                    # If empty then just continue:
                    continue
                else:
                    if args.mis:
                        print('Format not found in EDAM: {:>45}    for tool: {}'.format(output1, tool))
                    continue
                dataFormat.append({'term': pref_label, 'uri': uri})                                                    # add output EDAM term and uri to data format list
                resource['function'][0]['output'].append({'dataFormat': dataFormat})                                   # add data format list to input list

            # Map the SeqWIKI specified platform to EDAM:
            resource['platform'] = list()                                                                              # platform list
            for platform in row[16].split(','):                                                                        # iterate over platforms
                if platform:
                    if re.match('windows', platform, re.IGNORECASE):
                        resource['platform'].append('Windows')
                    if re.match('linux', platform, re.IGNORECASE):
                        resource['platform'].append('Linux')
                    if re.match('mac', platform, re.IGNORECASE):
                        resource['platform'].append('Mac')
                    if re.match('unix', platform, re.IGNORECASE):
                        resource['platform'].append('Unix')
                    # Some SeqWIKI specific platforms manually found and mapped to the appropriate platform label:
                    if re.match('any|independent|cross|browser', platform, re.IGNORECASE):
                        resource['platform'].extend(['Windows', 'Linux', 'Mac', 'Unix'])
                else:
                    pass

            # Fill in all the EDAM topics:
            resource['topic'] = list()                                                                                 # topic list
            for topic in row[3].split(','):                                                                            # iterate over topics
                topic = topic.lower()
                # Make hash lookup to validate the operation:
                if topic and topic in all_topics:
                    # Possibly raise a flag here if the concept is obsolete
                    concept_key = t_label2key[topic]
                    uri = concept[concept_key][0]
                    pref_label = concept[concept_key][2]
                # If the topic is actually an operation, filtered for concept names common for both topics and operations:
                elif topic and topic in all_operations and topic not in topic_operation_overlap:
                    if args.mix:
                        print('Topic in operation for tool: {:>40}    {:<25}{}'.format(tool, 'with wrong topic:', topic))
                    # concept_key = o_label2key[topic]
                    # uri = concept[concept_key][0]
                    # pref_label = concept[concept_key][2]
                    continue
                elif not topic:
                    continue  # If empty then just continue
                else:
                    if args.mis:
                        print('Topic not found in EDAM: {:>45}    for tool: {}'.format(topic, tool))
                    continue
                resource['topic'].append({'term': pref_label, 'uri': uri})                                             # add topics label and uri

            # Match the programming language specified under SeqWIKI
            # with the ones allowed by the biotools schema:
            resource['language'] = list()                                                                              # language list
            for language in row[10].split(','):                                                                        # iterate over languages
                if language and language.lower() in possible_lang_low:
                    idx = possible_lang_low.index(language.lower())
                    resource['language'].append(possible_lang[idx])
                elif language:
                    # Split the label by whitespace and see if it matches anything:
                    lang_namesplit = language.split()
                    success = 0
                    for comp in lang_namesplit:
                        if comp.lower() in possible_lang_low:
                            idx = possible_lang_low.index(comp.lower())
                            resource['language'].append(possible_lang[idx])
                            success = 1
                    if not success and args.v:
                        print('Language not found in biotools schema: {:>40}    for tool: {}'.format(language, tool))

            # Take the SeqWIKI "Developer" and "Institute" and assign this to "credits":
            resource['credits'] = dict()                                                                               # credits grouping
            resource['credits']['creditsDeveloper'] = list()                                                           # credits developer list
            for creditsDeveloper in row[5].split(','):                                                                 # iterate over credits developers
                if creditsDeveloper:
                    resource['credits']['creditsDeveloper'].append(creditsDeveloper)                                   # add credits developers

            resource['credits']['creditsInstitution'] = list()                                                         # credits institution list
            for creditsInstitution in row[8].split(','):                                                               # iterate over credits institutions
                if creditsInstitution:
                    resource['credits']['creditsInstitution'].append(creditsInstitution)                               # add credits institution

            # Take the SeqWIKI "Email address" and assign this to "contacts"
            resource['contact'] = list()                                                                               # create contact list
            for contactEmail in row[6].split(','):                                                                     # iterate over contact emails
                if contactEmail:
                    resource['contact'].append({'contactEmail': contactEmail})                                         # add contact emails

            # Few tools in SeqWIKI have an interface field but at least assign the few that are there:
            resource['interface'] = list()
            for interface in row[9].split(','):
                if interface.lower() in possible_interface_low:
                    idx = possible_interface_low.index(interface.lower())
                    resource['interface'].append({'interfaceType': possible_interface[idx]})

            # Try to find the license and match to one from the biotools schema:
            if row[12]:
                for license in row[12].split(','):
                    if license.lower() in possible_license_low:
                        idx = possible_license_low.index(license.lower())
                        resource['license'] = possible_license[idx]                                                    # license
                        break
                    elif license in license_dict:
                        resource['license'] = license_dict[license]

            # Keep track on the licenses that are not picked up by the biotools schema:
            if row[12] and 'license' not in resource:
                for license in row[12].split(','):
                    bad_license_name[license] = 1

            # Take the summary field and use for the description:
            resource['description'] = row[23]                                                                          # description

            # These fields will be used to fill in references and urls:
            resource['publications'] = dict()                                                                          # publications grouping
            resource['publications']['publicationsOtherID'] = list()                                                   # publications other id list
            resource['docs'] = dict()                                                                                  # docs grouping

            # print(row[0], line_count + 2)
            # Add tool to global dictionary

            all_resources[tool] = resource
            # Store which line the tool was picked up in:
            tools2line[tool] = line_count + 2

    # List all tools seen in the tools.csv file:
    all_tools = list(all_resources.keys())
    # Keep track of the tools remove from the above list:
    remove_tools = list()
    in_ref_not_in_tools = list()

    # We could print all the bad license names:
    if args.v:
        bad_license_name_string = list(bad_license_name.keys())
        bad_license_name_string = '\n'.join(bad_license_name_string)
        print('The following license names are not found in the biotools schema:')
        print(bad_license_name_string)

# In references:
# 0: pubmed id/doi -> "publications": {"publicationsPrimaryID":
# or if more than one the following goes into -> "publications": {"publicationsOtherID": [
# 5: name -> "name":
    # Open references CSV:
    with open(args.references, 'rb') as csvfile:
        references = csv.reader(csvfile, delimiter=',', quotechar='"')
        # Skip first line:
        next(references, None)
        for line_count, row in enumerate(references):
            tool = row[5].lower()
            # If the tool is seen in the tools.csv file it is noted:
            if tool in all_tools:
                all_tools.remove(tool)
                remove_tools.append(tool)
            # The tool have already been seen and just have multiple references:
            elif tool in remove_tools:
                pass
            # The tool has a reference but no entry in tools.csv
            else:
                info_string = '{:<40} on line: {:>3} in the references.csv file'.format(tool, str(line_count + 2))
                in_ref_not_in_tools.append(info_string)

            # If publication exists in file:
            if row[0]:
                # If tool exists in list of tools:
                if tool in all_resources:
                    # Take the first reference as the "publicationsPrimaryID", subsequent references are "publicationsOtherID":
                    if 'publicationsPrimaryID' not in all_resources[tool]['publications']:
                        all_resources[tool]['publications']['publicationsPrimaryID'] = row[0]                          # add primary publication
                    # If publicationsPrimaryID is already entered, put additional publications here:
                    else:
                        all_resources[tool]['publications']['publicationsOtherID'].append(row[0])                      # add other publications
                elif not tool:
                    continue
                else:
                    # These tools will be found and flagged by the "in_ref_not_in_tools" list
                    pass

    # Find the tools not seen in the references.csv file (this can be valid e.g. if a tool does not yet have an url):
    in_tools_not_in_ref = list()
    for tool in all_tools:
        line = tools2line[tool]
        info_string = '{:<40} on line: {:>3} in the tools.csv file'.format(tool, line)
        in_tools_not_in_ref.append(info_string)

    # Rebuilt the full list of tools in the tools.csv file:
    all_tools = list(all_resources.keys())
    remove_tools = list()
    in_url_not_in_tools = list()

# In urls:
# 1: name -> "name":
# 2: url type
# * Homepage -> "homepage":
# * Manual -> "docs": {"docsHome":
# Mailing list -> thrash this
# * Binaries -> "docs": {"docsDownloadBinaries":
# * Analysis server -> "homepage":
# * Source code -> -> "docs": {"docsDownloadSource":
# * HOWTO: -> "docs": {"docsHome":
# * Publication full text -> "docs": {"docsHome":
# * Description -> "docs": {"docsHome":
# Related -> thrash this
# * White Paper -> "docs": {"docsHome":
# 4: url
    # Open URLs CSV:
    with open(args.urls, 'rb') as csvfile:
        urls = csv.reader(csvfile, delimiter=',', quotechar='"')
        # Skip first line:
        next(urls, None)
        for line_count, row in enumerate(urls):
            # If url exists in file:
            if row[4]:
                tool = row[1].lower()
                # If the tool is seen in the tools.csv file it is noted:
                if tool in all_tools:
                    all_tools.remove(tool)
                    remove_tools.append(tool)
                # The tool have already been seen and just have multiple references:
                elif tool in remove_tools:
                    pass
                # The tool has a url but no entry in tools.csv
                else:
                    info_string = '{:<40} on line: {:>3} in the urls.csv file'.format(tool, str(line_count + 2))
                    in_url_not_in_tools.append(info_string)

                # If tool exists in list of tools:
                if tool in all_resources:
                    if row[2] == "Homepage" or row[2] == 'Analysis server':
                        all_resources[tool]['homepage'] = row[4]                                                       # add homepage
                    elif row[2] == "Manual" or row[2] == "HOWTO" or row[2] == "Publication full text" or row[2] == "Description" or row[2] == "White Paper":
                        all_resources[tool]['docs']['docsHome'] = row[4]                                               # add docs home
                    elif row[2] == "Binaries":
                        all_resources[tool]['docs']['docsDownloadBinaries'] = row[4]                                   # add docs download binaries
                    elif row[2] == "Source code":
                        all_resources[tool]['docs']['docsDownloadSource'] = row[4]                                     # add docs download source
                    else:
                        # Other links are thrashed:
                        pass
                elif not tool:
                    continue
                else:
                    # These tools will be found and flagged by the "in_url_not_in_tools" list
                    pass

    # Find the tools not seen in the urls.csv file (this can be valid e.g. if a tool does not yet have an url):
    in_tools_not_in_url = list()
    for tool in all_tools:
        line = tools2line[tool]
        info_string = '{:<40} on line: {:>3} in the tools.csv file'.format(tool, line)
        in_tools_not_in_url.append(info_string)

    # Print the nokey tools:
    if args.nokey:
        print('###### In references.csv but not in tools.csv: ######\n{}\n'.format('\n'.join(in_ref_not_in_tools)))
        print('###### In urls.csv but not in tools.csv: ######\n{}\n'.format('\n'.join(in_url_not_in_tools)))
        print('###### In tools.csv but not in references.csv: ######\n{}\n'.format('\n'.join(in_tools_not_in_ref)))
        print('###### In tools.csv but not in urls.csv: ######\n{}'.format('\n'.join(in_tools_not_in_url)))

    # Print small stats report:
    if args.stats:
        # If the specified filename does not exist create it along with a header:
        if not os.path.isfile(args.stats):
            with open(args.stats, 'w') as statfile:
                header = ['Timestamp', 'Total tools', 'No ref.', 'No url', 'No license', 'No operation', 'No topic', 'No email', 'No lang.', 'No interface', 'No description']
                statfile.write('{}\n'.format('\t'.join(header)))
        # Now print the stats and a timestamp:
        with open(args.stats, 'a') as statfile:
            stat_list = make_stats(all_resources)
            stat_list.insert(0, timestamp())
            stat_list = list(map(str, stat_list))
            statfile.write('{}\n'.format('\t'.join(stat_list)))

    # Convert the lower case tool keys to original case
    for tool in list(all_resources.keys()):
        Tool = tool2case[tool]
        all_resources[Tool] = all_resources[tool]
        del all_resources[tool]

    # Print to outfile:
    if args.out:
        with open(args.out, 'w') as outfile:
            outfile.write('{0}'.format(json.dumps(all_resources)))
        with open(args.out + '_pretty', 'w') as outfile:
            outfile.write('{0}'.format(json.dumps(all_resources, sort_keys=True, indent=4, separators=(',', ': '))))
            # print(json.dumps(all_resources, sort_keys=True, indent=4, separators=(',', ': ')))

    #######################################
    ## Enter username and password here: ##
    username = 'xxx'
    password = 'xxx'
    #######################################

    # # request access token
    token = authentication(username, password)

    # # upload tool
    for count, resource in enumerate(all_resources):
        import_resource(token, json.JSONEncoder().encode(resource), (count + 1))

# What are in the three SeqWIKI input files and how do the map to the EDAM JSON format:

# In tools:
# 0: name -> "name":
# 2: operations -> "function": [ "functionName": [ uri, term
# 3: topics -> "topic": [ uri, term
# 5: developer -> "credits": { "creditsDeveloper": [
# 6: email -> "contact": [{"contactEmail":
# 7: input format -> "function": [{"input": [{"dataFormat": [{
# 8: institute -> "credits": { "creditsInstitution": [
# 9: interface -> "interface": [{"interfaceType":
# 10: language -> "language": [
# 12: license -> "license":
# 13: maintained -> "maturity":
# 16: operating system -> "platform": [
# 17: output format -> "function": [{"output": [{"dataFormat": [{
# 21: resource type -> "resourceType": [
# 23: summary -> "description":

# In references:
# 0: pubmed id/doi -> "publications": {"publicationsPrimaryID":
# or if more than one the following goes into -> "publications": {"publicationsOtherID": [
# 5: name -> "name":

# In urls:
# 1: name -> "name":
# 2: url type
# Homepage -> "homepage":
# Manual -> "docs": {"docsHome":
# Mailing list -> thrash this
# Binaries -> "docs": {"docsDownloadBinaries":
# Analysis server -> "homepage":
# Source code -> -> "docs": {"docsDownloadSource":
# HOWTO: -> "docs": {"docsHome":
# Publication full text -> "docs": {"docsHome":
# Description -> "docs": {"docsHome":
# Related -> thrash this
# White Paper -> "docs": {"docsHome":
# 4: url
