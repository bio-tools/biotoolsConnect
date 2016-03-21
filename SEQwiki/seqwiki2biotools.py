import csv
import argparse
import json
import re
import urllib, urllib2
from sys import exit


def authentication(username, password):
    """
    Returns authentication token.
    """
    login_info = '{' + '"username": "{}","password": "{}"'.format(username, password) + '}'
    url = 'http://elixir-registry-demo.cbs.dtu.dk/auth/login'
    request = rest_service(url, login_info)

    try:
        handler = urllib2.urlopen(request)
        print('Authentication: Success')

    except urllib2.HTTPError as e:
        print('Authentication: Error {}\t{}'.format(e.code, e.reason))
        exit()

    token = json.loads(handler.read())['token']
    return token


def import_resource(auth_token, json_string, count):
    """
    Imports a single resource to the elixir database.
    """

    url = 'http://elixir-registry-demo.cbs.dtu.dk/tool'
    auth = 'Token ' + auth_token
    header = {'Authorization': auth}

    request = rest_service(url, json_string, header)

    try:
        handler = urllib2.urlopen(request)
        print('[{}] Resource upload: Success'.format(count))

    # Error handling
    except urllib2.HTTPError as e:
        if e.code == 400:
            error = json.loads(e.read())
            print('[{}] Resource upload: Error'.format(count))
            error_print(error['fields'], '/')
        else:
            print('[{}] Resource upload: Error {}\t{}'.format(count, e.code, e.reason))


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
    stat_list = [0, 0, 0, 0, 0, 0, 0, 0, 0]
    for tool in all_resources.keys():
        stat_list[0] += stat_list[0] + 1
        if 'publicationsPrimaryID' not in all_resources[tool]['publications'] or not all_resources[tool]['publications']['publicationsPrimaryID']:
            stat_list[1] += stat_list[1] + 1
        if 'homepage' not in all_resources[tool] or not all_resources[tool]['homepage']:
            stat_list[2] += stat_list[2] + 1
        if not all_resources[tool]['platform']:
            stat_list[3] += stat_list[3] + 1
        if 'license' not in all_resources[tool] or not all_resources[tool]['license']:
            stat_list[4] += stat_list[4] + 1
        if not all_resources[tool]['function'][0]:
            stat_list[5] += stat_list[5] + 1
        if not all_resources[tool]['topic']:
            stat_list[6] += stat_list[6] + 1
        if 'contact' not in all_resources[tool] or not all_resources[tool]['contact']:
            stat_list[7] += stat_list[7] + 1
        if 'language' not in all_resources[tool] or not all_resources[tool]['language']:
            stat_list[8] += stat_list[8] + 1

    return(stat_list)


if __name__ == '__main__':
    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("-tool", help="Tool CSV dump file obtained from http://seqanswers.com/wiki/Software/Dumps")
    parser.add_argument("-references", help="Reference CSV dump file obtained from http://seqanswers.com/wiki/Software/Dumps")
    parser.add_argument("-urls", help="URL CSV dump file obtained from http://seqanswers.com/wiki/Software/Dumps")
    parser.add_argument("-edam", help="EDAM CSV dump file obtained from http://bioportal.bioontology.org/ontologies/EDAM/?p=summary")
    parser.add_argument("-out", help="Output file name.")
    parser.add_argument("-mix", help="Print mix between operations and topics or formats and data; 0/1.")
    parser.add_argument("-mis", help="Print mismatches between operations/topics/formats seen in SeqWIKI vs. the valid concepts in EDAM; 0/1.")
    args = parser.parse_args()

    all_resources = {}
    tool2case = {}

    # Define the dictionaries to store the keys to the concept dictionary:
    t_label2key = dict()
    o_label2key = dict()
    d_label2key = dict()  # Notice that data type is not part of SeqWIKI. It is left here for completeness
    f_label2key = dict()
    # Line number as key to a list of information about the term:
    concept = dict()
    t_label2key, o_label2key, d_label2key, f_label2key, concept = fill_label2key(args.edam, t_label2key, o_label2key, d_label2key, f_label2key, concept)

    all_topics = [x.lower() for x in t_label2key.keys()]
    all_operations = [x.lower() for x in o_label2key.keys()]
    all_data = [x.lower() for x in d_label2key.keys()]
    all_formats = [x.lower() for x in f_label2key.keys()]

    topic_operation_overlap = list(set(all_topics) & set(all_operations))
    format_data_overlap = list(set(all_formats) & set(all_data))

    # SeqWIKI terminology to EDAM:
    # Bioinformatics method = operation
    # Biological domain = topic

    # Open tools CSV
    with open(args.tool, 'rb') as csvfile:
        tools = csv.reader(csvfile, delimiter=',', quotechar='"')
        # Skip first line
        next(tools, None)
        for row in tools:
            # Convert the tool name to lower case but first store the original case name in tool2case dict:
            tool = row[0]
            if tool in tool2case:
                print('Houston we have a duplicate!')
            else:
                tool2case[tool.lower()] = tool
            tool = tool.lower()

            resource = {}
            resource['name'] = tool2case[tool]                                                              # name
            resource['resourceType'] = []                                                                   # resource type
            resource['resourceType'].append({'term': 'Tool'})

            resource['function'] = []                                                                       # create function list
            resource['function'].append({})                                                                 # add 1 function

            # Fill in all the EDAM operations/functions:
            resource['function'][0]['functionName'] = []                                                    # create function name list
            resource['function'][0]['functionDescription'] = ''                                             # no current function description in SeqWIKI
            for functionName in row[2].split(','):                                                          # iterate over function names
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
                resource['function'][0]['functionName'].append({'term': pref_label})                    # add function names using the preferred label
                resource['function'][0]['functionName'].append({'uri': uri})                            # add function uri

            resource['description'] = row[21]                                                               # description
            resource['description'] = row[23] if not row[21] else (row[21] + '\n\n' + row[23])              # description continued
            # Make a string find to find the optimal license:
            resource['license'] = row[12]                                                                   # license
            resource['maturity'] = 'Supported' if row[13] == "Yes" else 'Not supported'                     # maturity

            # Fill in all the EDAM input formats:
            resource['function'][0]['input'] = []                                                           # create input list
            for input1 in row[7].split(','):                                                                # iterate over inputs
                input1 = input1.lower()
                dataFormat = []                                                                         # create list for data format
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
                dataFormat.append({'term': input1})                                                     # add input EDAM term to data format list
                dataFormat.append({'uri': uri})                                                         # add input EDAM term to data format list
                resource['function'][0]['input'].append({'dataFormat': dataFormat})                     # add data format list to input list

            # Fill in all the EDAM output formats:
            resource['function'][0]['output'] = []                                                           # create output list
            for output1 in row[7].split(','):                                                                # iterate over outputs
                output1 = output1.lower()
                dataFormat = []                                                                         # create list for data format
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
                dataFormat.append({'term': output1})                                                     # add output EDAM term to data format list
                dataFormat.append({'uri': uri})                                                         # add output EDAM term to data format list
                resource['function'][0]['output'].append({'dataFormat': dataFormat})                     # add data format list to input list

            resource['platform'] = []                                                                       # create platform list
            for platform in row[16].split(','):                                                             # iterate over platforms
                if platform:
                    if re.match('windows', platform, re.IGNORECASE):                                        # map platforms to ELIXIR
                        resource['platform'].append('Windows')
                    if re.match('linux', platform, re.IGNORECASE):                                          # map platforms to ELIXIR
                        resource['platform'].append('Linux')
                    if re.match('mac', platform, re.IGNORECASE):                                            # map platforms to ELIXIR
                        resource['platform'].append('Mac')
                    if re.match('unix', platform, re.IGNORECASE):                                           # map platforms to ELIXIR
                        resource['platform'].append('Unix')
                    if re.match('any|independent|cross|browser', platform, re.IGNORECASE):                  # map those stupid SeqWIKI platforms names to ELIXIR
                        resource['platform'].extend(['Windows', 'Linux', 'Mac', 'Unix'])
                else:
                    pass

            # Fill in all the EDAM topics:
            resource['topic'] = []                                                                          # create topic list
            for topic in row[3].split(','):                                                                 # iterate over topics
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
                resource['topic'].append({'term': topic})                                               # add topics
                resource['topic'].append({'uri': uri})                                                  # add uri

            resource['language'] = []                                                                       # create language list
            for language in row[10].split(','):                                                              # iterate over languages
                if language:
                    resource['language'].append(language)                                                   # add languages

            resource['credits'] = {}                                                                        # create credits grouping
            resource['credits']['creditsDeveloper'] = []                                                    # create credits developer list
            for creditsDeveloper in row[5].split(','):                                                      # iterate over credits developers
                if creditsDeveloper:
                    resource['credits']['creditsDeveloper'].append(creditsDeveloper)                        # add credits developers

            resource['credits']['creditsInstitution'] = []                                                  # create credits institution list
            for creditsInstitution in row[8].split(','):                                                    # iterate over credits institutions
                if creditsInstitution:
                    resource['credits']['creditsInstitution'].append(creditsInstitution)                    # add credits institution

            resource['contact'] = []                                                                        # create contact list
            for contactEmail in row[6].split(','):                                                          # iterate over contact emails
                if contactEmail:
                    resource['contact'].append({'contactEmail': contactEmail})                              # add contact emails

            resource['publications'] = {}                                                                   # create publications grouping
            resource['publications']['publicationsOtherID'] = []                                            # create publications other id list

            resource['docs'] = {}                                                                           # create docs grouping

            # Add tool to global dictionary
            all_resources[tool] = resource

    # Open references CSV
    with open(args.references, 'rb') as csvfile:
        references = csv.reader(csvfile, delimiter=',', quotechar='"')
        # Skip first line
        next(references, None)
        for row in references:
            tool = row[5].lower()
            # If publication exists in file
            if row[4]:
                # if tool exists in list of tools
                if tool in all_resources:
                    # If publicationsPrimaryID is not entered, enter it first
                    if 'publicationsPrimaryID' not in all_resources[tool]['publications']:
                        all_resources[tool]['publications']['publicationsPrimaryID'] = row[4]             # add primary publication
                    # If publicationsPrimaryID is already entered, put additional publications here
                    else:
                        all_resources[tool]['publications']['publicationsOtherID'].append(row[4])         # add other publications
                elif not tool:
                    continue
                else:
                    continue  # Leave this for now
                    print('Tool in reference file not found:')
                    print(tool)

    # Open URLs CSV
    with open(args.urls, 'rb') as csvfile:
        urls = csv.reader(csvfile, delimiter=',', quotechar='"')
        # skip first line
        next(urls, None)
        for row in urls:
            # If url exists in file
            if row[4]:
                tool = row[1].lower()
                # If tool exists in list of tools
                if tool in all_resources:
                    if row[2] == "Homepage":
                        all_resources[tool]['homepage'] = row[4]                                          # add homepage
                    elif row[2] == "Manual":
                        all_resources[tool]['docs']['docsHome'] = row[4]                                  # add docs home
                    else:
                        all_resources[tool]['docs']['docsDownload'] = row[4]                              # add docs download
                elif not tool:
                    continue
                else:
                    continue  # Leave this for now
                    print('Tool in url file not found:')
                    print(tool)
                    # print(row)

    stat_list = list()
    stat_list = make_stats(all_resources)
    #### HERE convert the lower case tool keys to original case
    # Print to outfile:
    with open(args.out, 'w') as outfile:
        outfile.write('{0}'.format(json.dumps(all_resources)))
        # print(json.dumps(all_resources))


    #######################################
    ## Enter username and password here: ##
    username = '123'
    password = '123'
    #######################################

    # # request access token
    # token = authentication(username,password)

    # # upload tool
    # for count, resource in enumerate(all_resources):
    #     import_resource(token, json.JSONEncoder().encode(resource), (count+1))
