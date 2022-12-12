# Set security variables
set.seed(unclass(Sys.time()))
nvimr_id <- as.character(round(runif(1, 1, 100000000)))
nvimr_secr <- as.character(round(runif(1, 1, 100000000)))
cat("let $NVIMR_ID = '", nvimr_id, "' | let $NVIMR_SECRET = '", nvimr_secr, "'\n", sep = "")
flush(stdout())

setwd(Sys.getenv("NVIMR_TMPDIR"))

# Save libPaths for nclientserver
cat(unique(c(unlist(strsplit(Sys.getenv("R_LIBS_USER"),
                             .Platform$path.sep)), .libPaths())),
    sep = "\n", colapse = "\n", file = "libPaths")

# Check R version
R_version <- paste0(version[c("major", "minor")], collapse = ".")

if (R_version < "4.0.0") {
    cat("call RWarningMsg('Nvim-R requires R >= 4.0.0')\n")
    flush(stdout())
}

need_new_nvimcom <- ""

if (file.exists(paste0(Sys.getenv("NVIMR_COMPLDIR"), "/nvimcom_info"))) {
    nvimcom_info <- readLines(paste0(Sys.getenv("NVIMR_COMPLDIR"), "/nvimcom_info"))
    if (nvimcom_info[3] != R_version)
        need_new_nvimcom = "R version mismatch"
} else {
    need_new_nvimcom <- "nvimcom_info not found"
}

# Check nvimcom version
nd <- readLines(paste0(nvim_r_home, "/R/nvimcom/DESCRIPTION"))
nd <- nd[grepl("Version:", nd)]
needed_nvc_version <- sub("Version: ", "", nd)

ip <- utils::installed.packages()
if (length(grep("nvimcom", rownames(ip))) == 1) {
    nvimcom_version <- ip[grep("nvimcom", rownames(ip)), "Version"]
    if (nvimcom_version != needed_nvc_version)
        need_new_nvimcom <- "nvimcom version mismatch"
} else {
    need_new_nvimcom <- "Nvimcom not installed"
}

# Build and install nvimcom if necessary
if (need_new_nvimcom != "") {
    cat("let g:rplugin.debug_info['Why build nvimcom'] = '",
        need_new_nvimcom, "'\n", sep = "")
    flush(stdout())

    # Check if any directory in libPaths is writable
    ok <- FALSE
    for (p in .libPaths())
        if (dir.exists(p) && file.access(p, mode = 2) == 0)
            ok <- TRUE
    if (!ok) {
        for (p in .libPaths()) {
            if (dir.create(p)) {
                ok <- TRUE
                cat("call RWarningMsg('The directory \"", p,
                    "\" was created to install nvimcom.')\n", sep = "")
                flush(stdout())
                break
            }
        }
    }

    if (!ok) {
        cat("call RWarningMsg('No suitable directory found to install nvimcom')\n")
        flush(stdout())
        quit(save = "no")
    }

    cat("echo \"Building nvimcom... \"\n")
    flush(stdout())
    tools:::.build_packages(paste0(nvim_r_home, "/R/nvimcom"), no.q = TRUE)
    if (!file.exists(paste0("nvimcom_", needed_nvc_version, ".tar.gz"))) {
        cat("call RWarningMsg('Failed to build nvimcom.')\n")
        flush(stdout())
        quit(save = "no")
    }

    cat("echo \"Installing nvimcom... \"\n")
    flush(stdout())
    tools:::.install_packages(paste0("nvimcom_", needed_nvc_version, ".tar.gz"), no.q = TRUE)
    unlink(paste0("nvimcom_", needed_nvc_version, ".tar.gz"))
    ip <- utils::installed.packages()
    if (length(grep("nvimcom", rownames(ip))) == 0) {
        cat("call RWarningMsg('Failed to install nvimcom.')\n")
        flush(stdout())
        quit(save = "no")
    }
    if (length(grep("nvimcom", rownames(ip))) > 1) {
        cat("call RWarningMsg('More than one nvimcom versions installed.')\n")
        flush(stdout())
        quit(save = "no")
    }
    nvimcom_version <- ip[grep("nvimcom", rownames(ip)), "Version"]
    if (nvimcom_version != needed_nvc_version) {
        cat("call RWarningMsg('Failed to update nvimcom.')\n")
        flush(stdout())
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
cat("echo ''\n")
flush(stdout())
