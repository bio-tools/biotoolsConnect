########## Import of Bioconductor tools to bio.tools
## Issues:
## 1) biocViews are not being used or mapped to EDAM. Manual annotation so far
## 2) Authors do not have email adresses but "maintainers" do, therefore difficult to distinguish contacts from maintainers or contributors
## 3) Only one data per input/output allowed. Problem when multiple data and format terms -> all format terms for each data term
## 4) Short description sometimes too short -> added (R package) at the end
## 5) Terms which are not in EDAM, typos or in wrong category
## 6) * Duplicated terms: operation_3223;operation_3742 operation_3352;operation_3353: temporarily deleted
## 7) * wrong terms (e.g. operation instead of topic) -> manually corrected


library(biocViews)
library(graph)
library(XML)
# library(ontologyIndex)
library(stringr)


# Necessary functions as get_OWL was depreciated in new versions of ontologyIndex
str_ancs_from_pars <- function(id, pars, chld) {
  stopifnot(all(sapply(list(pars, chld), function(x) is.null(names(x)) | identical(names(x), id))))
  int.pars <- c(split(as.integer(factor(unlist(use.names=FALSE, pars), levels=id)), unlist(use.names=FALSE, mapply(SIMPLIFY=FALSE, FUN=rep, id, sapply(pars, length)))), setNames(nm=setdiff(id, unlist(use.names=FALSE, pars)), rep(list(integer(0)), length(setdiff(id, unlist(use.names=FALSE, pars))))))[id]
  int.chld <- c(split(as.integer(factor(unlist(use.names=FALSE, chld), levels=id)), unlist(use.names=FALSE, mapply(SIMPLIFY=FALSE, FUN=rep, id, sapply(chld, length)))), setNames(nm=setdiff(id, unlist(use.names=FALSE, chld)), rep(list(integer(0)), length(setdiff(id, unlist(use.names=FALSE, chld))))))[id]
  
  setNames(nm=id, lapply(ancs_from_pars(
    int.pars,
    int.chld
  ), function(x) id[x]))
}

ancs_from_pars <- function(pars, chld) {
  ancs <- as.list(seq(length(pars)))
  done <- sapply(pars, function(x) length(x) == 0)
  cands <- which(done)
  new.done <- 1:length(cands)
  while (!all(done)) {
    cands <- unique(unlist(use.names=FALSE, chld[cands[new.done]]))
    v <- sapply(pars[cands], function(x) all(done[x]))
    if (!is.logical(v)) {
      stop("Can't get ancestors for items ", paste0(collapse=", ", which(!done)))
    }
    new.done <- which(v)
    done[cands[new.done]] <- TRUE
    ancs[cands[new.done]] <- mapply(SIMPLIFY=FALSE, FUN=c, lapply(cands[new.done], function(x) unique(unlist(use.names=FALSE, ancs[pars[[x]]]))), cands[new.done])
  }
  ancs
}
ontology_index <- function(id, name, parents, remove_missing=FALSE, obsolete=setNames(nm=id, rep(FALSE, length(id))), version=NULL, ...) {
  if (!((is.null(names(parents)) & length(parents) == length(id)) | identical(names(parents), id))) {
    stop("`parents` argument must have names attribute identical to `id` argument or be the same length")
  }
  if (remove_missing) parents <- lapply(parents, intersect, id)
  children <- c(
    lapply(FUN=as.character, X=split(
      unlist(use.names=FALSE, rep(id, times=sapply(parents, length))),
      unlist(use.names=FALSE, parents)
    )),
    setNames(nm=setdiff(id, unlist(use.names=FALSE, parents)), rep(list(character(0)), length(setdiff(id, unlist(use.names=FALSE, parents)))))
  )[id]
  structure(lapply(FUN=setNames, nm=id, X=list(id=id, name=name, parents=parents, children=children, ancestors=str_ancs_from_pars(id, unname(parents), unname(children)), obsolete=obsolete, ...)), class="ontology_index", version=version)
}
OWL_list_attributes_per_node <- function(xpath, attribute) {
  force(xpath)
  force(attribute)
  function(nodes) {
    par_node <- xpath; par_count <- paste0("count(", par_node, ")"); split(xml2::xml_attr(x=xml2::xml_find_all(x=nodes, xpath=par_node), attr=attribute, ns=xml2::xml_ns(nodes)), factor(rep(seq_along(nodes), times=xml2::xml_find_num(x=nodes, xpath=par_count)), levels=seq_along(nodes)))
  }
}
OWL_is_a <- OWL_list_attributes_per_node(xpath="rdfs:subClassOf[@rdf:resource]", attribute="rdf:resource")
OWL_part_of <- OWL_list_attributes_per_node(xpath="rdfs:subClassOf/owl:Restriction/owl:onProperty[@rdf:resource='http://purl.obolibrary.org/obo/BFO_0000050']/../owl:someValuesFrom", attribute="rdf:resource")
OWL_is_a_and_part_of <- function(nodes) lapply(FUN=unique, mapply(SIMPLIFY=FALSE, FUN=c, OWL_is_a(nodes), OWL_part_of(nodes)))
OWL_strings_from_nodes <- function(xpath) {
  force(xpath)
  function(nodes) xml2::xml_find_chr(x=nodes, xpath=xpath)
}
OWL_IDs <- OWL_strings_from_nodes("string(@rdf:about)")
OWL_labels <- OWL_strings_from_nodes("string(rdfs:label)")
OWL_obsolete <- function(nodes) xml2::xml_find_chr(x=nodes, xpath="string(owl:deprecated)") == "true"

get_OWL <- function(
  file, 
  class_xpath="owl:Class[@rdf:about]", 
  id=OWL_IDs,
  name=OWL_labels,
  parents=OWL_is_a,
  obsolete=OWL_obsolete,
  version_xpath="owl:Ontology",
  remove_missing=FALSE,
  ...
) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop("Please install the 'xml2' package to use this function.",
         call. = FALSE)
  }
  funcs <- list(id=id, name=name, parents=parents, obsolete=obsolete, ...)
  doc <- xml2::read_xml(file)
  ns <- xml2::xml_ns(doc)
  classes <- xml2::xml_find_all(x=doc, ns=ns, xpath=class_xpath)
  properties <- lapply(funcs, function(f) unname(f(classes)))
  version_nodes <- xml2::xml_children(xml2::xml_find_first(x=doc, xpath="owl:Ontology", ns=ns))
  version_text <- xml2::xml_text(version_nodes)
  version <- paste0(xml2::xml_name(version_nodes),": ", version_text)[nchar(version_text) > 0]
  do.call(what=ontology_index, c(list(remove_missing=remove_missing, version=version), properties))
}



############### get recent EDAM ontology for mapping of terms
system("rm EDAM.owl")
system("wget http://edamontology.org/EDAM.owl")
EDAM <- get_OWL("EDAM.owl")

## Remove obsolete terms
EDAM$id <- EDAM$id[!EDAM$obsolete]
EDAM$name <- EDAM$name[!EDAM$obsolete]
EDAM$parents <- EDAM$parents[!EDAM$obsolete]
EDAM$children <- EDAM$children[!EDAM$obsolete]
EDAM$ancestors <- EDAM$ancestors[!EDAM$obsolete]
EDAM$obsolete <- EDAM$obsolete[!EDAM$obsolete]

########  TEMPORARILY DELETING DULICATED TERMS
EDAM$name[which(EDAM$id == "http://edamontology.org/operation_3742")] <- ""
EDAM$name[which(EDAM$id == "http://edamontology.org/operation_3353")] <- ""
#################################################

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

# Add EDAM mappings STILL NEEDED?
EDAMmaps <- read.csv("EDAM Mappings - BioConductor Version 1.csv",row.names=2)
map_terms <- function(tool) {
  views <- strsplit(tool["biocViews"],"\\|")
  tEDAM <- NULL
  for (i in views) {
    tEDAM <- rbind(tEDAM,EDAMmaps[i,])
  }
  # tEDAM
  out <- apply(tEDAM,2,paste,collapse="|")
  out
}
length(map_terms(FullPcks[2,]))
ttt <- t(apply(FullPcks,1,map_terms))

FullPcks <- cbind(FullPcks,ttt)

## add manual annotations
ManualAnnotations <- read.csv("BioconductorAnnotations.csv",skip=3,row.names=1)
colnames(ManualAnnotations) 

write.csv(FullPcks,"FullBioconductor.csv")

tPcks <- cbind(FullPcks[,c("Name","Title","Description","biocViews")],paste(FullPcks[,"reposFullUrl"],"/html/",FullPcks[,"Name"],".html",sep=""),
               FullPcks[,c("Category","Term.1","URI","Term.2","URI.1")])
write.csv(tPcks,"FullBioconductorForCuration.csv",row.names=F)

# convert licenses to SPDX License List
FullPcks <- data.frame(FullPcks,stringsAsFactors = F)
FullPcks$License <- gsub(" \\+ file LICENSE","",FullPcks$License)
FullPcks$License <- gsub(" \\+ file LICENCE","",FullPcks$License)
FullPcks$License <- gsub(" \\| file LICENSE","",FullPcks$License)
FullPcks$License <- gsub("file LICENSE","",FullPcks$License)
FullPcks$License <- gsub("Unlimited","",FullPcks$License)
FullPcks[grep("LGPL.*3.*",FullPcks$License),"License"] <- "LGPL-3.0"
FullPcks[grep("LGPL.*2\\.1.*",FullPcks$License),"License"] <- "LGPL-2.1"
FullPcks[grep("LGPL.*2.*",FullPcks$License),"License"] <- "LGPL-2.0"
FullPcks[grep("GPL.*3.*",FullPcks$License),"License"] <- "GPL-3.0"
FullPcks[grep("GPL.*2.*",FullPcks$License),"License"] <- "GPL-2.0"
FullPcks[grep("GPL.*gnu.*",FullPcks$License),"License"] <- "GPL-3.0"
FullPcks[grep("Artistic.*2.*",FullPcks$License),"License"] <- "Artistic-2.0"
FullPcks[grep("Apache.*2.*",FullPcks$License),"License"] <- "Apache-2.0"
FullPcks[grep("EPL",FullPcks$License),"License"] <- "EPL-1.0"
FullPcks[grep("CPL",FullPcks$License),"License"] <- "CPL-1.0"
FullPcks[grep("CeCILL",FullPcks$License),"License"] <- "CECILL-2.1"
FullPcks[grep("BSD",FullPcks$License),"License"] <- "BSD-4-Clause"
FullPcks[grep("BSD_2_clause",FullPcks$License),"License"] <- "BSD-2-Clause"
FullPcks[grep("BSD_3_clause",FullPcks$License),"License"] <- "BSD-3-Clause"
FullPcks[grep("CC BY-NC-SA 4.0",FullPcks$License),"License"] <- "CC-BY-NC-SA-4.0"
FullPcks[grep("CC BY-NC-ND 4.0",FullPcks$License),"License"] <- "CC-BY-NC-ND-4.0"
FullPcks[grep("CC BY-NC 4.0",FullPcks$License),"License"] <- "CC-BY-NC-4.0"
FullPcks[FullPcks$License == "GPL","License"] <- "GPL-3.0"
FullPcks[FullPcks$License == "LGPL","License"] <- "LGPL-3.0"
sort(names(table(FullPcks$License)))

EDAMTypos <- Citations <-  NULL

writeEDAMformat <- function (parentnode, terms){
  if (is.na(terms)) {
    tnode4 <- newXMLNode("format",parent=parentnode)
    alt_name <- "http://edamontology.org/format_1915"
    newXMLNode("uri",parent=tnode4, alt_name)
    newXMLNode("term",parent=tnode4, EDAM$name[alt_name])
  } else {
    edam_list <- strsplit(as.character(terms), "[;]")
    
    for (e in unlist(edam_list)) {
      e <- gsub("^\\s+|\\s+$", "", e)
      edam_name <- grep("format",names(which(e == EDAM$name )),value=T)
      if (length(edam_name)>0) {
        if (nchar(e) <= 1) {
          EDAMTypos <<- rbind(EDAMTypos, c(currTool$Name,e))
        } else {
          tnode4 <- newXMLNode("format",parent=parentnode)
          newXMLNode("uri",parent=tnode4,edam_name)
          newXMLNode("term",parent=tnode4,e)
        }
      }
    }
  }
}


## Writing xml-file
xml_out = newXMLNode(name="tools",namespace=list(xmlns="http://bio.tools"),
                     namespaceDefinitions = list("xsi"="http://www.w3.org/2001/XMLSchema-instance"),
                     attrs = list("xsi:schemaLocation"="http://bio.tools biotools-2.0.0.xsd"))
for (i in 1:nrow(FullPcks)) {
  currTool <- FullPcks[i,]
  
  tnode <- newXMLNode("tool",parent=xml_out)
  tnode2 <- newXMLNode("summary",parent=tnode)
  
  
  newXMLNode("name",parent=tnode2,text=sub("\\(.*","",currTool["Name"]))
  ###### tool id without special characters and spaces (_ instead), max. 12 characters
  toolID <- gsub("\\!","",currTool$Name)
  toolID <- gsub(" ","_",toolID)
  toolID <- gsub("\\+","Plus",toolID)
  toolID <- gsub("\\.","",toolID)
  toolID <- strtrim(toolID,12)
  newXMLNode("toolID",parent=tnode2,text=sub("\\(.*","",toolID))
  if (!is.na(currTool["Version"]) & currTool["Version"] != ""){
    newXMLNode("version",parent=tnode2,text=currTool$Version)
    newXMLNode("versionID",parent=tnode2,text=currTool$Version)
  }
  # minimum 10 characters, max 200 characters
  if (nchar(currTool$Title)<10) currTool$Title <- paste(currTool$Title,"(R package)")
  newXMLNode("shortDescription",parent=tnode2,text=substr(gsub('\n'," ",currTool["Title"]),1,200))
  # restrict to 1000 characters
  currTool$Description <- gsub("\n"," ",currTool$Description)
  currTool["Description"] <- substr(currTool["Description"],1,1000)
  newXMLNode("description",parent=tnode2,text=gsub('\n'," ",currTool["Description"]))
  newXMLNode("homepage",parent=tnode2,text=paste(as.character(currTool["reposFullUrl"]),"/html/",
                                                 currTool["Name"],".html",sep=""))
  
  ## EDAM terms, still not defined for Bioconductor as waiting for proposals
  # for now taken from msutils converter
  ## Probably need to adapt to allow multiple functions with different input/output in future
  tnode2 <- newXMLNode("function",parent=tnode)
  manEDAMs <- as.matrix(ManualAnnotations[currTool$Name,])
  manEDAMs[manEDAMs == ""] <- NA
  if (is.na(manEDAMs[2])) {
    tnode3 <- newXMLNode("operation",parent=tnode2)
    alt_name <- "http://edamontology.org/operation_0004"
    newXMLNode("uri",parent=tnode3,alt_name)
    newXMLNode("term",parent=tnode3,EDAM$name[alt_name])
  } else {
    edam_list <- strsplit((manEDAMs[2]), "[;]")
    for (e in unlist(edam_list)) {
      e <- gsub("^\\s+|\\s+$", "", e)
      edam_name <- grep("operation",names(which(e == EDAM$name )),value=T)
      if (length(edam_name)>0) {
        if (nchar(e) <= 1) {
          EDAMTypos <- rbind(EDAMTypos, c(currTool$Name,e))
        } else {
          tnode3 <- newXMLNode("operation",parent=tnode2)
          newXMLNode("uri",parent=tnode3,edam_name)
          newXMLNode("term",parent=tnode3,e)
        }
      }
    }
  }
  if (is.na(manEDAMs[3])) {
    tnode3 <- newXMLNode("input",parent=tnode2)
    tnode4 <- newXMLNode("data",parent=tnode3)
    alt_name <- "http://edamontology.org/data_0006"
    newXMLNode("uri",parent=tnode4, alt_name)
    newXMLNode("term",parent=tnode4, EDAM$name[alt_name])
    writeEDAMformat(tnode3, manEDAMs[4])
    
  } else {
    edam_list <- strsplit(as.character(manEDAMs[3]), "[;]")
    for (e in unlist(edam_list)) {
      e <- gsub("^\\s+|\\s+$", "", e)
      edam_name <- grep("data",names(which(e == EDAM$name )),value=T)
      if (length(edam_name)>0) {
        if (nchar(e) <= 1) {
          EDAMTypos <- rbind(EDAMTypos, c(currTool$Name,e))
        } else {
          tnode3 <- newXMLNode("input",parent=tnode2)
          tnode4 <- newXMLNode("data",parent=tnode3)
          newXMLNode("uri",parent=tnode4,edam_name)
          newXMLNode("term",parent=tnode4,e)
          writeEDAMformat(tnode3, manEDAMs[4])
        }
      }
    }
  }
  
  if (is.na(manEDAMs[5])) {
    tnode3 <- newXMLNode("output",parent=tnode2)
    tnode4 <- newXMLNode("data",parent=tnode3)
    alt_name <- "http://edamontology.org/data_0006"
    newXMLNode("uri",parent=tnode4, alt_name)
    newXMLNode("term",parent=tnode4, EDAM$name[alt_name])
    writeEDAMformat(tnode3, manEDAMs[6])
  } else {
    edam_list <- strsplit(as.character(manEDAMs[5]), "[;]")
    for (e in unlist(edam_list)) {
      e <- gsub("^\\s+|\\s+$", "", e)
      edam_name <- grep("data",names(which(e == EDAM$name )),value=T)
      if (length(edam_name)>0) {
        if (nchar(e) <= 1) {
          EDAMTypos <- rbind(EDAMTypos, c(currTool$Name,e))
        } else {
          tnode3 <- newXMLNode("output",parent=tnode2)
          tnode4 <- newXMLNode("data",parent=tnode3)
          newXMLNode("uri",parent=tnode4,edam_name)
          newXMLNode("term",parent=tnode4,e)
          writeEDAMformat(tnode3, manEDAMs[6])
          
        }
      }
    }
  }
  
  tnode2 <- newXMLNode("labels",parent=tnode)
  if(length(grep("bioc",currTool["reposFullUrl"]))>0) {
    newXMLNode("toolType",parent=tnode2,text = "Command-line tool")
    newXMLNode("toolType",parent=tnode2,text = "Library")
  }else{
    newXMLNode("toolType",parent=tnode2,text = "Database")
    newXMLNode("toolType",parent=tnode2,text = "Library")
  }
  
  ## write EDAM terms if available, else write most general one
  if (is.na(manEDAMs[7])) {
    tnode3 <- newXMLNode("topic",parent=tnode2)
    alt_name <- "http://edamontology.org/topic_0003"
    newXMLNode("uri",parent=tnode3, alt_name)
    newXMLNode("term",parent=tnode3, EDAM$name[alt_name])
  } else {
    edam_list <- strsplit(as.character(manEDAMs[7]), "[;]")
    for (e in unlist(edam_list)) {
      e <- gsub("^\\s+|\\s+$", "", e)
      edam_name <- grep("topic",names(which(e == EDAM$name )),value=T)
      if (nchar(e) <= 1) {
        EDAMTypos <- rbind(EDAMTypos, c(currTool$Name,e))
      } else {
        tnode3 <- newXMLNode("topic",parent=tnode2)
        newXMLNode("uri",parent=tnode3,edam_name)
        newXMLNode("term",parent=tnode3,e)
      }
    }
  }
  
  
  if (!is.na(currTool$License) & currTool$License != "") {
    newXMLNode("license",parent=tnode2,text=currTool$License)
  }
  newXMLNode("collectionID",parent=tnode2,text="Bioconductor")
  
  currTool["URL"] <- gsub("\n",",",currTool["URL"])
  currTool["URL"] <- gsub(" and",",",currTool["URL"])
  currTool["URL"] <- gsub(" ","",currTool["URL"])
  currTool["URL"] <- sub("<","",currTool["URL"])
  currTool["URL"] <- sub(">","",currTool["URL"])
  tools <- unlist(strsplit(as.character(currTool["URL"]),","))
  for (tool in tools) {
    if (!is.na(tool) & tool != "") {
      tnode2 <- newXMLNode("link",parent=tnode)
      if (length(grep("http",tool)) > 0) {
        newXMLNode("url",parent=tnode2,text=tool)
      } else {
        tool <- gsub(" ","",tool)
        newXMLNode("url",parent=tnode2,text=paste("http://",tool,sep=""))
      }
      newXMLNode("type",parent=tnode2,"Mirror")
    }
  }
  
  if (!is.na(currTool$source.ver) & currTool$source.ver != "") {
    tnode2 <- newXMLNode("download",parent=tnode)
    newXMLNode("url",parent=tnode2,paste("http://bioconductor/packages/release/bioc/",currTool$source.ver,sep=""))
    newXMLNode("type",parent=tnode2,"Source code")
  }
  
  tnode2 <- newXMLNode("documentation",parent=tnode)
  newXMLNode("url",parent=tnode2,text=paste(currTool["reposFullUrl"],"/html/",currTool["Name"],".html",sep=""))
  newXMLNode("type",parent=tnode2,"Manual")
  
  # retrieve citations from Bioconductor web site and then convert into Pubmed IDs
  citation <- NA
  try(citation <- htmlTreeParse(paste("http://bioconductor.org/packages/release/bioc/citations/",currTool["Name"],"/citation.html",sep=""))[[1]][[1]])
  print(paste("Num Papers",length(citation)))
  allout <- NULL
  if (!is.na(citation))  {
    for (j in 1:length(citation)) {
      ttt <- strsplit(toString(citation[[j]][1]$text),"\n")[[1]][2]
      ttt <- gsub("”","",ttt)
      ttt <- gsub("“","",ttt)
      ttt <- gsub("\\.","\\1",ttt)
      ttt <- gsub("\\:","%3A",ttt)
      ttt <- gsub("\\/","%2F",ttt)
      ttt <- gsub("\\*","",ttt)
      ttt <- gsub(" ","+",ttt)
      print(ttt)
      if (!is.na(ttt)) {
        out <- read.csv(paste("https://www.ncbi.nlm.nih.gov/pubmed/?term=",ttt,"[title]&report=uilist&format=text",sep=""))
        out <- gsub("<pre>","",out[[1]][2])
        if (!grepl("pre",out)) 
          allout <- c(allout,out)
        print(out)
        
      }
      
    }
    if(!is.null(allout)) {
      print(paste("allout",allout))
      for (j in 1:length(allout))
        tnode2 <- newXMLNode("publication",parent=tnode)
      newXMLNode("pmid",parent=tnode2,paste("PMID:",allout[j],sep=""))
      Citations <- rbind(Citations, c(currTool["Name"], allout[j]))
    }
  }
  
  
  currTool["Maintainer"] <- gsub("\n"," ",currTool["Maintainer"])
  currTool["Maintainer"] <- gsub(" and ",", ",currTool["Maintainer"])
  currTool["Maintainer"] <- gsub(";",", ",currTool["Maintainer"])
  ## merely to avoid one case of a ill-placed comma
  currTool["Maintainer"] <- gsub(", <"," <",currTool["Maintainer"])
  
  creditsContr <- NULL
  maintainers <- strsplit(as.character(currTool["Maintainer"]),",")
  for (m in unlist(maintainers)) {
    if (m != " " & m != "" & !is.na(m) & !is.na(m)) {
      maintainer <- unlist(strsplit(paste(sub(">","",m),collapse=""),"<"))
      maintainer[2] <- gsub(" ","",maintainer[2])
      if(!is.na(maintainer[2])) {
        tnode2 <- newXMLNode("contact",parent=tnode)
        if (maintainer[1] !=" ") {
          newXMLNode("email",parent=tnode2,text=maintainer[2])
          newXMLNode("name",parent=tnode2,text=maintainer[1])
        }
      } else {
        creditsContr <- append(creditsContr,maintainer[1])
      }
    }
  }
  
}

#   
# 
# currTool["Author"] <- gsub(" and ",", ",currTool["Author"])
# currTool["Author"] <- gsub("\n"," ",currTool["Author"])
# currTool["Author"] <- gsub(";",",",currTool["Author"])
# developers <- unlist(strsplit(currTool["Author"],","))
# for (dev in developers) 
#   if(!is.na(dev) & dev != "" & dev!= " ")
#     newXMLNode("creditsDeveloper",parent=tnode2,text=dev)
# for (cr in creditsContr)
#   if(!is.null(cr) & !is.na(cr) & cr!="" & cr!=" " )
#     newXMLNode("creditsContributor",parent=tnode2,text=cr)

saveXML(xml_out,"FullBioconductor.xml")
