# R may break strings while sending them even if they are short
out <- function(x) {
    # Nvim-R will wait for more input if the string doesn't end with "\002"
    y <- paste0(x, "\002\n")
    cat(y)
    flush(stdout())
}

# Set security variables
set.seed(unclass(Sys.time()))
nvimr_id <- as.character(round(runif(1, 1, 100000000)))
nvimr_secr <- as.character(round(runif(1, 1, 100000000)))
out(paste0("let $NVIMR_ID = '", nvimr_id, "' | let $NVIMR_SECRET = '", nvimr_secr, "'"))

setwd(Sys.getenv("NVIMR_TMPDIR"))

# Save libPaths for nclientserver
libp <- unique(c(unlist(strsplit(Sys.getenv("R_LIBS_USER"),
                                 .Platform$path.sep)), .libPaths()))
cat(libp, sep = "\n", colapse = "\n", file = "libPaths")

# Check R version
R_version <- paste0(version[c("major", "minor")], collapse = ".")

if (R_version < "4.0.0")
    out("RWarn: Nvim-R requires R >= 4.0.0")

need_new_nvimcom <- ""

# Check nvimcom version
nd <- readLines(paste0(nvim_r_home, "/R/nvimcom/DESCRIPTION"))
nd <- nd[grepl("Version:", nd)]
needed_nvc_version <- sub("Version: ", "", nd)

ip <- utils::installed.packages()
if (length(grep("^nvimcom$", rownames(ip))) == 1) {
    nvimcom_info <- ip["nvimcom", c("Version", "LibPath", "Built")]
    if (nvimcom_info["Built"] != R_version) {
        need_new_nvimcom <- "R version mismatch"
    } else {
        if (nvimcom_info["Version"] != needed_nvc_version)
            need_new_nvimcom <- "nvimcom version mismatch"
    }
} else {
    if (length(grep("^nvimcom$", rownames(ip))) > 1) {
        # FIXME: what version would be loaded?
        out(paste0("RWarn: nvimcom installed in more than one directory: ",
                   paste0(ip[grep("^nvimcom$", rownames(ip)), "LibPath"], collapse = ", ")))
    } else {
        if (length(grep("^nvimcom$", rownames(ip))) == 0)
            need_new_nvimcom <- "Nvimcom not installed"
    }
}

# Build and install nvimcom if necessary
if (need_new_nvimcom != "") {
    out(paste0("let g:rplugin.debug_info['Why build nvimcom'] = '", need_new_nvimcom, "'"))

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
        out("RWarn: No suitable directory found to install nvimcom")
        quit(save = "no")
    }

    out("echo \"Building nvimcom... \"")
    tools:::.build_packages(paste0(nvim_r_home, "/R/nvimcom"), no.q = TRUE)
    if (!file.exists(paste0("nvimcom_", needed_nvc_version, ".tar.gz"))) {
        out("RWarn: Failed to build nvimcom.")
        quit(save = "no")
    }

    out("echo \"Installing nvimcom... \"")
    tools:::.install_packages(paste0("nvimcom_", needed_nvc_version, ".tar.gz"), no.q = TRUE)
    unlink(paste0("nvimcom_", needed_nvc_version, ".tar.gz"))
    ip <- utils::installed.packages()
    if (length(grep("nvimcom", rownames(ip))) == 0) {
        if (dir.exists(paste0(libp[1], "/00LOCK-nvimcom")))
            out(paste0('RWarn: Failed to install nvimcom. Perhaps you should delete the directory "', libp[1], '/00LOCK-nvimcom"'))
        else
            out("RWarn: Failed to install nvimcom.")
        quit(save = "no")
    }
    if (length(grep("nvimcom", rownames(ip))) > 1) {
        out("RWarn: More than one nvimcom versions installed.")
        quit(save = "no")
    }
    nvimcom_version <- ip[grep("nvimcom", rownames(ip)), "Version"]
    if (nvimcom_version != needed_nvc_version) {
        out("RWarn: Failed to update nvimcom.")
        quit(save = "no")
    }
}

# Save ~/.cache/Nvim-R/nvimcom_info
nvimcom_info <- unname(utils::installed.packages()["nvimcom", c("Version", "LibPath", "Built")])
writeLines(nvimcom_info, paste0(Sys.getenv("NVIMR_COMPLDIR"), "/nvimcom_info"))

# Build omnils_, fun_ and args_ files, if necessary
library("nvimcom")
pkgs <- utils::installed.packages()
libs <- libs[libs %in% rownames(pkgs)]
cat(paste(libs, utils::installed.packages()[libs, 'Version'], collapse = '\n', sep = '_'),
    '\n', sep = '', file = paste0(Sys.getenv("NVIMR_TMPDIR"), "/libnames_", nvimr_id))

nvimcom:::nvim.buildomnils(libs)
out("echo ''")
