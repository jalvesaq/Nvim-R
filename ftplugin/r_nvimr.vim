
if exists("g:disable_r_ftplugin")
    finish
endif

" Source scripts common to R, Rnoweb, Rhelp, Rmd, Rrst and rdoc files:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"
if exists("g:rplugin.failed")
    finish
endif

" Some buffer variables common to R, Rnoweb, Rhelp, Rmd, Rrst and rdoc files
" need be defined after the global ones:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_buffer.vim"

function! GetRCmdBatchOutput(...)
    if filereadable(s:routfile)
        let curpos = getpos(".")
        if g:R_routnotab == 1
            exe "split " . s:routfile
            set filetype=rout
            exe "normal! \<c-w>\<c-p>"
        else
            exe "tabnew " . s:routfile
            set filetype=rout
            normal! gT
        endif
    else
        call RWarningMsg("The file '" . s:routfile . "' either does not exist or not readable.")
    endif
endfunction

" Run R CMD BATCH on current file and load the resulting .Rout in a split
" window
function! ShowRout()
    let s:routfile = expand("%:r") . ".Rout"
    if bufloaded(s:routfile)
        exe "bunload " . s:routfile
        call delete(s:routfile)
    endif

    " if not silent, the user will have to type <Enter>
    silent update

    if has("win32")
        let rcmd = g:rplugin.Rcmd . ' CMD BATCH --no-restore --no-save "' . expand("%") . '" "' . s:routfile . '"'
    else
        let rcmd = [g:rplugin.Rcmd, "CMD", "BATCH", "--no-restore", "--no-save", expand("%"),  s:routfile]
    endif
    if has("nvim")
        let g:rplugin.jobs["R_CMD"] = jobstart(rcmd, {'on_exit': function('GetRCmdBatchOutput')})
    else
        let rjob = job_start(rcmd, {'close_cb': function('GetRCmdBatchOutput')})
        let g:rplugin.jobs["R_CMD"] = job_getchannel(rjob)
    endif
endfunction

" Convert R script into Rmd, md and, then, html -- using knitr::spin()
function! RSpin()
    update
    call g:SendCmdToR('require(knitr); .vim_oldwd <- getwd(); setwd("' . expand("%:p:h") . '"); spin("' . expand("%:t") . '"); setwd(.vim_oldwd); rm(.vim_oldwd)')
endfunction

" Default IsInRCode function when the plugin is used as a global plugin
function! DefaultIsInRCode(vrb)
    return 1
endfunction

let b:IsInRCode = function("DefaultIsInRCode")

"==========================================================================
" Key bindings and menu items

call RCreateStartMaps()
call RCreateEditMaps()

" Only .R files are sent to R
call RCreateMaps('ni', 'RSendFile',  'aa', ':call SendFileToR("silent")')
call RCreateMaps('ni', 'RESendFile', 'ae', ':call SendFileToR("echo")')
call RCreateMaps('ni', 'RShowRout',  'ao', ':call ShowRout()')

" Knitr::spin
" -------------------------------------
call RCreateMaps('ni', 'RSpinFile',  'ks', ':call RSpin()')

call RCreateSendMaps()
call RControlMaps()
call RCreateMaps('nvi', 'RSetwd',    'rd', ':call RSetWD()')


" Menu R
if has("gui_running")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/gui_running.vim"
    call MakeRMenu()
endif

call RSourceOtherScripts()

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode"
endif
