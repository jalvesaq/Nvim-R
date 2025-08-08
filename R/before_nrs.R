# R may break strings while sending them even if they are short
out <- function(x) {
    # Vim-R will wait for more input if the string doesn't end with "\x14"
    y <- paste0(x, "\x14\n")
    cat(y)
    flush(stdout())
}

isdir <- file.info(Sys.getenv("VIMR_TMPDIR"))[["isdir"]]
if (is.na(isdir)) {
    out(paste0("RWarn: R: VIMR_TMPDIR (`", Sys.getenv("VIMR_TMPDIR"), "`) not found."))
} else {
    if (!isdir)
        out(paste0("RWarn: R: VIMR_TMPDIR (`", Sys.getenv("VIMR_TMPDIR"), "`) is not a directory."))
}

isdir <- file.info(Sys.getenv("VIMR_COMPLDIR"))[["isdir"]]
if (is.na(isdir)) {
    out(paste0("RWarn: R: VIMR_COMPLDIR (`", Sys.getenv("VIMR_COMPLDIR"), "`) not found."))
} else {
    if (!isdir)
        out(paste0("RWarn: R: VIMR_COMPLDIR (`", Sys.getenv("VIMR_COMPLDIR"), "`) is not a directory."))
}

setwd(Sys.getenv("VIMR_TMPDIR"))

# Save libPaths for vimrserver
libp <- unique(c(unlist(strsplit(Sys.getenv("R_LIBS_USER"),
                                 .Platform$path.sep)), .libPaths()))
cat(libp, sep = "\n", colapse = "\n", file = "libPaths")

# Check R version
R_version <- paste0(version[c("major", "minor")], collapse = ".")

if (R_version < "4.0.0")
    out("RWarn: Vim-R requires R >= 4.0.0")

R_version <- sub("[0-9]$", "", R_version)

need_new_vimcom <- ""

check_vimcom_installation <- function() {
    np <- find.package("vimcom", quiet = TRUE, verbose = FALSE)
    if (length(np) == 1) {
        nd <- utils::packageDescription("vimcom")
        if (nd$Version != needed_nvc_version) {
            out("RWarn: Failed to update vimcom.")
            quit(save = "no", status = 63)
        }
    } else {
        if (length(np) == 0) {
            if (dir.exists(paste0(libp[1], "/00LOCK-vimcom"))) {
                out(paste0('RWarn: Failed to install vimcom. Perhaps you should delete the directory "', libp[1], '/00LOCK-vimcom"'))
            } else {
                out("RWarn: Failed to install vimcom.")
            }
            quit(save = "no", status = 61)
        } else {
            out("RWarn: More than one vimcom versions installed.")
            quit(save = "no", status = 62)
        }
    }
}

# The vimcom directory will not exist if vimcom was packaged separately from
# the rest of Vim-R. I will also not be found if running Vim in MSYS2 and R
# on Windows because the directory names change between the two systems.
if (!is.null(needed_nvc_version)) {
    np <- find.package("vimcom", quiet = TRUE, verbose = FALSE)
    if (length(np) == 1) {
        nd <- utils::packageDescription("vimcom")
        if (!grepl(paste0('^R ', R_version), nd$Built)) {
            need_new_vimcom <- paste0("R version mismatch: '", R_version, "' vs '", nd$Built, "'")
        } else {
            if (nd$Version != needed_nvc_version) {
                need_new_vimcom <- "vimcom version mismatch"
                fi <- file.info(paste0(np, "/DESCRIPTION"))
                if (sum(grepl("uname", names(fi))) == 1 &&
                    Sys.getenv("USER") != "" &&
                    Sys.getenv("USER") != fi[["uname"]]) {
                    need_new_vimcom <-
                        paste0(need_new_vimcom, " (vimcom ", nd$Version,
                               " was installed in `", np, "` by \"", fi[["uname"]], "\")")
                }
            }
        }
    } else {
        if (length(np) == 0)
            need_new_vimcom <- "Vimcom not installed"
    }

    # Build and install vimcom if necessary
    if (need_new_vimcom != "") {
        out(paste0("let g:rplugin.debug_info['Why build vimcom'] = '", need_new_vimcom, "'"))

        # Check if any directory in libPaths is writable
        ok <- FALSE
        for (p in libp)
            if (dir.exists(p) && file.access(p, mode = 2) == 0)
                ok <- TRUE
        if (!ok) {
            out(paste0("let s:libd = '", libp[1], "'"))
            quit(save = "no", status = 71)
        }

        if (!ok) {
            out("RWarn: No suitable directory found to install vimcom")
            quit(save = "no", status = 65)
        }

        if (!file.exists(paste0(vim_r_home, "/R/vimcom"))) {
            if (file.exists(paste0(Sys.getenv("VIMR_TMPDIR"), "/", "vimcom_", needed_nvc_version, ".tar.gz"))) {
                out("echo \"Installing vimcom... \"")
                tools:::.install_packages(paste0(Sys.getenv("VIMR_TMPDIR"), "/", "vimcom_", needed_nvc_version, ".tar.gz"), no.q = TRUE)
                unlink(paste0(Sys.getenv("VIMR_TMPDIR"), "/", "vimcom_", needed_nvc_version, ".tar.gz"))
                check_vimcom_installation()
            } else {
                out(paste0("RWarn: Cannot build vimcom: directory '", vim_r_home, "/R/vimcom", "' not found"))
                quit(save = "no", status = 72)
            }
        } else {

            out("echo \"Building vimcom... \"")
            tools:::.build_packages(paste0(vim_r_home, "/R/vimcom"), no.q = TRUE)
            if (!file.exists(paste0("vimcom_", needed_nvc_version, ".tar.gz"))) {
                out("RWarn: Failed to build vimcom.")
                quit(save = "no", status = 66)
            }

            out("echo \"Installing vimcom... \"")
            tools:::.install_packages(paste0("vimcom_", needed_nvc_version, ".tar.gz"), no.q = TRUE)
            unlink(paste0("vimcom_", needed_nvc_version, ".tar.gz"))
            check_vimcom_installation()
        }
    }
}


# Save ~/.cache/Vim-R/vimcom_info
np <- find.package("vimcom", quiet = TRUE, verbose = FALSE)
if (length(np) == 1) {
    nd <- utils::packageDescription("vimcom")
    vimcom_info <- c(nd$Version, np, sub("R ([^;]*).*", "\\1", nd$Built))
    writeLines(vimcom_info, paste0(Sys.getenv("VIMR_COMPLDIR"), "/vimcom_info"))

    # Build omnils_, fun_ and args_ files, if necessary
    library("vimcom", warn.conflicts = FALSE)
    hasl <- rep(FALSE, length(libs))
    lver <- rep("", length(libs))
    for (i in 1:length(libs))
        if (length(find.package(libs[i], quiet = TRUE, verbose = FALSE)) > 0) {
            hasl[i] <- TRUE
            lver[i] <- packageDescription(libs[i])$Version
        }
    libs <- libs[hasl]
    lver <- lver[hasl]
    cat(paste(libs, lver, collapse = '\n', sep = '_'),
        '\n', sep = '', file = paste0(Sys.getenv("VIMR_TMPDIR"), "/libnames_", Sys.getenv("VIMR_ID")))
    vimcom:::vim.buildomnils(libs)
    out("echo ''")
    quit(save = "no")
}

if (length(np) == 0) {
    out("RWarn: vimcom is not installed.")
    for (p in libp)
        if (dir.exists(paste0(p, "/00LOCK-vimcom")))
            out(paste0('RWarn: vimcom is not installed. Perhaps you should delete the directory "', p, '/00LOCK-vimcom"'))
    quit(save = "no", status = 67)
}

if (length(np) > 1) {
    out(paste0("RWarn: vimcom is installed in more than one directory: ",
               paste0(ip[grep("^vimcom$", rownames(ip)), "LibPath"], collapse = ", ")))
    quit(save = "no", status = 68)
}
