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


