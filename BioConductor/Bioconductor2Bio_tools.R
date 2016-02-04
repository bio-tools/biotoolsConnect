library(biocViews)
library(graph)
library(XML)


#Get biocViews:
example(getBiocViews)
# names: upper view -> lower views
A <- edges(biocViewsVocab)
outViews <- NULL
for (i in names(A)) {
  if (length(A[[i]])>0)
    outViews <- rbind(outViews,cbind(A[[i]],i))
}
write.csv(outViews,"allViews.csv")


# get views and packages:

# annotations
repos <- "http://bioconductor.org/packages/release/data/annotation" 
bv <- getBiocViews(repos, biocViewsVocab, "NoViewProvided")
# access description of package:
bv[[5]]@packageList[1]
pckOut <- NULL
pcks <- bv$AnnotationData@packageList
slots <- c("Title","Description","Version","Author","Maintainer","Depends","Imports","SystemRequirements",
           "License","URL","biocViews","source.ver","manuals","reposFullUrl","functionIndex")
for ( i in names(pcks)) {
  ttt <- i
  for (j in slots) {
    ttt <- append(ttt,paste(slot(pcks[[i]],j),collapse="|")) 
  }
  pckOut <- rbind(pckOut, ttt)
}
colnames(pckOut) <- c("Name",slots)
rownames(pckOut) <- 1:nrow(pckOut)
write.csv(pckOut,"Annotations.csv")
Annotations <- pckOut

# experimental data
repos <- "http://bioconductor.org/packages/release/data/experiment"
bv <- getBiocViews(repos, biocViewsVocab, "NoViewProvided")
pckOut <- NULL
pcks <- bv$ExperimentData@packageList
slots <- c("Title","Description","Version","Author","Maintainer","Depends","Imports","SystemRequirements",
           "License","URL","biocViews","source.ver","manuals","reposFullUrl","functionIndex")
for ( i in names(pcks)) {
  ttt <- i
  for (j in slots) {
    ttt <- append(ttt,paste(slot(pcks[[i]],j),collapse="|"))
  }
  pckOut <- rbind(pckOut, ttt)
}
colnames(pckOut) <- c("Name",slots)
rownames(pckOut) <- 1:nrow(pckOut)
write.csv(pckOut,"ExperimentData.csv")
Experiments <- pckOut

# software
repos <- "http://bioconductor.org/packages/release/bioc" 
bv <- getBiocViews(repos, biocViewsVocab, "NoViewProvided")
pckOut <- NULL
pcks <- bv$Software@packageList
slots <- c("Title","Description","Version","Author","Maintainer","Depends","Imports","SystemRequirements",
           "License","URL","biocViews","source.ver","manuals","reposFullUrl","functionIndex")
for ( i in names(pcks)) {
  ttt <- i
  for (j in slots) {
    ttt <- append(ttt,paste(slot(pcks[[i]],j),collapse="|"))
  }
  pckOut <- rbind(pckOut, ttt)
}
colnames(pckOut) <- c("Name",slots)
rownames(pckOut) <- 1:nrow(pckOut)
write.csv(pckOut,"Software.csv")
Software <- pckOut

############## For now, only software tools
# FullPcks <- rbind(Annotations,Experiments,Software)
FullPcks <- Software

# Add EDAM mappings
EDAM <- read.csv("EDAM Mappings - BioConductor Version 1.csv",skip=1,row.names=2)
map_terms <- function(tool) {
  views <- strsplit(tool["biocViews"],"\\|")
  tEDAM <- NULL
  for (i in views) {
    tEDAM <- rbind(tEDAM,EDAM[i,])
  }
  # tEDAM
  out <- apply(tEDAM,2,paste,collapse="|")
  out
}
length(map_terms(FullPcks[2,]))
ttt <- t(apply(FullPcks,1,map_terms))

FullPcks <- cbind(FullPcks,ttt)
write.csv(FullPcks,"FullBioconductor.csv")

tPcks <- cbind(FullPcks[,c("Name","Title","Description","biocViews")],paste(FullPcks[,"reposFullUrl"],"/html/",FullPcks[,"Name"],".html",sep=""),
               FullPcks[,c("Category","Term.1","URI","Term.2","URI.1")])
write.csv(tPcks,"FullBioconductorForCuration.csv",row.names=F)


## Writing xml-file
xml_out = newXMLNode("resources",attrs=list("xsi:schemaLocation"="http://biotoolsregistry.org ../biotools-1.1.xsd"))
for (i in 1:nrow(FullPcks)) {
  currTool <- FullPcks[i,]
  
  tnode <- newXMLNode("resource",parent=xml_out)
  newXMLNode("name",parent=tnode,text=currTool["Name"])
  newXMLNode("homepage",parent=tnode,text=paste(currTool["reposFullUrl"],"/html/",currTool["Name"],".html",sep=""))
  
  ## URL translates somehow into mirror. Issues are: a) no http://, b) newlines, c) multiple entries
  currTool["URL"] <- gsub("\n",",",currTool["URL"])
  currTool["URL"] <- gsub(" and",",",currTool["URL"])
  currTool["URL"] <- gsub(" ","",currTool["URL"])
  currTool["URL"] <- sub("<","",currTool["URL"])
  currTool["URL"] <- sub(">","",currTool["URL"])
  tools <- unlist(strsplit(currTool["URL"],","))
  for (tool in tools) {
    if (!is.na(tool) & tool != "") {
      if (length(grep("http",tool)) > 0) {
        newXMLNode("mirror",parent=tnode,text=tool)
      } else {
        newXMLNode("mirror",parent=tnode,text=paste("http://",tool,sep=""))
      }
    }
  }
  if (!is.na(currTool["Version"]) & currTool["Version"] != "") 
    newXMLNode("version",parent=tnode,text=currTool["Version"])
  newXMLNode("collection",parent=tnode,text="Bioconductor")
  newXMLNode("accessibility",parent=tnode,text="Public")
  for (dep in unlist(strsplit(currTool["Depends"],"|",fixed=T))) {
    tnode2 <- newXMLNode("uses",parent=tnode)
    newXMLNode("usesName",parent=tnode2,text=dep)
  }
  for (dep in unlist(strsplit(currTool["Imports"],"|",fixed=T))) {
    tnode2 <- newXMLNode("uses",parent=tnode)
    newXMLNode("usesName",parent=tnode2,text=dep)
  }
  if(length(grep("bioc",currTool["reposFullUrl"]))>0) {
    newXMLNode("resourceType",parent=tnode,text="Tool")
  }else{
    newXMLNode("resourceType",parent=tnode,text="Database")
  }
  
  tnode2 <- newXMLNode("interface",parent=tnode)
  newXMLNode("interfaceType",parent=tnode2,text="Command line")
  newXMLNode("interfaceDocs",parent=tnode2,text="http://www.bioconductor.org")
  
  # maximally 1000 characters: truncate if too many
  currTool["Description"] <- substr(currTool["Description"],1,1000)
  newXMLNode("description",parent=tnode,text=gsub('\n'," ",currTool["Description"]))

  ## todo: EDAM terms
  newXMLNode("topic",parent=tnode,text="Topic",attrs=list(uri="http://edamontology.org/topic_0003"))
  tnode2 <- newXMLNode("function",parent=tnode)
  newXMLNode("functionName",parent=tnode2,text="Operation",attrs=list(uri="http://edamontology.org/operation_0004"))
  tnode3 <- newXMLNode("input",parent=tnode2)
  newXMLNode("dataType",parent=tnode3,text="Data",attrs=list(uri="http://edamontology.org/data_0006"))
  newXMLNode("dataFormat",parent=tnode3,text="Format",attrs=list(uri="http://edamontology.org/format_1915"))
  tnode3 <- newXMLNode("output",parent=tnode2)
  newXMLNode("dataType",parent=tnode3,text="Data",attrs=list(uri="http://edamontology.org/data_0006"))
  newXMLNode("dataFormat",parent=tnode3,text="Format",attrs=list(uri="http://edamontology.org/format_1915"))
  
  currTool["Maintainer"] <- gsub("\n"," ",currTool["Maintainer"])
  currTool["Maintainer"] <- gsub(" and ",", ",currTool["Maintainer"])
  currTool["Maintainer"] <- gsub(";",", ",currTool["Maintainer"])
  creditsContr <- NULL
  maintainers <- strsplit(currTool["Maintainer"],",")
  for (m in unlist(maintainers)) {
    if (m != " " & m != "" & !is.na(m) & !is.na(m)) {
      maintainer <- unlist(maintainer <- strsplit(sub(">","",m),"<"))
      maintainer[2] <- gsub(" ","",maintainer[2])
      if(!is.na(maintainer[2])) {
        tnode2 <- newXMLNode("contact",parent=tnode)
        newXMLNode("contactEmail",parent=tnode2,text=maintainer[2])
        if (maintainer[1] !=" ")
          newXMLNode("contactName",parent=tnode2,text=maintainer[1])
      } else {
        creditsContr <- append(creditsContr,maintainer[1])
      }
    }
  }
  
  ## until getting changed in Registry, use General
  newXMLNode("contactRole",parent=tnode2,text="Maintainer")
  # newXMLNode("contactRole",parent=tnode2,text="General")
  newXMLNode("sourceRegistry",parent=tnode,text="http://bioconductor.org/")
  #   if (!is.na(currTool["SystemRequirements"]) & currTool["SystemRequirements"] != "") 
  #       newXMLNode("platform",parent=tnode,text=currTool["SystemRequirements"])
  
  #   ## Licenses are too many, substitute some of them:
  #   currTool["License"] <- sub("The Artistic License, Version 2.0","Artistic License 2.0",currTool["License"])
  #   currTool["License"] <- sub("Artistic-2.0","Artistic License 2.0",currTool["License"])
  #   currTool["License"] <- sub("LGPL-","GNU Lesser General Public License ",currTool["License"])
  #   currTool["License"] <- sub("LGPL","GNU Lesser General Public License v2.1",currTool["License"])
  #   newXMLNode("license",parent=tnode,text=currTool["License"])
  newXMLNode("cost",parent=tnode,text="Free")
  tnode2 <- newXMLNode("docs",parent=tnode)
  # newXMLNode("docsHome",parent=tnode2,text=paste(currTool["reposFullUrl"],currTool["source.ver"],sep="/"))
  newXMLNode("docsHome",parent=tnode2,text=paste(currTool["reposFullUrl"],"/html/",currTool["Name"],".html",sep=""))
#   if (!is.na(currTool["docsHome"]) & currTool["docsHome"] != "") {
#     tnode2 <- newXMLNode("docs",parent=tnode)
#     newXMLNode("docsHome",parent=tnode2,text=currTool["manuals"])
#   }
  tnode2 <- newXMLNode("publications",parent=tnode)
  newXMLNode("publicationsPrimaryID",parent=tnode2,text="None")
  tnode2 <- newXMLNode("credits",parent=tnode)
  
  currTool["Author"] <- gsub(" and ",", ",currTool["Author"])
  currTool["Author"] <- gsub("\n"," ",currTool["Author"])
  currTool["Author"] <- gsub(";",",",currTool["Author"])
  developers <- unlist(strsplit(currTool["Author"],","))
  for (dev in developers) 
if(!is.na(dev) & dev != "" & dev!= " ")
    newXMLNode("creditsDeveloper",parent=tnode2,text=dev)
  for (cr in creditsContr)
  if(!is.null(cr) & !is.na(cr) & cr!="" & cr!=" " )
    newXMLNode("creditsContributor",parent=tnode2,text=cr)
  
  ## missing:
  # Title, biocViews, sourceVer
}
saveXML(xml_out,"FullBioconductor.xml")


