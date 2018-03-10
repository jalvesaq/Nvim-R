
nvim.print <- function(object, firstobj)
{
    if(!exists(object))
        stop("object '", object, "' not found")
    if(!missing(firstobj)){
        objclass <- nvim.getclass(firstobj)
        if(objclass[1] != "#E#" && objclass[1] != ""){
            mlen <- try(length(methods(object)), silent = TRUE)
            if(class(mlen) == "integer" && mlen > 0){
                for(cls in objclass){
                    if(exists(paste(object, ".", objclass, sep = ""))){
                        .newobj <- get(paste(object, ".", objclass, sep = ""))
                        message(paste0("Note: Printing ", object, ".", objclass))
                        break
                    }
                }
            }
        }
    }
    if(!exists(".newobj"))
        .newobj <- get(object)
    print(.newobj)
}

