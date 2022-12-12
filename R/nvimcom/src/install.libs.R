files <- Sys.glob(paste0("*", SHLIB_EXT))
dest <- file.path(R_PACKAGE_DIR, paste0('libs', R_ARCH))
dir.create(dest, recursive = TRUE, showWarnings = FALSE)
file.copy(files, dest, overwrite = TRUE)
if(file.exists("symbols.rds"))
    file.copy("symbols.rds", dest, overwrite = TRUE)

exec <- "apps/nclientserver"
if(WINDOWS)
    exec <- "apps/nclientserver.exe"
if(any(file.exists(exec))){
    dest <- file.path(R_PACKAGE_DIR,  paste0('bin', R_ARCH))
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    file.copy(exec, dest, overwrite = TRUE)
}

