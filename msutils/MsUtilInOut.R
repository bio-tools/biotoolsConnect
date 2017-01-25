## Script to import the content of ms-utils.org into bio.tools
##
## Update: Adapted to bio.tools schema 2.0
## Not working: head of xml-file still requires substitution of "xmlns:xmlns" to "xmlns"


library(biocViews)
library(graph)
library(XML)
library(ontologyIndex)

setwd("/home/veit/devel/Proteomics/ELIXIR_EDAM/DataRetrieval")

############### get recent EDAM ontology for mapping of terms
system("wget http://edamontology.org/EDAM.owl")
EDAM <- get_OWL("EDAM.owl")

## Remove obsolete terms
EDAM$id <- EDAM$id[!EDAM$obsolete]
EDAM$name <- EDAM$name[!EDAM$obsolete]
EDAM$parents <- EDAM$parents[!EDAM$obsolete]
EDAM$children <- EDAM$children[!EDAM$obsolete]
EDAM$ancestors <- EDAM$ancestors[!EDAM$obsolete]
EDAM$obsolete <- EDAM$obsolete[!EDAM$obsolete]


############### DATA MSUTILS.ORG -> ELIXIR REGISTRY
# get data
system("wget http://www.ms-utils.org/wiki/pmwiki.php/Main/SoftwareList?action=source -O msutils.txt")
system("sed -i 's/||/@/g' msutils.txt")
msutils <- read.csv("msutils.txt",sep="@",skip=1,row.names=NULL,stringsAsFactors = F,quote="")
tempstr <- NA
for (i in 1:nrow(msutils)) {
  if(length(grep("[++",msutils[i,2],fixed = T))>0) {
    tempstr <- gsub("+","",gsub("]","",gsub("[","",as.character(msutils[i,2]),fixed=T),fixed=T),fixed=T)
  }
  msutils[i,1] <- tempstr
}
msutils <- msutils[msutils[,3]!="",]
colnames(msutils) <- c("Category","link","description","lang","interface","name","Email")

msutils$name <- sapply(msutils[,2],function(x) gsub("\\]","",strsplit(x,"\\|")[[1]][2]))
msutils$link <- sapply(msutils[,2],function(x) gsub("\\[","",strsplit(x,"\\|")[[1]][1]))
#msutils$name <- unlist(...)
msutils$source <- msutils$paper <- msutils$weblink <- msutils$email <- NA
for (i in 1:nrow(msutils)) {
  ttt <- msutils$lang[i]
  msutils$source[i] <- msutils$lang[i] <- NA
  if (length(grep("\\[",ttt))>0) {
    msutils$source[i] <- gsub("\\[","",strsplit(ttt,"\\|")[[1]][1])
    msutils$lang[i] <- gsub("\\]","",strsplit(ttt,"\\|")[[1]][2])
  } else if (nchar(gsub(" ","",ttt))>0) {
    msutils$lang[i] <- ttt
  }
  ttt <- msutils$interface[i]
  msutils$weblink[i] <- msutils$interface[i] <- NA
  if (length(grep("\\[",ttt))>0) {
    msutils$weblink[i] <- gsub("\\[","",strsplit(ttt,"\\|")[[1]][1])
    msutils$interface[i] <- gsub("\\]","",strsplit(ttt,"\\|")[[1]][2])
  } else  if (nchar(gsub(" ","",ttt))>0) {
    msutils$interface[i] <- ttt
  }
  ttt <- msutils$description[i]
  msutils$paper[i] <- NA
  if (length(grep("\\[",ttt))>0) {
    if (length(grep("pubmed",ttt))>0) {
      tpaper <-  regmatches(ttt,gregexpr("www[a-z,\\.]*/pubmed/[0-9]*",ttt))
      # multiple entries are separated by "|"
      msutils$paper[i] <- paste(grep("[0-9]",unlist(lapply(tpaper,function(x) strsplit(x,"pubmed/"))),value=T),collapse="|")
    } else if (length(grep("dx\\.doi",ttt))>0) {
      tpaper <-  regmatches(ttt,gregexpr("dx\\.doi[a-z,\\.]*/[0-9\\.]*/[0-9,a-z,A-Z,\\.]*",ttt))[[1]]
      tpaper <- strsplit(tpaper,"/")
      msutils$paper[i] <- tpaper[[1]][length(tpaper[[1]])]
    }
    
    msutils$description[i] <- gsub("\\#","",gsub("\\]\\]","",gsub("\\[\\[[a-z,0-9,\\.,\\/,\\:,\\#,\\A-Z]*\\|","",ttt)))
  }
}

write.csv(msutils,"msutils.csv")

############# temporary solution to read from csv-file
msutils <- read.csv("msutils_with_EDAM - msutils_tools - temporary solution.csv", stringsAsFactors = F)

msutils$interface[msutils$interface == "offline"] <- NA
msutils$description[msutils$description == ""] <- NA
msutils$email[msutils$email == ""] <- NA

###############################################

## remove duplicates
FullPcks <- FullPcks[!duplicated(FullPcks$name), ]

FullPcks <- msutils
xml_out = newXMLNode(name="tools",namespace=list(xmlns="http://bio.tools"),namespaceDefinitions = list("xsi"="http://www.w3.org/2001/XMLSchema-instance"),attrs = list("xsi:schemaLocation"="http://bio.tools biotools-2.0-beta-04.xsd"))
for (i in 1:nrow(FullPcks)) {
  currTool <- FullPcks[i,]
  # Check for minimal requirements of schema
  if (!is.na(currTool["name"])  && grepl("http",currTool["link"]) && !is.na(currTool["description"]) && 
      !is.na(currTool["interface"]) && !(grepl("not",currTool["interface"]))) {
    
    tnode <- newXMLNode("tool",parent=xml_out)
    tnode2 <- newXMLNode("summary",parent=tnode)
    ## need to remove ! from name as well
    currTool$name <- gsub("\\!","",currTool$name)
    newXMLNode("name",parent=tnode2,text=sub("\\(.*","",currTool["name"]))
    ###### tool id without special characters and spaces (_ instead), max. 12 characters
    currTool$toolID <- gsub("\\!","",currTool$name)
    currTool$toolID <- gsub(" ","_",currTool$toolID)
    currTool$toolID <- gsub("\\+","Plus",currTool$toolID)
    currTool$toolID <- gsub("\\.","",currTool$toolID)
    currTool$toolID <- strtrim(currTool$toolID,12)
    newXMLNode("toolID",parent=tnode2,text=sub("\\(.*","",currTool["toolID"]))
    newXMLNode("shortDescription",parent=tnode2,text=gsub('\n'," ",currTool["description"]))
    newXMLNode("description",parent=tnode2,text=gsub('\n'," ",currTool["description"]))
    newXMLNode("homepage",parent=tnode2,text=currTool["link"])
    
    ## Probably need to adapt to allow multiple functions with different input/output in future
    tnode2 <- newXMLNode("function",parent=tnode)
    if (is.na(currTool$EDAM.operation) | currTool$EDAM.operation == "") {
      tnode3 <- newXMLNode("operation",parent=tnode2)
      alt_name <- "http://edamontology.org/operation_0004"
      newXMLNode("uri",parent=tnode3,alt_name)
      newXMLNode("term",parent=tnode3,EDAM$name[alt_name])
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.operation), "\\|")
      for (e in unlist(edam_list)) {
        e <- gsub(" ","",e)
        tnode3 <- newXMLNode("operation",parent=tnode2)
        edam_name <- paste("http://edamontology.org/",e, sep="")
        newXMLNode("uri",parent=tnode3,edam_name)
        newXMLNode("term",parent=tnode3,EDAM$name[edam_name])
      }
    }
    tnode3 <- newXMLNode("input",parent=tnode2)
    ### Data terms still to come
    # if (is.na(currTool$EDAM.data) | currTool$EDAM.data == "")
    tnode4 <- newXMLNode("data",parent=tnode3)
    alt_name <- "http://edamontology.org/data_0006"
    newXMLNode("uri",parent=tnode4, alt_name)
    newXMLNode("term",parent=tnode4, EDAM$name[alt_name])
    if (is.na(currTool$EDAM.data.format.in) | currTool$EDAM.data.format.in == "") {
      tnode4 <- newXMLNode("format",parent=tnode3)
      alt_name <- "http://edamontology.org/format_1915"
      newXMLNode("uri",parent=tnode4, alt_name)
      newXMLNode("term",parent=tnode4, EDAM$name[alt_name])
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.data.format.in), "\\|")
      for (e in unlist(edam_list)) {
        e <- gsub(" ","",e)
        tnode4 <- newXMLNode("format",parent=tnode3)
        edam_name <- paste("http://edamontology.org/",e, sep="")
        newXMLNode("uri",parent=tnode4, edam_name)
        newXMLNode("term",parent=tnode4, EDAM$name[edam_name])
      }
    }
    tnode3 <- newXMLNode("output",parent=tnode2)
    ### Data terms still to come
    # if (is.na(currTool$EDAM.data) | currTool$EDAM.data == "")
    tnode4 <- newXMLNode("data",parent=tnode3)
    alt_name <- "http://edamontology.org/data_0006"
    newXMLNode("uri",parent=tnode4, alt_name)
    newXMLNode("term",parent=tnode4, EDAM$name[alt_name])
    if (is.na(currTool$EDAM.data.format.out) | currTool$EDAM.data.format.out == "") {
      tnode4 <- newXMLNode("format",parent=tnode3)
      alt_name <- "http://edamontology.org/format_1915"
      newXMLNode("uri",parent=tnode4, alt_name)
      newXMLNode("term",parent=tnode4, EDAM$name[alt_name])
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.data.format.out), "\\|")
      for (e in unlist(edam_list)) {
        e <- gsub(" ","",e)
        tnode4 <- newXMLNode("format",parent=tnode3)
        edam_name <- paste("http://edamontology.org/",e, sep="")
        newXMLNode("uri",parent=tnode4, edam_name)
        newXMLNode("term",parent=tnode4, EDAM$name[edam_name])
      }
    }
    
    tnode2 <- newXMLNode("labels",parent=tnode)
    ##  transform special interfaces
    interface_list <- strsplit(as.character(currTool$interface), "\\|")
    for (e in unlist(interface_list)) {
      if (e == "Linux distribution") {
        newXMLNode("toolType",parent=tnode2,text="Suite")
      } else if (e == "iOS app") {
        newXMLNode("toolType",parent=tnode2,text="Desktop application")
      } else {
        ## CHECK NAMES
        newXMLNode("toolType",parent=tnode2,text = e)
      }
    }
    
    ## write EDAM terms if available, else write most general one
    if (is.na(currTool$EDAM.topic) | currTool$EDAM.topic == "") {
      tnode3 <- newXMLNode("topic",parent=tnode2)
      alt_name <- "http://edamontology.org/topic_0003"
      newXMLNode("uri",parent=tnode3, alt_name)
      newXMLNode("term",parent=tnode3, EDAM$name[alt_name])
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.topic), "\\|")
      for (e in unlist(edam_list)) {
        e <- gsub(" ","",e,)
        tnode3 <- newXMLNode("topic",parent=tnode2)
        edam_name <- paste("http://edamontology.org/",e, sep="")
        newXMLNode("uri",parent=tnode3, edam_name)
        newXMLNode("term",parent=tnode3, EDAM$name[edam_name])
      }
    }
    if (!is.na(currTool["lang"]) & currTool$lang != "" & currTool$lang != "Excel") {
      lang_list <- unlist(strsplit(as.character(currTool$lang), "\\/"))
      for (e in lang_list) {
        if (e == "Visual C++")
          e <- "C++"
        if (e == "VC")
          e <- "C"
        newXMLNode("language",parent=tnode2,text=e)
      }
    }
    if (!is.na(currTool["SPDX.license.IDs"]) & currTool$license != "") {
      newXMLNode("license",parent=tnode2,text=gsub('\n'," ",currTool["SPDX.license.IDs"]))
    }
    newXMLNode("collectionID",parent=tnode2,text="ms-utils")
    # newXMLNode("cost",parent=tnode2,text="Free of charge")
    # newXMLNode("accessibility",parent=tnode2,text="Open access")
    
    if (!is.na(currTool$weblink) & currTool$weblink != "") {
      tnode2 <- newXMLNode("link",parent=tnode)
      newXMLNode("url",parent=tnode2,currTool$weblink)
      newXMLNode("type",parent=tnode2,"Mirror")
    }
    
    tnode2 <- newXMLNode("link",parent=tnode)
    newXMLNode("url",parent=tnode2,"http://ms-utils.org")
    newXMLNode("type",parent=tnode2,"Registry")
    
    if (!is.na(currTool$source) & currTool$source != "") {
      tnode2 <- newXMLNode("download",parent=tnode)
      newXMLNode("url",parent=tnode2,currTool$source)
      newXMLNode("type",parent=tnode2,"Source code")
    }
    
    if (!is.na(currTool["paper"]) & currTool$paper != "") {
      pub_list <- unlist(strsplit(as.character(currTool$paper), "\\|"))
      for (e in pub_list) {
        tnode2 <- newXMLNode("publication",parent=tnode)
        if (!grepl("/",e)) {
          newXMLNode("pmid",parent=tnode2,text=e)
        } else {
          newXMLNode("doi",parent=tnode2,text=e)
        }
      }
    }
    
    
    tnode2 <- newXMLNode("contact",parent=tnode)
    ## TBD:
    newXMLNode("email",parent=tnode2,text="webmaster@ms-utils.org")
    newXMLNode("url",parent=tnode2,text="ms-utils.org")
    
    maintainers <- strsplit(as.character(currTool["email"]),"\\|")
    for (m in unlist(maintainers)) {
      if (m != " " & m != "" & !is.na(m) & !is.na(m)) {
        if(!is.na(m)) {
          tnode2 <- newXMLNode("credit",parent=tnode)
          newXMLNode("name",parent=tnode2,"see publication")
          newXMLNode("email",parent=tnode2,text=m)
          newXMLNode("typeEntity",parent=tnode2,text="Person")
          newXMLNode("typeRole",parent=tnode2,text="Maintainer")
        }
      }
    }
  }
  
}


saveXML(xml_out,"FullMSUtils.xml")

############### ELIXIR REGISTRY -> MSUTILS.ORG 

url <- system("wget https://elixir-registry.cbs.dtu.dk/api/tool?format=xml -O FullElixir.xml")
FullRegistry <- xmlTreeParse("FullElixir.xml")
FullReg <- xmlToList(FullRegistry)

# Extract the ones with EDAM "Proteomics"

sublist <- NULL
tname <- "Proteomics"
for (i in 1:length(FullReg)) {
  tttt <- FullReg[[i]]
  topics <- tttt[which(names(tttt)== "topic")]
  if (length(topics) >= 1) {
    if(length(topics) == 1) {
      try(
        # print(topics$topic$text),
        if (topics$topic$text == tname)
          sublist <- c(sublist,list(tttt)))
    } else {
      for (j in 1:length(topics)) {
        try(if (topics[[j]]$text == tname)
          sublist <- c(sublist,list(tttt)))
      }
    }
  }
}

# Generate line for wiki file

textout <- ""
for (i in 1:length(sublist)) {
  
  ttt <- sublist[[i]]
  if(length(ttt$language)==0)
    ttt$language <- ""
  if(length(ttt$publications$publicationsPrimaryID)==0)
    ttt$publications$publicationsPrimaryID <- ""
  if(length(ttt$interface$interfaceType)==0)
    ttt$interface$interfaceType <- ""
  
  textout <- paste(textout,"\n","||[[",ttt$homepage,"|",ttt$name,"]]||",
                   ttt$description,"[[",ttt$publications$publicationsPrimaryID,"|#]]||",ttt$language,"||",
                   ttt$interface$interfaceType,"||"
                   ,sep="")
}

write(textout,"msutils_in.txt")



