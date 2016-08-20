library(biocViews)
library(graph)
library(XML)

setwd("/home/veit/devel/Proteomics/ELIXIR_EDAM/DataRetrieval")

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

# OBSERVATIONS: No format data type EDAM terms

msutils$interface[msutils$interface == "offline"] <- NA
msutils$description[msutils$description == ""] <- NA
msutils$email[msutils$email == ""] <- NA


###############################################

FullPcks <- msutils
xml_out = newXMLNode("resources",attrs=list("xsi:schemaLocation"="http://biotoolsregistry.org ../biotools-1.1.xsd"))
for (i in 1:nrow(FullPcks)) {
  currTool <- FullPcks[i,]
  if (!is.na(currTool["description"]) && !is.na(currTool["name"]) && grepl("http",currTool["link"]) && 
      !is.na(currTool["interface"]) && !(grepl("not",currTool["interface"])) && !is.na(currTool["email"])) {
    
    tnode <- newXMLNode("resource",parent=xml_out)
    
    
    ###### DELETE CHARACTER "!" TOOL NAMES (ONLY TEMPORARILY)
    currTool$name <- sub("\\!","",currTool$name)
    
    newXMLNode("name",parent=tnode,text=sub("\\(.*","",currTool["name"]))
    
    newXMLNode("homepage",parent=tnode,text=currTool["link"])
    if (!is.na(currTool$weblink) & currTool$weblink != "") {
      newXMLNode("mirror",parent=tnode,text=currTool$weblink)
    }
    newXMLNode("collection",parent=tnode,text="ms-utils.org")
    newXMLNode("accessibility",parent=tnode,text="Public")
    
    ## split interfaces "Linux distribution" and "Library" into resourceType
    if (currTool$interface == "Linux distribution") {
      newXMLNode("resourceType",parent=tnode,text="Platform")
      interface_list <- c("Command line","Desktop GUI")
      for (e in unlist(interface_list)) {
        tnode2 <- newXMLNode("interface",parent=tnode)
        newXMLNode("interfaceType",parent=tnode2,text=e)
      }
    } else if (currTool$interface == "Library") {
      newXMLNode("resourceType",parent=tnode,text="Library")
      interface_list <- c("Command line")
      for (e in unlist(interface_list)) {
        tnode2 <- newXMLNode("interface",parent=tnode)
        newXMLNode("interfaceType",parent=tnode2,text=e)
      }
    } else if (currTool$interface == "iOS app") {
      newXMLNode("resourceType",parent=tnode,text="Library")
      interface_list <- c("Desktop GUI")
      for (e in unlist(interface_list)) {
        tnode2 <- newXMLNode("interface",parent=tnode)
        newXMLNode("interfaceType",parent=tnode2,text=e)
      }
    } else {
      newXMLNode("resourceType",parent=tnode,text="Tool")
      interface_list <- strsplit(as.character(currTool$interface), "\\|")
      for (e in unlist(interface_list)) {
        tnode2 <- newXMLNode("interface",parent=tnode)
        newXMLNode("interfaceType",parent=tnode2,text=e)
      }
    }
    newXMLNode("description",parent=tnode,text=gsub('\n'," ",currTool["description"]))
    
    ## write EDAM terms if available, else write most general one
    if (is.na(currTool$EDAM.topic) | currTool$EDAM.topic == "") {
      newXMLNode("topic",parent=tnode,text="Topic",attrs=list(uri="http://edamontology.org/topic_0003"))
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.topic), "\\|")
      for (e in unlist(edam_list)) 
        e <- gsub(" ","",e,)
      newXMLNode("topic",parent=tnode,text="Topic",
                   attrs=list(uri=paste("http://edamontology.org/",e, sep="")))
    }
    tnode2 <- newXMLNode("function",parent=tnode)
    if (is.na(currTool$EDAM.operation) | currTool$EDAM.operation == "") {
      newXMLNode("functionName",parent=tnode2,text="Operation",attrs=list(uri="http://edamontology.org/operation_0004"))
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.operation), "\\|")
      for (e in unlist(edam_list)) 
        e <- gsub(" ","",e,)
      newXMLNode("functionName",parent=tnode2,text="Operation",
                   attrs=list(uri=paste("http://edamontology.org/",e, sep="")))
    }
    tnode3 <- newXMLNode("input",parent=tnode2)
    newXMLNode("dataType",parent=tnode3,text="Data",attrs=list(uri="http://edamontology.org/data_0006"))
    if (is.na(currTool$EDAM.data.format.in) | currTool$EDAM.data.format.in == "") {
      newXMLNode("dataFormat",parent=tnode3,text="Format",attrs=list(uri="http://edamontology.org/format_1915"))
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.data.format.in), "\\|")
      for (e in unlist(edam_list)) 
        e <- gsub(" ","",e,)
        newXMLNode("dataFormat",parent=tnode3,text="Format",
                   attrs=list(uri=paste("http://edamontology.org/",e, sep="")))
    }
    tnode3 <- newXMLNode("output",parent=tnode2)
    newXMLNode("dataType",parent=tnode3,text="Data",attrs=list(uri="http://edamontology.org/data_0006"))
    if (is.na(currTool$EDAM.data.format.out) | currTool$EDAM.data.format.out == "") {
      newXMLNode("dataFormat",parent=tnode3,text="Format",attrs=list(uri="http://edamontology.org/format_1915"))
    } else {
      edam_list <- strsplit(as.character(currTool$EDAM.data.format.out), "\\|")
      for (e in unlist(edam_list)) 
        e <- gsub(" ","",e,)
      newXMLNode("dataFormat",parent=tnode3,text="Format",
                   attrs=list(uri=paste("http://edamontology.org/",e, sep="")))
    }
    newXMLNode("dataFormat",parent=tnode3,text="Format",attrs=list(uri="http://edamontology.org/format_1915"))
    
    maintainers <- strsplit(as.character(currTool["email"]),"\\|")
    for (m in unlist(maintainers)) {
      if (m != " " & m != "" & !is.na(m) & !is.na(m)) {
        if(!is.na(m)) {
          tnode2 <- newXMLNode("contact",parent=tnode)
          newXMLNode("contactEmail",parent=tnode2,text=m)
          newXMLNode("contactRole",parent=tnode2,text="Maintainer")
        }
      }
    }
    
    newXMLNode("sourceRegistry",parent=tnode,text="http://ms-utils.org")
    
    
    if (!is.na(currTool["lang"]) & currTool$lang != "" & currTool$lang != "Excel") {
      lang_list <- unlist(strsplit(as.character(currTool$lang), "\\/"))
      for (e in lang_list) {
        if (e == "Visual C++")
          e <- "C++"
        if (e == "VC")
          e <- "C"
        newXMLNode("language",parent=tnode,text=e)
      }
    }
    
    if (!is.na(currTool["license"]) & currTool$license != "") {
      newXMLNode("license",parent=tnode,text=gsub('\n'," ",currTool["license"]))
    }
    
    newXMLNode("cost",parent=tnode,text="Free")
    
    if (!is.na(currTool$source) & currTool$source != "") {
      tnode2 <- newXMLNode("docs",parent=tnode)
      newXMLNode("docsDownloadSource",parent=tnode2,text=currTool$source)
    }
    
    if (!is.na(currTool["paper"]) & currTool$paper != "") {
      tnode2 <- newXMLNode("publications",parent=tnode)
      pub_list <- unlist(strsplit(as.character(currTool$paper), "\\|"))
      for (e in pub_list) {
        if (which(e==pub_list) == 1)
          newXMLNode("publicationsPrimaryID",parent=tnode2,text=e)
        else 
          newXMLNode("publicationsOtherID",parent=tnode2,text=e)
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


### PROBLEMS SO FAR:
# too many links in wiki file (especially description), sometimes getting the wrong one.
# publication link not always ID (DOI or PubMed)
# ELIXIR: where do I put link to source code?

