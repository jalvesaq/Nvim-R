
nvim.hmsg <- function(files, header, title, delete.file)
{
    if(Sys.getenv("NVIMR_TMPDIR") == "")
        stop("NVIMR_TMPDIR not set.")
    dest <- paste0(Sys.getenv("NVIMR_TMPDIR"), "/Rdoc")
    file.copy(files[1], dest, overwrite = TRUE)
    ttl <- sub("R Help on '(.*)'", "\\1 (help)", title)
    ttl <- sub("R Help on \u2018(.*)\u2019", "\\1 (help)", ttl)
    .C("nvimcom_msg_to_nvim", paste0("ShowRDoc('", ttl, "')"), PACKAGE="nvimcom")
    return(invisible(NULL))
}

nvim.help <- function(topic, w, firstobj, package)
{
    if(!missing(firstobj) && firstobj != ""){
        objclass <- nvim.getclass(firstobj)
        if(objclass != "#E#" && objclass != ""){
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
    }

    oldRdOp <- tools::Rd2txt_options()
    on.exit(tools::Rd2txt_options(oldRdOp))
    tools::Rd2txt_options(width = w)

    oldpager <- getOption("pager")
    on.exit(options(pager = oldpager), add = TRUE)
    options(pager = nvim.hmsg)

    warn <- function(msg)
    {
        .C("nvimcom_msg_to_nvim",
           paste0("RWarningMsg('", as.character(msg), "')"),
           PACKAGE = "nvimcom")
    }

    if("pkgload" %in% loadedNamespaces()) {
        ret <- try(pkgload::dev_help(topic), silent = TRUE)

        if(!inherits(ret, "try-error")) {
            suppressMessages(print(ret))
            return(invisible(NULL))
        } else if(!missing(package) && pkgload::is_dev_package(package)) {
            warn(ret)
            return(invisible(NULL))
        }
    }

    if("devtools" %in% loadedNamespaces()) {
        ret <- suppressMessages(try(devtools::dev_help(topic), silent = TRUE))

        if (!inherits(ret, "try-error")) {
            return(invisible(NULL))
        } else if(!missing(package) && package %in% devtools::dev_packages()) {
            warn(ret)
            return(invisible(NULL))
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
