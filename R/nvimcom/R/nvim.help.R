
nvim.hmsg <- function(files, header, title, delete.file)
{
    if(Sys.getenv("NVIMR_TMPDIR") == "")
        stop("NVIMR_TMPDIR not set.")
    dest <- paste0(Sys.getenv("NVIMR_TMPDIR"), "/Rdoc")
    file.copy(files[1], dest, overwrite = TRUE)
    keyword <- sub(".* '", "", title)
    keyword <- sub(".* \u2018", "", keyword)
    keyword <- sub("'", "", keyword)
    keyword <- sub("\u2019", "", keyword)
    .C("nvimcom_msg_to_nvim", paste0("ShowRDoc('", keyword, "')"), PACKAGE="nvimcom")
    return(invisible(NULL))
}

nvim.help <- function(topic, w, objclass, package)
{
    if(!missing(objclass) && objclass != ""){
        mlen <- try(length(methods(topic)), silent = TRUE)
        if(class(mlen) == "integer" && mlen > 0){
            for(i in 1:length(objclass)){
                newtopic <- paste(topic, ".", objclass[i], sep = "")
                if(length(utils::help(newtopic))){
                    topic <- newtopic
                    break
                }
            }
        }
    }

    oldRdOp <- tools::Rd2txt_options()
    on.exit(tools::Rd2txt_options(oldRdOp))
    tools::Rd2txt_options(width = w)

    oldpager <- getOption("pager")
    on.exit(options(pager = oldpager), add = TRUE)
    options(pager = nvim.hmsg)

    # try devtools first (if loaded)
    if ("devtools" %in% loadedNamespaces()) {
        if (missing(package)) {
            if (!is.null(devtools:::find_topic(topic))) {
                devtools::dev_help(topic)
                return(invisible(NULL))
            }
        } else {
            if (package %in% devtools::dev_packages()) {
                ret = try(devtools::dev_help(topic), silent = TRUE)
                if (inherits(ret, "try-error"))
                    .C("nvimcom_msg_to_nvim", paste0("RWarningMsg('", as.character(ret), "')"), PACKAGE="nvimcom")
                return(invisible(NULL))
            }
        }
    }

    if(missing(package))
        h <- utils::help(topic, help_type = "text")
    else
        h <- utils::help(topic, package = as.character(package), help_type = "text")

    if(length(h) == 0){
        msg <- paste('No documentation for "', topic, '" in loaded packages and libraries.', sep = "")
        .C("nvimcom_msg_to_nvim", paste0("RWarningMsg('", msg, "')"), PACKAGE="nvimcom")
        return(invisible(NULL))
    }
    if(length(h) > 1){
        if(missing(package)){
            h <- sub("/help/.*", "", h)
            h <- sub(".*/", "", h)
            msg <- paste("MULTILIB", paste(h, collapse = " "), topic)
            .C("nvimcom_msg_to_nvim", paste0("ShowRDoc('", msg, "')"), PACKAGE="nvimcom")
            return(invisible(NULL))
        } else {
            h <- h[grep(paste("/", package, "/", sep = ""), h)]
            if(length(h) == 0){
                msg <- paste("Package '", package, "' has no documentation for '", topic, "'", sep = "")
                .C("nvimcom_msg_to_nvim", paste0("RWarningMsg('", msg, "')"), PACKAGE="nvimcom")
                return(invisible(NULL))
            }
        }
    }
    print(h)

    return(invisible(NULL))
}

nvim.example <- function(topic)
{
    saved.warn <- getOption("warn")
    options(warn = -1)
    on.exit(options(warn = saved.warn))
    ret <- try(example(topic, give.lines = TRUE, character.only = TRUE,
                       package = NULL), silent = TRUE)
    if (inherits(ret, "try-error")){
        .C("nvimcom_msg_to_nvim",
           paste0("RWarningMsg('", as.character(ret), "')"), PACKAGE="nvimcom")
    } else {
        if(is.character(ret)){
            if(length(ret) > 0){
                writeLines(ret, paste0(Sys.getenv("NVIMR_TMPDIR"), "/example.R"))
                .C("nvimcom_msg_to_nvim", "OpenRExample()", PACKAGE="nvimcom")
            } else {
                .C("nvimcom_msg_to_nvim",
                   paste0("RWarningMsg('There is no example for \"", topic, "\"')"),
                   PACKAGE="nvimcom")
            }
        } else {
            .C("nvimcom_msg_to_nvim",
               paste0("RWarningMsg('There is no help for \"", topic, "\".')"),
               PACKAGE="nvimcom")
        }
    }
    return(invisible(NULL))
}
