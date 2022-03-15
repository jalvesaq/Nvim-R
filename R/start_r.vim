"==============================================================================
" Function to start R and functions that are called only after R is started.
"==============================================================================

" Delete provisory links
unlet g:RAction
unlet g:RBrOpenCloseLs
unlet g:RClearAll
unlet g:RClearConsole
unlet g:RMakeRmd
unlet g:RObjBrowser
unlet g:RQuit
unlet g:RSendPartOfLine
unlet g:SendFunctionToR
unlet g:SendLineToR
unlet g:SendLineToRAndInsertOutput
unlet g:SendMBlockToR
unlet g:SendParagraphToR
unlet g:SendSelectionToR

"==============================================================================
" Functions to start and close R
"==============================================================================

" Start R
function StartR(whatr)
    let s:wait_nvimcom = 1

    if g:rplugin.starting_ncs == 1
        " The user called StartR too quickly
        echon "Waiting nclientserver..."
        let ii = 0
        while g:rplugin.starting_ncs == 1
            sleep 100m
            let ii += 1
            if ii == 30
                break
            endif
        endwhile
        let g:rplugin.starting_ncs = 0
    endif

    if (type(g:R_external_term) == v:t_number && g:R_external_term == 1) || type(g:R_external_term) == v:t_string
        let g:R_objbr_place = substitute(g:R_objbr_place, 'console', 'script', '')
    endif

    if !isdirectory(g:rplugin.tmpdir)
        call mkdir(g:rplugin.tmpdir, "p", 0700)
    endif

    " https://github.com/jalvesaq/Nvim-R/issues/157
    if !exists("*FunHiOtherBf")
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/functions.vim"
    endif

    if a:whatr =~ "custom"
        call inputsave()
        let r_args = input('Enter parameters for R: ')
        call inputrestore()
        let g:rplugin.r_args = split(r_args)
    else
        if exists("g:R_args")
            let g:rplugin.r_args = g:R_args
        else
            let g:rplugin.r_args = []
        endif
    endif

    call writefile([], g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call writefile([], g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call writefile([], g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)

    call AddForDeletion(g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/nvimbol_finished")
    call AddForDeletion(g:rplugin.tmpdir . "/start_options.R")
    call AddForDeletion(g:rplugin.tmpdir . "/args_for_completion")

    " Reset R_DEFAULT_PACKAGES to its original value (see https://github.com/jalvesaq/Nvim-R/issues/554):
    let start_options = ['Sys.setenv("R_DEFAULT_PACKAGES" = "' . s:r_default_pkgs . '")']

    if g:R_objbr_allnames
        let start_options += ['options(nvimcom.allnames = TRUE)']
    else
        let start_options += ['options(nvimcom.allnames = FALSE)']
    endif
    if g:R_texerr
        let start_options += ['options(nvimcom.texerrs = TRUE)']
    else
        let start_options += ['options(nvimcom.texerrs = FALSE)']
    endif
    if g:R_hi_fun_globenv == 2
        let start_options += ['options(nvimcom.autoglbenv = TRUE)']
    else
        let start_options += ['options(nvimcom.autoglbenv = FALSE)']
    endif
    if g:R_debug
        let start_options += ['options(nvimcom.debug_r = TRUE)']
    else
        let start_options += ['options(nvimcom.debug_r = FALSE)']
    endif
    if exists('g:R_setwidth') && g:R_setwidth == 2
        let start_options += ['options(nvimcom.setwidth = TRUE)']
    else
        let start_options += ['options(nvimcom.setwidth = FALSE)']
    endif
    if g:R_nvimpager == "no"
        let start_options += ['options(nvimcom.nvimpager = FALSE)']
    else
        let start_options += ['options(nvimcom.nvimpager = TRUE)']
    endif
    if type(g:R_external_term) == v:t_number && g:R_external_term == 0 && g:R_esc_term
        let start_options += ['options(editor = nvimcom:::nvim.edit)']
    endif
    if exists("g:R_csv_delim") && (g:R_csv_delim == "," || g:R_csv_delim == ";")
        let start_options += ['options(nvimcom.delim = "' . g:R_csv_delim. '")']
    else
        let start_options += ['options(nvimcom.delim = "\t")']
    endif
    let start_options += ['options(nvimcom.source.path = "' . s:Rsource_read . '")']

    let rwd = ""
    if g:R_nvim_wd == 0
        let rwd = expand("%:p:h")
    elseif g:R_nvim_wd == 1
        let rwd = getcwd()
    endif
    if rwd != ""
        if has("win32")
            let rwd = substitute(rwd, '\\', '/', 'g')
        endif

        " `rwd` will not be a real directory if editing a file on the internet
        " with netrw plugin
        if isdirectory(rwd)
            if has("win32") && &encoding == "utf-8"
                let start_options += ['.nvim.rwd <- "' . rwd . '"']
                let start_options += ['Encoding(.nvim.rwd) <- "UTF-8"']
                let start_options += ['setwd(.nvim.rwd)']
                let start_options += ['rm(.nvim.rwd)']
            else
                let start_options += ['setwd("' . rwd . '")']
            endif
        endif
    endif

    call writefile(start_options, g:rplugin.tmpdir . "/start_options.R")

    " Required to make R load nvimcom without the need of the user including
    " library(nvimcom) in his or her ~/.Rprofile.
    if $R_DEFAULT_PACKAGES == ""
        let $R_DEFAULT_PACKAGES = "datasets,utils,grDevices,graphics,stats,methods,nvimcom"
    elseif $R_DEFAULT_PACKAGES !~ "nvimcom"
        let $R_DEFAULT_PACKAGES .= ",nvimcom"
    endif

    if exists("g:RStudio_cmd")
        let $R_DEFAULT_PACKAGES .= ",rstudioapi"
        call StartRStudio()
        return
    endif

    if type(g:R_external_term) == v:t_number && g:R_external_term == 0
        call StartR_InBuffer()
        return
    endif

    if g:R_applescript
        call StartR_OSX()
        return
    endif

    if has("win32")
        call StartR_Windows()
        return
    endif

    if IsSendCmdToRFake()
        return
    endif

    let args_str = join(g:rplugin.r_args)
    if args_str == ""
        let rcmd = g:rplugin.R
    else
        let rcmd = g:rplugin.R . " " . args_str
    endif

    call StartR_ExternalTerm(rcmd)
endfunction

" Send SIGINT to R
function SignalToR(signal)
    if s:R_pid
        call system('kill -s ' . a:signal . ' ' . s:R_pid)
    endif
endfunction


function CheckIfNvimcomIsRunning(...)
    let s:nseconds = s:nseconds - 1
    if g:rplugin.nvimcom_port == 0
        if s:nseconds > 0
            call timer_start(1000, "CheckIfNvimcomIsRunning")
        else
            let msg = "The package nvimcom wasn't loaded yet. Please, quit R and try again."
            call RWarningMsg(msg)
            sleep 500m
        endif
    endif
endfunction

function WaitNvimcomStart()
    let args_str = join(g:rplugin.r_args)
    if args_str =~ "vanilla"
        return 0
    endif
    if g:R_wait < 2
        g:R_wait = 2
    endif

    let s:nseconds = g:R_wait
    call timer_start(1000, "CheckIfNvimcomIsRunning")
endfunction

function SetNvimcomInfo(nvimcomversion, nvimcomhome, bindportn, rpid, wid, r_info)
    if !exists("g:R_nvimcom_home") && a:nvimcomhome != g:rplugin.nvimcom_info['home']
        call RWarningMsg('Mismatch in directory names: "' . g:rplugin.nvimcom_info['home'] . '" and "' . a:nvimcomhome . '"')
        sleep 1
    endif

    if g:rplugin.nvimcom_info['version'] != a:nvimcomversion
        call RWarningMsg('Mismatch in nvimcom versions: "' . g:rplugin.nvimcom_info['version'] . '" and "' . a:nvimcomversion . '"')
        sleep 1
    endif

    let $R_DEFAULT_PACKAGES = s:r_default_pkgs

    let g:rplugin.nvimcom_port = a:bindportn
    let s:R_pid = a:rpid
    let $RCONSOLE = a:wid

    let Rinfo = split(a:r_info, "\x02")
    let s:R_version = Rinfo[0]
    if !exists("g:R_OutDec")
        let g:R_OutDec = Rinfo[1]
    endif
    let g:Rout_prompt_str = substitute(Rinfo[2], ' $', '', '')
    let g:Rout_continue_str = substitute(Rinfo[3], ' $', '', '')
    let g:Rout_prompt_str = substitute(g:Rout_prompt_str, '.*#N#', '', '')
    let g:Rout_continue_str = substitute(g:Rout_continue_str, '.*#N#', '', '')

    if has('nvim') && has_key(g:rplugin, "R_bufname")
        " Put the cursor and the end of the buffer to ensure automatic scrolling
        " See: https://github.com/neovim/neovim/issues/2636
        let isnormal = mode() ==# 'n'
        let curwin = winnr()
        exe 'sb ' . g:rplugin.R_bufname
        if !exists('g:R_hl_term')
            if Rinfo[4] =~# 'colorout'
                let g:R_hl_term = 0
            else
                let g:R_hl_term = 1
                set syntax=rout
            endif
        endif
        call cursor('$', 1)
        exe curwin . 'wincmd w'
        if isnormal
            stopinsert
        endif
    endif

    if IsJobRunning("ClientServer")
        " Set RConsole window ID in nclientserver to ArrangeWindows()
        if has("win32")
            if $RCONSOLE == "0"
                call RWarningMsg("nvimcom did not save R window ID")
            endif
        endif
        " Set nvimcom port in nvimclient
        if has("win32")
            call JobStdin(g:rplugin.jobs["ClientServer"], "1" . g:rplugin.nvimcom_port . " " . $RCONSOLE . "\n")
        else
            call JobStdin(g:rplugin.jobs["ClientServer"], "1" . g:rplugin.nvimcom_port . "\n")
        endif
    else
        call RWarningMsg("nvimcom is not running")
    endif

    if exists("g:RStudio_cmd")
        if has("win32") && g:R_arrange_windows && filereadable(g:rplugin.compldir . "/win_pos")
            " ArrangeWindows
            call JobStdin(g:rplugin.jobs["ClientServer"], "75" . g:rplugin.compldir . "\n")
        endif
    elseif has("win32")
        if g:R_arrange_windows && filereadable(g:rplugin.compldir . "/win_pos")
            " ArrangeWindows
            call JobStdin(g:rplugin.jobs["ClientServer"], "75" . g:rplugin.compldir . "\n")
        endif
    elseif g:R_applescript
        call foreground()
        sleep 200m
    else
        call delete(g:rplugin.tmpdir . "/initterm_" . $NVIMR_ID . ".sh")
        call delete(g:rplugin.tmpdir . "/openR")
    endif

    if type(g:R_after_start) == 1
        " Backward compatibility: R_after_start was a string until November, 2019.
        if g:R_after_start != ''
            call system(g:R_after_start)
        endif
    elseif type(g:R_after_start) == 3
        for cmd in g:R_after_start
            if cmd =~ '^!'
                call system(substitute(cmd, '^!', '', ''))
            elseif cmd =~ '^:'
                exe substitute(cmd, '^:', '', '')
            else
                call RWarningMsg("R_after_start must be a list of strings starting with either '!' or ':'")
            endif
        endfor
    endif
    call timer_start(1000, "SetSendCmdToR")
    if g:R_objbr_auto_start
        let s:autosttobjbr = 1
        call timer_start(1010, "RObjBrowser")
    endif
endfunction

function SetSendCmdToR(...)
    if exists("g:RStudio_cmd")
        let g:SendCmdToR = function('SendCmdToRStudio')
    elseif type(g:R_external_term) == v:t_number && g:R_external_term == 0
        let g:SendCmdToR = function('SendCmdToR_Buffer')
    elseif has("win32")
        let g:SendCmdToR = function('SendCmdToR_Windows')
    endif
    let s:wait_nvimcom = 0
endfunction

" Quit R
function RQuit(how)
    if exists("b:quit_command")
        let qcmd = b:quit_command
    else
        if a:how == "save"
            let qcmd = 'quit(save = "yes")'
        else
            let qcmd = 'quit(save = "no")'
        endif
    endif

    if has("win32") && type(g:R_external_term) == v:t_number && g:R_external_term == 1
        " SaveWinPos
        call JobStdin(g:rplugin.jobs["ClientServer"], "74" . $NVIMR_COMPLDIR . "\n")
    endif

    if bufloaded('Object_Browser')
        exe 'bunload! Object_Browser'
        sleep 30m
    endif

    call g:SendCmdToR(qcmd)

    if has_key(g:rplugin, "tmux_split") || a:how == 'save'
        sleep 200m
    endif

    sleep 50m
    call ClearRInfo()
endfunction

function ClearRInfo()
    call delete(g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call delete(g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)
    call delete(g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    for fn in g:rplugin.del_list
        call delete(fn)
    endfor
    let g:SendCmdToR = function('SendCmdToR_fake')
    let s:R_pid = 0
    let g:rplugin.nvimcom_port = 0

    " Legacy support for running R in a Tmux split pane
    if has_key(g:rplugin, "tmux_split") && exists('g:R_tmux_title') && g:rplugin.tmux_split
                \ && g:R_tmux_title != 'automatic' && g:R_tmux_title != ''
        call system("tmux set automatic-rename on")
    endif

    if type(g:R_external_term) == v:t_number && g:R_external_term == 0 && has("nvim")
        call CloseRTerm()
    endif

endfunction

let s:wait_nvimcom = 0


"==============================================================================
" Internal communication with R
"==============================================================================

" Send a message to nclientserver job which will send the message to nvimcom
" through a TCP connection.
function SendToNvimcom(code, attch)
    if s:wait_nvimcom
        if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
            call RWarningMsg("R is not running")
        elseif string(g:SendCmdToR) == "function('SendCmdToR_NotYet')"
            call RWarningMsg("R is not ready yet")
        endif
        return
    endif

    if !IsJobRunning("ClientServer")
        call RWarningMsg("ClientServer not running.")
        return
    endif
    call JobStdin(g:rplugin.jobs["ClientServer"], "2" . a:code . $NVIMR_ID . a:attch . "\n")
endfunction

" This function is called by nvimcom only if the message is longer than 980
" characters. Then, it saves the message in a file and sends to Nvim-R only
" this command to read the message from the file. Shorter messages are
" received from the nclientserver stdout (see nvimrcom.vim and vimrcom.vim).
function ReadRMsg()
    let msg = readfile($NVIMR_TMPDIR . "/nvimcom_msg")
    exe "call " . msg[0]
    call delete($NVIMR_TMPDIR . "/nvimcom_msg")
endfunction


"==============================================================================
" Keep syntax highlighting, data for omni completion and object browser up to
" date
"==============================================================================

" Did R successfully finished evaluating a command?
" There is no need of waiting for the completion of the .GlobalEnv list of
" objects to start omni completion if no command was run afer the list was
" bilt for the last time.
let s:R_task_completed = 0

" Function called by nvimcom
function RTaskCompleted()
    let s:R_task_completed = 1
    if g:R_hi_fun_globenv == 2
        call SendToNvimcom("A", "TaskCompleted hi_fun_globenv = 2")
        call RealUpdateRGlbEnv(0)
    endif
endfunction

let s:updating_globalenvlist = 0
let s:waiting_glblnv_list = 0

" Function called by nvimcom
function GlblEnvUpdated(changed)
    let s:updating_globalenvlist = 0
    if s:waiting_glblnv_list
        if a:changed == 0
            " Nothing to update
            let s:waiting_glblnv_list = 0
        endif
    endif
endfunction

let s:nglobfun = 0
function RealUpdateRGlbEnv(block)
    if ! s:R_task_completed
        return
    endif
    let s:R_task_completed = 0

    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        return
    endif

    let s:updating_globalenvlist = 1
    call SendToNvimcom("G", "UpdateRGlbEnv updating_globalenvlist")

    if g:rplugin.nvimcom_port == 0
        sleep 500m
        return
    endif

    if a:block
        " We can't return from this function and wait for a message from
        " nvimcom because both omni completion and the Object Browser require
        " the list of completions immediately.
        sleep 10m
        let ii = 0
        let max_ii = 100 * g:R_wait_reply
        while s:updating_globalenvlist && ii < max_ii
            let ii += 1
            sleep 10m
        endwhile
        if ii == max_ii
            call RWarningMsg("No longer waiting...")
            return
        endif
    else
        let s:waiting_glblnv_list = 1
    endif
endfunction

" Called by nclientserver. When g:rplugin has the key 'localfun', the function
" is also called by SourceRFunList() (R/functions.vim)
function UpdateLocalFunctions(funnames)
    let g:rplugin.localfun = a:funnames
    syntax clear rGlobEnvFun
    let flist = split(a:funnames, " ")
    for fnm in flist
        if fnm =~ '[\\\[\$@-]'
            continue
        endif
        if !exists('g:R_hi_fun_paren') || g:R_hi_fun_paren == 0
            exe 'syntax keyword rGlobEnvFun ' . fnm
        else
            exe 'syntax match rGlobEnvFun /\<' . fnm . '\s*\ze(/'
        endif
    endfor
endfunction



"==============================================================================
"  Functions triggered by nvimcom after user action on R Console
"==============================================================================

function ShowRObj(howto, bname, ftype)
    let bfnm = substitute(a:bname, '[ [:punct:]]', '_', 'g')
    call AddForDeletion(g:rplugin.tmpdir . "/" . bfnm)
    silent exe a:howto . ' ' . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . '/' . bfnm
    silent exe 'set ft=' . a:ftype
    let objf = readfile(g:rplugin.tmpdir . "/Rinsert")
    call setline(1, objf)
    set nomodified
endfunction

" This function is called by nvimcom
function EditRObject(fname)
    let fcont = readfile(a:fname)
    exe "tabnew " . substitute($NVIMR_TMPDIR . "/edit_" . $NVIMR_ID, ' ', '\\ ', 'g')
    call setline(".", fcont)
    set filetype=r
    stopinsert
    autocmd BufUnload <buffer> call delete($NVIMR_TMPDIR . "/edit_" . $NVIMR_ID . "_wait") | startinsert
endfunction


"==============================================================================
"  Object Browser (see also ../ftplugin/rbrowser.vim)
"==============================================================================

function StartObjBrowser()
    " Either open or close the Object Browser
    let savesb = &switchbuf
    set switchbuf=useopen,usetab
    if bufloaded('Object_Browser')
        let curwin = win_getid()
        let curtab = tabpagenr()
        exe 'sb Object_Browser'
        let objbrtab = tabpagenr()
        quit
        call win_gotoid(curwin)
        if curtab != objbrtab
            call StartObjBrowser()
        endif
    else
        let edbuf = bufnr()

        if g:R_objbr_place =~# 'RIGHT'
            sil exe 'botright vsplit Object_Browser'
        elseif g:R_objbr_place =~# 'LEFT'
            sil exe 'topleft vsplit Object_Browser'
        elseif g:R_objbr_place =~# 'TOP'
            sil exe 'topleft split Object_Browser'
        elseif g:R_objbr_place =~# 'BOTTOM'
            sil exe 'botright split Object_Browser'
        else
            if g:R_objbr_place =~? 'console'
                sil exe 'sb ' . g:rplugin.R_bufname
            else
                sil exe 'sb ' . g:rplugin.rscript_name
            endif
            if g:R_objbr_place =~# 'right'
                sil exe 'rightbelow vsplit Object_Browser'
            elseif g:R_objbr_place =~# 'left'
                sil exe 'leftabove vsplit Object_Browser'
            elseif g:R_objbr_place =~# 'above'
                sil exe 'aboveleft split Object_Browser'
            elseif g:R_objbr_place =~# 'below'
                sil exe 'belowright split Object_Browser'
            else
                call RWarningMsg('Invalid value for R_objbr_place: "' . R_objbr_place . '"')
                exe "set switchbuf=" . savesb
                return
            endif
        endif
        if g:R_objbr_place =~? 'left' || g:R_objbr_place =~? 'right'
            sil exe 'vertical resize ' . g:R_objbr_w
        else
            sil exe 'resize ' . g:R_objbr_h
        endif
        sil set filetype=rbrowser
        let g:rplugin.curview = "GlobalEnv"
        let g:rplugin.ob_winnr = win_getid()
        if has("nvim")
            let g:rplugin.ob_buf = nvim_win_get_buf(g:rplugin.ob_winnr)
        endif

        if exists('s:autosttobjbr') && s:autosttobjbr == 1
            let s:autosttobjbr = 0
            exe edbuf . 'sb'
        endif
    endif
    exe "set switchbuf=" . savesb
endfunction

" Open an Object Browser window
function RObjBrowser(...)
    " Only opens the Object Browser if R is running
    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        call RWarningMsg("The Object Browser can be opened only if R is running.")
        return
    endif

    if s:running_objbr == 1
        " Called twice due to BufEnter event
        return
    endif

    let s:running_objbr = 1

    call RealUpdateRGlbEnv(1)
    call JobStdin(g:rplugin.jobs["ClientServer"], "31\n")
    call SendToNvimcom("A", "RObjBrowser")

    call StartObjBrowser()
    let s:running_objbr = 0

    if len(g:R_after_ob_open) > 0
        redraw
        for cmd in g:R_after_ob_open
            exe substitute(cmd, '^:', '', '')
        endfor
    endif

    return
endfunction

function RBrOpenCloseLs(stt)
    call JobStdin(g:rplugin.jobs["ClientServer"], "34" . a:stt . g:rplugin.curview . "\n")
endfunction


"==============================================================================
" Support for debugging R code
"==============================================================================

" No support for break points
"if synIDattr(synIDtrans(hlID("SignColumn")), "bg") =~ '^#'
"    exe 'hi def StopSign guifg=red guibg=' . synIDattr(synIDtrans(hlID("SignColumn")), "bg")
"else
"    exe 'hi def StopSign ctermfg=red ctermbg=' . synIDattr(synIDtrans(hlID("SignColumn")), "bg")
"endif
"call sign_define('stpline', {'text': '●', 'texthl': 'StopSign', 'linehl': 'None', 'numhl': 'None'})

" Functions sign_define(), sign_place() and sign_unplace() require Neovim >= 0.4.3
"call sign_define('dbgline', {'text': '▬▶', 'texthl': 'SignColumn', 'linehl': 'QuickFixLine', 'numhl': 'Normal'})

if &ambiwidth == "double" || (has("win32") && !has("nvim"))
    sign define dbgline text==> texthl=SignColumn linehl=QuickFixLine
else
    sign define dbgline text=▬▶ texthl=SignColumn linehl=QuickFixLine
endif

let s:func_offset = -2
let s:rdebugging = 0
function StopRDebugging()
    "call sign_unplace('rdebugcurline')
    "sign unplace rdebugcurline
    sign unplace 1
    let s:func_offset = -2 " Did not seek yet
    let s:rdebugging = 0
endfunction

function FindDebugFunc(srcref)
    if type(g:R_external_term) == v:t_number && g:R_external_term == 0
        let s:func_offset = -1 " Not found
        let sbopt = &switchbuf
        set switchbuf=useopen,usetab
        let curtab = tabpagenr()
        let isnormal = mode() ==# 'n'
        let curwin = winnr()
        exe 'sb ' . g:rplugin.R_bufname
        sleep 30m " Time to fill the buffer lines
        let rlines = getline(1, "$")
        exe 'sb ' . g:rplugin.rscript_name
    elseif string(g:SendCmdToR) == "function('SendCmdToR_Term')"
        let tout = system('tmux -L NvimR capture-pane -p -t ' . g:rplugin.tmuxsname)
        let rlines = split(tout, "\n")
    elseif string(g:SendCmdToR) == "function('SendCmdToR_TmuxSplit')"
        let tout = system('tmux capture-pane -p -t ' . g:rplugin.rconsole_pane)
        let rlines = split(tout, "\n")
    else
        let rlines = []
    endif

    let idx = len(rlines) - 1
    while idx > 0
        if rlines[idx] =~# '^debugging in: '
            let funcnm = substitute(rlines[idx], '^debugging in: \(.\{-}\)(.*', '\1', '')
            let s:func_offset = search('.*\<' . funcnm . '\s*<-\s*function\s*(', 'b')
            if s:func_offset < 1
                let s:func_offset = search('.*\<' . funcnm . '\s*=\s*function\s*(', 'b')
            endif
            if s:func_offset < 1
                let s:func_offset = search('.*\<' . funcnm . '\s*<<-\s*function\s*(', 'b')
            endif
            if s:func_offset > 0
                let s:func_offset -= 1
            endif
            if a:srcref == '<text>'
                if &filetype == 'rmd'
                    let s:func_offset = search('^\s*```\s*{\s*r', 'nb')
                elseif &filetype == 'rnoweb'
                    let s:func_offset = search('^<<', 'nb')
                endif
            endif
            break
        endif
        let idx -= 1
    endwhile

    if type(g:R_external_term) == v:t_number && g:R_external_term == 0
        if tabpagenr() != curtab
            exe 'normal! ' . curtab . 'gt'
        endif
        exe curwin . 'wincmd w'
        if isnormal
            stopinsert
        endif
        exe 'set switchbuf=' . sbopt
    endif
endfunction

function RDebugJump(fnm, lnum)
    if a:fnm == '' || a:fnm == '<text>'
        " Functions sent directly to R Console have no associated source file
        " and functions sourced by knitr have '<text>' as source reference.
        if s:func_offset == -2
            call FindDebugFunc(a:fnm)
        endif
        if s:func_offset < 0
            return
        endif
    endif

    if s:func_offset >= 0
        let flnum = a:lnum + s:func_offset
        let fname = g:rplugin.rscript_name
    else
        let flnum = a:lnum
        let fname = expand(a:fnm)
    endif

    let bname = bufname("%")

    if !bufloaded(fname) && fname != g:rplugin.rscript_name && fname != expand("%") && fname != expand("%:p")
        if filereadable(fname)
            exe 'sb ' . g:rplugin.rscript_name
            if &modified
                split
            endif
            exe 'edit ' . fname
        elseif glob("*") =~ fname
            exe 'sb ' . g:rplugin.rscript_name
            if &modified
                split
            endif
            exe 'edit ' . fname
        else
            return
        endif
    endif

    if bufloaded(fname)
        if fname != expand("%")
            exe 'sb ' . fname
        endif
        exe ':' . flnum
    endif

    " Call sign_place() and sign_unplace() when requiring Vim 8.2 and Neovim 0.5
    "call sign_unplace('rdebugcurline')
    "call sign_place(1, 'rdebugcurline', 'dbgline', fname, {'lnum': flnum})
    sign unplace 1
    exe 'sign place 1 line=' . flnum . ' name=dbgline file=' . fname
    if g:R_dbg_jump && !s:rdebugging && type(g:R_external_term) == v:t_number && g:R_external_term == 0
        exe 'sb ' . g:rplugin.R_bufname
        startinsert
    elseif bname != expand("%")
        exe 'sb ' . bname
    endif
    let s:rdebugging = 1
endfunction


"==============================================================================
" Functions that ask R to help editing the code
"==============================================================================

function RFormatCode() range
    if g:rplugin.nvimcom_port == 0
        return
    endif

    let lns = getline(a:firstline, a:lastline)
    call writefile(lns, g:rplugin.tmpdir . "/unformatted_code")
    call AddForDeletion(g:rplugin.tmpdir . "/unformatted_code")
    call AddForDeletion(g:rplugin.tmpdir . "/formatted_code")

    let wco = &textwidth
    if wco == 0
        let wco = 78
    elseif wco < 20
        let wco = 20
    elseif wco > 180
        let wco = 180
    endif

    call SendToNvimcom("E", 'nvimcom:::nvim_format(' . a:firstline . ', ' . a:lastline . ', ' . wco . ', ' . &shiftwidth. ')')
endfunction

function FinishRFormatCode(lnum1, lnum2)
    let lns = readfile(g:rplugin.tmpdir . "/formatted_code")
    silent exe a:lnum1 . "," . a:lnum2 . "delete"
    call append(a:lnum1 - 1, lns)
    call delete(g:rplugin.tmpdir . "/formatted_code")
    call delete(g:rplugin.tmpdir . "/unformatted_code")
    echo (a:lnum2 - a:lnum1 + 1) . " lines formatted."
endfunction

function RInsert(cmd, type)
    if g:rplugin.nvimcom_port == 0
        return
    endif

    call delete(g:rplugin.tmpdir . "/Rinsert")
    call AddForDeletion(g:rplugin.tmpdir . "/Rinsert")

    call SendToNvimcom("E", 'nvimcom:::nvim_insert(' . a:cmd . ', "' . a:type . '")')
endfunction

function SendLineToRAndInsertOutput()
    let lin = getline(".")
    let cleanl = substitute(lin, '".\{-}"', '', 'g')
    if cleanl =~ ';'
        call RWarningMsg('`print(line)` works only if `line` is a single command')
    endif
    let cleanl = substitute(lin, '\s*#.*', "", "")
    call RInsert("print(" . cleanl . ")", "comment")
endfunction

function FinishRInsert(type)
    silent exe "read " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/Rinsert"

    if a:type == "comment"
        let curpos = getpos(".")
        " comment the output
        let ilines = readfile(g:rplugin.tmpdir . "/Rinsert")
        for iln in ilines
            call RSimpleCommentLine("normal", "c")
            normal! j
        endfor
        call setpos(".", curpos)
    endif
endfunction

function GetROutput(outf)
    if a:outf =~ g:rplugin.tmpdir
        let tnum = 1
        while bufexists("so" . tnum)
            let tnum += 1
        endwhile
        exe 'tabnew so' . tnum
        exe 'read ' . substitute(a:outf, " ", '\\ ', 'g')
        set filetype=rout
        setlocal buftype=nofile
        setlocal noswapfile
    else
        exe 'tabnew ' . substitute(a:outf, " ", '\\ ', 'g')
    endif
    normal! gT
    redraw
endfunction


function RViewDF(oname, ...)
    if exists('g:R_csv_app')
        let tsvnm = g:rplugin.tmpdir . '/' . a:oname . '.tsv'
        call system('cp "' . g:rplugin.tmpdir . '/Rinsert" "' . tsvnm . '"')
        call AddForDeletion(tsvnm)

        if g:R_csv_app =~# '^terminal:'
            let csv_app = split(g:R_csv_app, ':')[1]
            if executable(csv_app)
                tabnew
                exe 'terminal ' . csv_app . ' ' . substitute(tsvnm, ' ', '\\ ', 'g')
                startinsert
            else
                call RWarningMsg('R_csv_app ("' . csv_app . '") is not executable')
            endif
            return
        elseif g:R_csv_app =~# '^tmux new-window '
            let csv_app = substitute(g:R_csv_app, '^tmux new-window *', '', '')
            if !executable(csv_app)
                call RWarningMsg('R_csv_app ("' . csv_app . '") is not executable')
                return
            endif
        elseif !executable(g:R_csv_app) && !executable(split(g:R_csv_app)[0])
            call RWarningMsg('R_csv_app ("' . g:R_csv_app . '") is not executable')
            return
        endif

        normal! :<Esc>
        if has("nvim")
            let appcmd = split(g:R_csv_app) + [tsvnm]
            call jobstart(appcmd, {'detach': v:true})
        elseif has("win32")
            silent exe '!start "' . g:R_csv_app . '" "' . tsvnm . '"'
        else
            call system(g:R_csv_app . ' "' . tsvnm . '" >' . s:null . ' 2>' . s:null . ' &')
        endif
        return
    endif

    let location = get(a:, 1, "tabnew")
    silent exe location . ' ' . a:oname
    silent 1,$d
    silent exe 'read ' . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . '/Rinsert'
    silent 1d
    setlocal filetype=csv
    setlocal nomodified
    setlocal bufhidden=wipe
    setlocal noswapfile
    set buftype=nofile
    redraw
endfunction


"==============================================================================
" Show R documentation
"==============================================================================

function SetRTextWidth(rkeyword)
    if g:R_nvimpager == "tabnew"
        let s:rdoctitle = a:rkeyword
    else
        let s:tnr = tabpagenr()
        if g:R_nvimpager != "tab" && s:tnr > 1
            let s:rdoctitle = "R_doc" . s:tnr
        else
            let s:rdoctitle = "R_doc"
        endif
        unlet s:tnr
    endif
    if !bufloaded(s:rdoctitle) || g:R_newsize == 1
        let g:R_newsize = 0

        " s:vimpager is used to calculate the width of the R help documentation
        " and to decide whether to obey R_nvimpager = 'vertical'
        let s:vimpager = g:R_nvimpager

        let wwidth = winwidth(0)

        " Not enough room to split vertically
        if g:R_nvimpager == "vertical" && wwidth <= (g:R_help_w + g:R_editor_w)
            let s:vimpager = "horizontal"
        endif

        if s:vimpager == "horizontal"
            " Use the window width (at most 80 columns)
            let htwf = (wwidth > 80) ? 88.1 : ((wwidth - 1) / 0.9)
        elseif g:R_nvimpager == "tab" || g:R_nvimpager == "tabnew"
            let wwidth = &columns
            let htwf = (wwidth > 80) ? 88.1 : ((wwidth - 1) / 0.9)
        else
            let min_e = (g:R_editor_w > 80) ? g:R_editor_w : 80
            let min_h = (g:R_help_w > 73) ? g:R_help_w : 73

            if wwidth > (min_e + min_h)
                " The editor window is large enough to be split
                let s:hwidth = min_h
            elseif wwidth > (min_e + g:R_help_w)
                " The help window must have less than min_h columns
                let s:hwidth = wwidth - min_e
            else
                " The help window must have the minimum value
                let s:hwidth = g:R_help_w
            endif
            let htwf = (s:hwidth - 1) / 0.9
        endif
        let htw = printf("%f", htwf)
        let s:htw = substitute(htw, "\\..*", "", "")
        let s:htw = s:htw - (&number || &relativenumber) * &numberwidth
    endif
endfunction

function RAskHelp(...)
    if a:1 == ""
        call g:SendCmdToR("help.start()")
        return
    endif
    if g:R_nvimpager == "no"
        call g:SendCmdToR("help(" . a:1. ")")
    else
        call AskRDoc(a:1, "", 0)
    endif
endfunction

" Show R's help doc in Nvim's buffer
" (based  on pydoc plugin)
function AskRDoc(rkeyword, package, getclass)
    if filewritable(s:docfile)
        call delete(s:docfile)
    endif
    call AddForDeletion(s:docfile)

    let firstobj = ""
    if bufname("%") =~ "Object_Browser" || (has_key(g:rplugin, "R_bufname") && bufname("%") == g:rplugin.R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . g:rplugin.rscript_name
        exe "set switchbuf=" . savesb
    else
        if a:getclass
            let firstobj = RGetFirstObj(a:rkeyword)
        endif
    endif

    call SetRTextWidth(a:rkeyword)

    if firstobj == "" && a:package == ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L)'
    elseif a:package != ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L, package="' . a:package  . '")'
    else
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L, "' . firstobj . '")'
    endif

    call SendToNvimcom("E", rcmd)
endfunction

" Function called by nvimcom
function ShowRDoc(rkeyword)
    call AddForDeletion(s:docfile)

    let rkeyw = a:rkeyword
    if a:rkeyword =~ "^MULTILIB"
        let msgs = split(a:rkeyword)
        let msg = "The topic '" . msgs[-1] . "' was found in more than one library:\n"
        for idx in range(1, len(msgs) - 2)
            let msg .= idx . " : " . msgs[idx] . "\n"
        endfor
        redraw
        let chn = input(msg . "Please, select one of them: ")
        if chn > 0 && chn < (len(msgs) - 1)
            call SendToNvimcom("E", 'nvimcom:::nvim.help("' . msgs[-1] . '", ' . s:htw . 'L, package="' . msgs[chn] . '")')
        endif
        return
    endif

    if has_key(g:rplugin, "R_bufname") && bufname("%") == g:rplugin.R_bufname
        " Exit Terminal mode and go to Normal mode
        stopinsert
    endif

    " Legacy support for running R in a Tmux split pane.
    " If the help command was triggered in the R Console, jump to Vim pane:
    if has_key(g:rplugin, "tmux_split") && g:rplugin.tmux_split && !s:running_rhelp
        let slog = system("tmux select-pane -t " . g:rplugin.editor_pane)
        if v:shell_error
            call RWarningMsg(slog)
        endif
    endif
    let s:running_rhelp = 0

    if bufname("%") =~ "Object_Browser" || (has_key(g:rplugin, "R_bufname") && bufname("%") == g:rplugin.R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . g:rplugin.rscript_name
        exe "set switchbuf=" . savesb
    endif
    call SetRTextWidth(rkeyw)

    let rdoccaption = substitute(s:rdoctitle, '\', '', "g")
    if a:rkeyword =~ "R History"
        let rdoccaption = "R_History"
        let s:rdoctitle = "R_History"
    endif
    if bufloaded(rdoccaption)
        let curtabnr = tabpagenr()
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb ". s:rdoctitle
        exe "set switchbuf=" . savesb
        if g:R_nvimpager == "tabnew"
            exe "tabmove " . curtabnr
        endif
    else
        if g:R_nvimpager == "tab" || g:R_nvimpager == "tabnew"
            exe 'tabnew ' . s:rdoctitle
        elseif s:vimpager == "vertical"
            let splr = &splitright
            set splitright
            exe s:hwidth . 'vsplit ' . s:rdoctitle
            let &splitright = splr
        elseif s:vimpager == "horizontal"
            exe 'split ' . s:rdoctitle
            if winheight(0) < 20
                resize 20
            endif
        elseif s:vimpager == "no"
            " The only way of ShowRDoc() being called when R_nvimpager=="no"
            " is the user setting the value of R_nvimpager to 'no' after
            " Neovim startup. It should be set in the vimrc.
            if type(g:R_external_term) == v:t_number && g:R_external_term == 0
                let g:R_nvimpager = "vertical"
            else
                let g:R_nvimpager = "tab"
            endif
            call ShowRDoc(a:rkeyword)
            return
        else
            echohl WarningMsg
            echomsg 'Invalid R_nvimpager value: "' . g:R_nvimpager . '". Valid values are: "tab", "vertical", "horizontal", "tabnew" and "no".'
            echohl None
            return
        endif
    endif

    setlocal modifiable
    let g:rplugin.curbuf = bufname("%")

    let save_unnamed_reg = @@
    set modifiable
    sil normal! ggdG
    let fcntt = readfile(s:docfile)
    call setline(1, fcntt)
    if a:rkeyword =~ "R History"
        set filetype=r
        call cursor(1, 1)
    elseif a:rkeyword =~ "^MULTILIB"
        syn match Special '<Enter>'
        exe 'syn match String /"' . rkeyw . '"/'
        for idx in range(1, len(msgs) - 2)
            exe "syn match PreProc '^   " . msgs[idx] . "'"
        endfor
        exe 'nnoremap <buffer><silent> <CR> :call AskRDoc("' . rkeyw . '", expand("<cword>"), 0)<CR>'
        redraw
        call cursor(5, 4)
    elseif a:rkeyword =~ '(help)' || search("\x08", "nw") > 0
        set filetype=rdoc
        call cursor(1, 1)
    elseif a:rkeyword =~? '\.Rd$'
        " Called by devtools::load_all().
        " See https://github.com/jalvesaq/Nvim-R/issues/482
        set filetype=rhelp
        call cursor(1, 1)
    else
        set filetype=rout
        setlocal bufhidden=wipe
        setlocal nonumber
        setlocal noswapfile
        set buftype=nofile
        nnoremap <buffer><silent> q :q<CR>
        call cursor(1, 1)
    endif
    let @@ = save_unnamed_reg
    setlocal nomodified
    stopinsert
    redraw
endfunction


"==============================================================================
" Functions to send code directly to R Console
"==============================================================================

function GetSourceArgs(e)
    let sargs = ""
    if g:R_source_args != ""
        let sargs = ", " . g:R_source_args
    endif
    if a:e == "echo"
        let sargs .= ', echo=TRUE'
    endif
    return sargs
endfunction

" Send sources to R
function RSourceLines(...)
    let lines = a:1
    if &filetype == "rrst"
        let lines = map(copy(lines), 'substitute(v:val, "^\\.\\. \\?", "", "")')
    endif
    if &filetype == "rmd"
        let lines = map(copy(lines), 'substitute(v:val, "^(\\`\\`)\\?", "", "")')
    endif
    if !g:R_commented_lines
        let newlines = []
        for line in lines
            if line !~ '^\s*#'
                call add(newlines, line)
            endif
        endfor
        let lines = newlines
    endif

    if a:0 == 3 && a:3 == "NewtabInsert"
        call writefile(lines, s:Rsource_write)
        call AddForDeletion(g:rplugin.tmpdir . '/Rinsert')
        call SendToNvimcom("E", 'nvimcom:::nvim_capture_source_output("' . s:Rsource_read . '", "' . g:rplugin.tmpdir . '/Rinsert")')
        return 1
    endif

    " The "brackted paste" option is not documented because it is not well
    " tested and source() have always worked flawlessly.
    if g:R_source_args == "bracketed paste"
        let rcmd = "\x1b[200~" . join(lines, "\n") . "\x1b[201~"
    else
        call writefile(lines, s:Rsource_write)
        let sargs = substitute(GetSourceArgs(a:2), '^, ', '', '')
        if a:0 == 3
            let rcmd = 'NvimR.' . a:3 . '(' . sargs . ')'
        else
            let rcmd = 'NvimR.source(' . sargs . ')'
        endif
    endif

    if a:0 == 3 && a:3 == "PythonCode"
        let rcmd = 'reticulate::py_run_file("' . s:Rsource_read . '")'
    endif

    let ok = g:SendCmdToR(rcmd)
    return ok
endfunction

" Skip empty lines and lines whose first non blank char is '#'
function GoDown()
    if &filetype == "rnoweb"
        let curline = getline(".")
        if curline[0] == '@'
            call RnwNextChunk()
            return
        endif
    elseif &filetype == "rmd"
        let curline = getline(".")
        if curline =~ '^```$'
            call RmdNextChunk()
            return
        endif
    elseif &filetype == "rrst"
        let curline = getline(".")
        if curline =~ '^\.\. \.\.$'
            call RrstNextChunk()
            return
        endif
    endif

    let i = line(".") + 1
    call cursor(i, 1)
    let curline = CleanCurrentLine()
    let lastLine = line("$")
    while i < lastLine && (curline[0] == '#' || strlen(curline) == 0)
        let i = i + 1
        call cursor(i, 1)
        let curline = CleanCurrentLine()
    endwhile
endfunction

" Send motion to R
function SendMotionToR(type)
    let lstart = line("'[")
    let lend = line("']")
    if lstart == lend
        call SendLineToR("stay", lstart)
    else
        let lines = getline(lstart, lend)
        call RSourceLines(lines, "", "block")
    endif
endfunction

" Send file to R
function SendFileToR(e)
    let flines = getline(1, "$")
    let fpath = expand("%:p") . ".tmp.R"

    if filereadable(fpath)
        call RWarningMsg('Error: cannot create "' . fpath . '" because it already exists. Please, delete it.')
        return
    endif

    if has("win32")
        let fpath = substitute(fpath, "\\", "/", "g")
    endif
    call writefile(flines, fpath)
    call AddForDeletion(fpath)
    let sargs = GetSourceArgs(a:e)
    let ok = g:SendCmdToR('nvimcom:::source.and.clean("' . fpath .  '"' . sargs . ')')
    if !ok
        call delete(fpath)
    endif
endfunction

" Send block to R
" Adapted from marksbrowser plugin
" Function to get the marks which the cursor is between
function SendMBlockToR(e, m)
    if &filetype != "r" && b:IsInRCode(1) != 1
        return
    endif

    let curline = line(".")
    let lineA = 1
    let lineB = line("$")
    let maxmarks = strlen(s:all_marks)
    let n = 0
    while n < maxmarks
        let c = strpart(s:all_marks, n, 1)
        let lnum = line("'" . c)
        if lnum != 0
            if lnum <= curline && lnum > lineA
                let lineA = lnum
            elseif lnum > curline && lnum < lineB
                let lineB = lnum
            endif
        endif
        let n = n + 1
    endwhile
    if lineA == 1 && lineB == (line("$"))
        call RWarningMsg("The file has no mark!")
        return
    endif
    if lineB < line("$")
        let lineB -= 1
    endif
    let lines = getline(lineA, lineB)
    let ok = RSourceLines(lines, a:e, "block")
    if ok == 0
        return
    endif
    if a:m == "down" && lineB != line("$")
        call cursor(lineB, 1)
        call GoDown()
    endif
endfunction

" Send functions to R
function SendFunctionToR(e, m)
    if &filetype != "r" && b:IsInRCode(1) != 1
        return
    endif

    let startline = line(".")
    let save_cursor = getpos(".")
    let line = SanitizeRLine(getline("."))
    let i = line(".")
    while i > 0 && line !~ "function"
        let i -= 1
        let line = SanitizeRLine(getline(i))
    endwhile
    if i == 0
        call RWarningMsg("Begin of function not found.")
        return
    endif
    let functionline = i
    while i > 0 && line !~ '\(<-\|=\)[[:space:]]*\($\|function\)'
        let i -= 1
        let line = SanitizeRLine(getline(i))
    endwhile
    if i == 0
        call RWarningMsg("The function assign operator  <-  was not found.")
        return
    endif
    let firstline = i
    let i = functionline
    let line = SanitizeRLine(getline(i))
    let tt = line("$")
    while i < tt && line !~ "{"
        let i += 1
        let line = SanitizeRLine(getline(i))
    endwhile
    if i == tt
        call RWarningMsg("The function opening brace was not found.")
        return
    endif
    let nb = CountBraces(line)
    while i < tt && nb > 0
        let i += 1
        let line = SanitizeRLine(getline(i))
        let nb += CountBraces(line)
    endwhile
    if nb != 0
        call RWarningMsg("The function closing brace was not found.")
        return
    endif
    let lastline = i

    if startline > lastline
        call setpos(".", [0, firstline - 1, 1])
        call SendFunctionToR(a:e, a:m)
        call setpos(".", save_cursor)
        return
    endif

    let lines = getline(firstline, lastline)
    let ok = RSourceLines(lines, a:e, "function")
    if  ok == 0
        return
    endif
    if a:m == "down"
        call cursor(lastline, 1)
        call GoDown()
    endif
endfunction

" Send all lines above to R
function SendAboveLinesToR()
    let lines = getline(1, line(".") - 1)
    call RSourceLines(lines, "")
endfunction

" Send selection to R
function SendSelectionToR(...)
    let ispy = 0
    if &filetype != "r"
        if &filetype == 'rmd' && RmdIsInPythonCode(0)
            let ispy = 1
        elseif b:IsInRCode(0) != 1
            if (&filetype == "rnoweb" && getline(".") !~ "\\Sexpr{") || (&filetype == "rmd" && getline(".") !~ "`r ") || (&filetype == "rrst" && getline(".") !~ ":r:`")
                call RWarningMsg("Not inside an R code chunk.")
                return
            endif
        endif
    endif

    if line("'<") == line("'>")
        let i = col("'<") - 1
        let j = col("'>") - i
        let l = getline("'<")
        let line = strpart(l, i, j)
        if &filetype == "r"
            let line = CleanOxygenLine(line)
        endif
        let ok = g:SendCmdToR(line)
        if ok && a:2 =~ "down"
            call GoDown()
        endif
        return
    endif

    let lines = getline("'<", "'>")

    if visualmode() == "\<C-V>"
        let lj = line("'<")
        let cj = col("'<")
        let lk = line("'>")
        let ck = col("'>")
        if cj > ck
            let bb = ck - 1
            let ee = cj - ck + 1
        else
            let bb = cj - 1
            let ee = ck - cj + 1
        endif
        if cj > len(getline(lj)) || ck > len(getline(lk))
            for idx in range(0, len(lines) - 1)
                let lines[idx] = strpart(lines[idx], bb)
            endfor
        else
            for idx in range(0, len(lines) - 1)
                let lines[idx] = strpart(lines[idx], bb, ee)
            endfor
        endif
    else
        let i = col("'<") - 1
        let j = col("'>")
        let lines[0] = strpart(lines[0], i)
        let llen = len(lines) - 1
        let lines[llen] = strpart(lines[llen], 0, j)
    endif

    let curpos = getpos(".")
    let curline = line("'<")
    for idx in range(0, len(lines) - 1)
        call setpos(".", [0, curline, 1, 0])
        if &filetype == "r"
            let lines[idx] = CleanOxygenLine(lines[idx])
        endif
        let curline += 1
    endfor
    call setpos(".", curpos)

    if a:0 == 3 && a:3 == "NewtabInsert"
        let ok = RSourceLines(lines, a:1, "NewtabInsert")
    elseif ispy
        let ok = RSourceLines(lines, a:1, 'PythonCode')
    else
        let ok = RSourceLines(lines, a:1, 'selection')
    endif

    if ok == 0
        return
    endif

    if a:2 == "down"
        call GoDown()
    else
        if a:0 < 3 || (a:0 == 3 && a:3 != "normal")
            normal! gv
        endif
    endif
endfunction

" Send paragraph to R
function SendParagraphToR(e, m)
    if &filetype != "r" && b:IsInRCode(1) != 1
        return
    endif

    let o = line(".")
    let c = col(".")
    let i = o
    if g:R_paragraph_begin && getline(i) !~ '^\s*$'
        let line = getline(i-1)
        while i > 1 && !(line =~ '^\s*$' ||
                    \ (&filetype == "rnoweb" && line =~ "^<<") ||
                    \ (&filetype == "rmd" && line =~ "^[ \t]*```{\\(r\\|python\\)"))
            let i -= 1
            let line = getline(i-1)
        endwhile
    endif
    let max = line("$")
    let j = i
    let gotempty = 0
    while j < max
        let line = getline(j+1)
        if line =~ '^\s*$' ||
                    \ (&filetype == "rnoweb" && line =~ "^@$") ||
                    \ (&filetype == "rmd" && line =~ "^[ \t]*```$")
            break
        endif
        let j += 1
    endwhile
    let lines = getline(i, j)
    let ok = RSourceLines(lines, a:e, "paragraph")
    if ok == 0
        return
    endif
    if j < max
        call cursor(j, 1)
    else
        call cursor(max, 1)
    endif
    if a:m == "down"
        call GoDown()
    else
        call cursor(o, c)
    endif
endfunction

" Send R code from the first chunk up to current line
function SendFHChunkToR()
    if &filetype == "rnoweb"
        let begchk = "^<<.*>>=\$"
        let endchk = "^@"
        let chdchk = "^<<.*child *= *"
    elseif &filetype == "rmd"
        let begchk = "^[ \t]*```[ ]*{r"
        let endchk = "^[ \t]*```$"
        let chdchk = "^```.*child *= *"
    elseif &filetype == "rrst"
        let begchk = "^\\.\\. {r"
        let endchk = "^\\.\\. \\.\\."
        let chdchk = "^\.\. {r.*child *= *"
    else
        " Should never happen
        call RWarningMsg('Strange filetype (SendFHChunkToR): "' . &filetype . '"')
    endif

    let codelines = []
    let here = line(".")
    let curbuf = getline(1, "$")
    let idx = 0
    while idx < here
        if curbuf[idx] =~ begchk && curbuf[idx] !~ '\<eval\s*=\s*F'
            " Child R chunk
            if curbuf[idx] =~ chdchk
                " First run everything up to child chunk and reset buffer
                call RSourceLines(codelines, "silent", "chunk")
                let codelines = []

                " Next run child chunk and continue
                call KnitChild(curbuf[idx], 'stay')
                let idx += 1
                " Regular R chunk
            else
                let idx += 1
                while curbuf[idx] !~ endchk && idx < here
                    let codelines += [curbuf[idx]]
                    let idx += 1
                endwhile
            endif
        else
            let idx += 1
        endif
    endwhile
    call RSourceLines(codelines, "silent", "chunk")
endfunction

function KnitChild(line, godown)
    let nline = substitute(a:line, '.*child *= *', "", "")
    let cfile = substitute(nline, nline[0], "", "")
    let cfile = substitute(cfile, nline[0] . '.*', "", "")
    if filereadable(cfile)
        let ok = g:SendCmdToR("require(knitr); knit('" . cfile . "', output=" . s:null . ")")
        if a:godown =~ "down"
            call cursor(line(".")+1, 1)
            call GoDown()
        endif
    else
        call RWarningMsg("File not found: '" . cfile . "'")
    endif
endfunction

function RParenDiff(str)
    let clnln = substitute(a:str, '\\"',  "", "g")
    let clnln = substitute(clnln, "\\\\'",  "", "g")
    let clnln = substitute(clnln, '".\{-}"',  '', 'g')
    let clnln = substitute(clnln, "'.\\{-}'",  "", "g")
    let clnln = substitute(clnln, "#.*", "", "g")
    let llen1 = strlen(substitute(clnln, '[{(\[]', '', 'g'))
    let llen2 = strlen(substitute(clnln, '[})\]]', '', 'g'))
    return llen1 - llen2
endfunction

" Send current line to R.
function SendLineToR(godown, ...)
    let lnum = get(a:, 1, ".")
    let line = getline(lnum)
    if strlen(line) == 0
        if a:godown =~ "down"
            call GoDown()
        endif
        return
    endif

    if &filetype == "rnoweb"
        if line == "@"
            if a:godown =~ "down"
                call GoDown()
            endif
            return
        endif
        if line =~ "^<<.*child *= *"
            call KnitChild(line, a:godown)
            return
        endif
        if RnwIsInRCode(1) != 1
            return
        endif
    endif

    if &filetype == "rmd"
        if line == "```"
            if a:godown =~ "down"
                call GoDown()
            endif
            return
        endif
        if line =~ "^```.*child *= *"
            call KnitChild(line, a:godown)
            return
        endif
        let line = substitute(line, "^(\\`\\`)\\?", "", "")
        if RmdIsInRCode(0) != 1
            if RmdIsInPythonCode(0) == 0
                call RWarningMsg("Not inside an R code chunk.")
                return
            else
                let line = 'reticulate::py_run_string("' . substitute(line, '"', '\\"', 'g') . '")'
            endif
        endif
    endif

    if &filetype == "rrst"
        if line == ".. .."
            if a:godown =~ "down"
                call GoDown()
            endif
            return
        endif
        if line =~ "^\.\. {r.*child *= *"
            call KnitChild(line, a:godown)
            return
        endif
        let line = substitute(line, "^\\.\\. \\?", "", "")
        if RrstIsInRCode(1) != 1
            return
        endif
    endif

    if &filetype == "rdoc"
        if getline(1) =~ '^The topic'
            let topic = substitute(line, '.*::', '', "")
            let package = substitute(line, '::.*', '', "")
            call AskRDoc(topic, package, 1)
            return
        endif
        if RdocIsInRCode(1) != 1
            return
        endif
    endif

    if &filetype == "rhelp" && RhelpIsInRCode(1) != 1
        return
    endif

    if &filetype == "r"
        let line = CleanOxygenLine(line)
    endif

    let block = 0
    if g:R_parenblock
        let chunkend = ""
        if &filetype == "rmd"
            let chunkend = "```"
        elseif &filetype == "rnoweb"
            let chunkend = "@"
        elseif &filetype == "rrst"
            let chunkend = ".. .."
        endif
        let rpd = RParenDiff(line)
        let has_op = line =~ '%>%\s*$'
        if rpd < 0
            let line1 = line(".")
            let cline = line1 + 1
            while cline <= line("$")
                let txt = getline(cline)
                if chunkend != "" && txt == chunkend
                    break
                endif
                let rpd += RParenDiff(txt)
                if rpd == 0
                    let has_op = getline(cline) =~ '%>%\s*$'
                    for lnum in range(line1, cline)
                        if g:R_bracketed_paste
                            if lnum == line1 && lnum == cline
                                let ok = g:SendCmdToR("\x1b[200~" . getline(lnum) . "\x1b[201~\n", 0)
                            elseif lnum == line1
                                let ok = g:SendCmdToR("\x1b[200~" . getline(lnum))
                            elseif lnum == cline
                                let ok = g:SendCmdToR(getline(lnum) . "\x1b[201~\n", 0)
                            else
                                let ok = g:SendCmdToR(getline(lnum))
                            endif
                        else
                            let ok = g:SendCmdToR(getline(lnum))
                        end
                        if !ok
                            " always close bracketed mode upon failure
                            if g:R_bracketed_paste
                                call g:SendCmdToR("\x1b[201~\n", 0)
                            end
                            return
                        endif
                    endfor
                    call cursor(cline, 1)
                    let block = 1
                    break
                endif
                let cline += 1
            endwhile
        endif
    endif

    if !block
        if g:R_bracketed_paste
            let ok = g:SendCmdToR("\x1b[200~" . line . "\x1b[201~\n", 0)
        else
            let ok = g:SendCmdToR(line)
        end
    endif

    if ok
        if a:godown =~ "down"
            call GoDown()
            if exists('has_op') && has_op
                call SendLineToR(a:godown)
            endif
        else
            if a:godown == "newline"
                normal! o
            endif
        endif
    endif
endfunction

function RSendPartOfLine(direction, correctpos)
    let lin = getline(".")
    let idx = col(".") - 1
    if a:correctpos
        call cursor(line("."), idx)
    endif
    if a:direction == "right"
        let rcmd = strpart(lin, idx)
    else
        let rcmd = strpart(lin, 0, idx + 1)
    endif
    call g:SendCmdToR(rcmd)
endfunction

" Clear the console screen
function RClearConsole()
    if g:R_clear_console == 0
        return
    endif
    if has("win32") && type(g:R_external_term) == v:t_number && g:R_external_term == 1
        call JobStdin(g:rplugin.jobs["ClientServer"], "76\n")
        sleep 50m
        call JobStdin(g:rplugin.jobs["ClientServer"], "77\n")
    else
        call g:SendCmdToR("\014", 0)
    endif
endfunction

" Remove all objects
function RClearAll()
    if g:R_rmhidden
        call g:SendCmdToR("rm(list=ls(all.names = TRUE))")
    else
        call g:SendCmdToR("rm(list=ls())")
    endif
    sleep 500m
    call RClearConsole()
endfunction

" Set working directory to the path of current buffer
function RSetWD()
    let wdcmd = 'setwd("' . expand("%:p:h") . '")'
    if has("win32")
        let wdcmd = substitute(wdcmd, "\\", "/", "g")
    endif
    call g:SendCmdToR(wdcmd)
    sleep 100m
endfunction

" knit the current buffer content
function RKnit()
    update
    if has("win32")
        call g:SendCmdToR('require(knitr); .nvim_oldwd <- getwd(); setwd("' . substitute(expand("%:p:h"), '\\', '/', 'g') . '"); knit("' . expand("%:t") . '"); setwd(.nvim_oldwd); rm(.nvim_oldwd)')
    else
        call g:SendCmdToR('require(knitr); .nvim_oldwd <- getwd(); setwd("' . expand("%:p:h") . '"); knit("' . expand("%:t") . '"); setwd(.nvim_oldwd); rm(.nvim_oldwd)')
    endif
endfunction

function StartTxtBrowser(brwsr, url)
    if has("nvim")
        tabnew
        call termopen(a:brwsr . " " . a:url)
        startinsert
    else
        exe 'terminal ++curwin ++close ' . a:brwsr . ' "' . a:url . '"'
    endif
endfunction

function RSourceDirectory(...)
    if has("win32")
        let dir = substitute(a:1, '\\', '/', "g")
    else
        let dir = a:1
    endif
    if dir == ""
        call g:SendCmdToR("nvim.srcdir()")
    else
        call g:SendCmdToR("nvim.srcdir('" . dir . "')")
    endif
endfunction

function PrintRObject(rkeyword)
    if bufname("%") =~ "Object_Browser"
        let firstobj = ""
    else
        let firstobj = RGetFirstObj(a:rkeyword)
    endif
    if firstobj == ""
        call g:SendCmdToR("print(" . a:rkeyword . ")")
    else
        call g:SendCmdToR('nvim.print("' . a:rkeyword . '", "' . firstobj . '")')
    endif
endfunction

function OpenRExample()
    if bufloaded(g:rplugin.tmpdir . "/example.R")
        exe "bunload! " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g')
    endif
    if g:R_nvimpager == "tabnew" || g:R_nvimpager == "tab"
        exe "tabnew " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/example.R"
    else
        let nvimpager = g:R_nvimpager
        if g:R_nvimpager == "vertical"
            let wwidth = winwidth(0)
            let min_e = (g:R_editor_w > 78) ? g:R_editor_w : 78
            let min_h = (g:R_help_w > 78) ? g:R_help_w : 78
            if wwidth < (min_e + min_h)
                let nvimpager = "horizontal"
            endif
        endif
        if nvimpager == "vertical"
            exe "belowright vsplit " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/example.R"
        else
            exe "belowright split " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/example.R"
        endif
    endif
    nnoremap <buffer><silent> q :q<CR>
    setlocal bufhidden=wipe
    setlocal noswapfile
    set buftype=nofile
    call delete(g:rplugin.tmpdir . "/example.R")
endfunction

" Call R functions for the word under cursor
function RAction(rcmd, ...)
    if &filetype == "rbrowser"
        let rkeyword = RBrowserGetName(1, 0)
    elseif a:0 == 1 && a:1 == "v" && line("'<") == line("'>")
        let rkeyword = strpart(getline("'>"), col("'<") - 1, col("'>") - col("'<") + 1)
    elseif a:0 == 1 && a:1 != "v" && a:1 !~ '^,'
        let rkeyword = RGetKeyword()
    else
        let rkeyword = RGetKeyword()
    endif
    if strlen(rkeyword) > 0
        if a:rcmd == "help"
            if rkeyword =~ "::"
                let rhelplist = split(rkeyword, "::")
                let rhelppkg = rhelplist[0]
                let rhelptopic = rhelplist[1]
            else
                let rhelppkg = ""
                let rhelptopic = rkeyword
            endif
            let s:running_rhelp = 1
            if g:R_nvimpager == "no"
                call g:SendCmdToR("help(" . rkeyword . ")")
            else
                if bufname("%") =~ "Object_Browser"
                    if g:rplugin.curview == "libraries"
                        let pkg = RBGetPkgName()
                    else
                        let pkg = ""
                    endif
                endif
                call AskRDoc(rhelptopic, rhelppkg, 1)
            endif
            return
        endif
        if a:rcmd == "print"
            call PrintRObject(rkeyword)
            return
        endif
        let rfun = a:rcmd
        if a:rcmd == "args"
            if g:R_listmethods == 1 && rkeyword !~ '::'
                call g:SendCmdToR('nvim.list.args("' . rkeyword . '")')
            else
                call g:SendCmdToR('args(' . rkeyword . ')')
            endif
            return
        endif
        if a:rcmd == "plot" && g:R_specialplot == 1
            let rfun = "nvim.plot"
        endif
        if a:rcmd == "plotsumm"
            if g:R_specialplot == 1
                let raction = "nvim.plot(" . rkeyword . "); summary(" . rkeyword . ")"
            else
                let raction = "plot(" . rkeyword . "); summary(" . rkeyword . ")"
            endif
            call g:SendCmdToR(raction)
            return
        endif

        if g:R_open_example && a:rcmd == "example"
            call SendToNvimcom("E", 'nvimcom:::nvim.example("' . rkeyword . '")')
            return
        endif

        if a:0 == 1 && a:1 =~ '^,'
            let argmnts = a:1
        elseif a:0 == 2 && a:2 =~ '^,'
            let argmnts = a:2
        else
            let argmnts = ''
        endif

        if a:rcmd == "viewobj" || a:rcmd == "dputtab"
            call delete(g:rplugin.tmpdir . "/Rinsert")
            call AddForDeletion(g:rplugin.tmpdir . "/Rinsert")

            if a:rcmd == "viewobj"
                if exists("g:R_df_viewer")
                    let argmnts .= ', R_df_viewer = "' . g:R_df_viewer . '"'
                endif
                if rkeyword =~ '::'
                    call SendToNvimcom("E",
                                \'nvimcom:::nvim_viewobj(' . rkeyword . argmnts . ')')
                else
                    if has("win32") && &encoding == "utf-8"
                        call SendToNvimcom("E",
                                    \'nvimcom:::nvim_viewobj("' . rkeyword . '"' . argmnts .
                                    \', fenc="UTF-8"' . ')')
                    else
                        call SendToNvimcom("E",
                                    \'nvimcom:::nvim_viewobj("' . rkeyword . '"' . argmnts . ')')
                    endif
                endif
            else
                call SendToNvimcom("E",
                            \'nvimcom:::nvim_dput("' . rkeyword . '"' . argmnts . ')')
            endif
            return
        endif

        let raction = rfun . '(' . rkeyword . argmnts . ')'
        call g:SendCmdToR(raction)
    endif
endfunction

" render a document with rmarkdown
function RMakeRmd(t)
    if !has_key(g:rplugin, "pdfviewer")
        call RSetPDFViewer()
    endif

    update

    let rmddir = expand("%:p:h")
    if has("win32")
        let rmddir = substitute(rmddir, '\\', '/', 'g')
    endif
    if a:t == "default"
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", rmddir = "' . rmddir . '"'
    else
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", outform = "' . a:t .'", rmddir = "' . rmddir . '"'
    endif

    if g:R_rmarkdown_args == ''
        let rcmd = rcmd . ', envir = ' . g:R_rmd_environment . ')'
    else
        let rcmd = rcmd . ', envir = ' . g:R_rmd_environment . ', ' . substitute(g:R_rmarkdown_args, "'", '"', 'g') . ')'
    endif
    call g:SendCmdToR(rcmd)
endfunction

function RBuildTags()
    if filereadable("etags")
        call RWarningMsg('The file "etags" exists. Please, delete it and try again.')
        return
    endif
    call g:SendCmdToR('rtags(ofile = "etags"); etags2ctags("etags", "tags"); unlink("etags")')
endfunction


"==============================================================================
" Set variables
"==============================================================================

let g:R_rmhidden          = get(g:, "R_rmhidden",           0)
let g:R_paragraph_begin   = get(g:, "R_paragraph_begin",    1)
let g:R_after_ob_open     = get(g:, "R_after_ob_open",     [])
let g:R_min_editor_width  = get(g:, "R_min_editor_width",  80)
let g:R_rconsole_width    = get(g:, "R_rconsole_width",    80)
let g:R_rconsole_height   = get(g:, "R_rconsole_height",   15)
let g:R_after_start       = get(g:, "R_after_start",       [])
let g:R_listmethods       = get(g:, "R_listmethods",        0)
let g:R_specialplot       = get(g:, "R_specialplot",        0)
let g:R_notmuxconf        = get(g:, "R_notmuxconf",         0)
let g:R_editor_w          = get(g:, "R_editor_w",          66)
let g:R_help_w            = get(g:, "R_help_w",            46)
let g:R_esc_term          = get(g:, "R_esc_term",           1)
let g:R_close_term        = get(g:, "R_close_term",         1)
let g:R_buffer_opts       = get(g:, "R_buffer_opts", "winfixwidth winfixheight nobuflisted")
let g:R_debug             = get(g:, "R_debug",              1)
let g:R_dbg_jump          = get(g:, "R_dbg_jump",           1)
let g:R_wait              = get(g:, "R_wait",              60)
let g:R_wait_reply        = get(g:, "R_wait_reply",         2)
let g:R_open_example      = get(g:, "R_open_example",       1)
let g:R_bracketed_paste   = get(g:, "R_bracketed_paste",    0)
let g:R_clear_console     = get(g:, "R_clear_console",      1)
let g:R_objbr_auto_start  = get(g:, "R_objbr_auto_start",   0)

" ^K (\013) cleans from cursor to the right and ^U (\025) cleans from cursor
" to the left. However, ^U causes a beep if there is nothing to clean. The
" solution is to use ^A (\001) to move the cursor to the beginning of the line
" before sending ^K. But the control characters may cause problems in some
" circumstances.
let g:R_clear_line = get(g:, "R_clear_line", 0)

let s:r_default_pkgs  = $R_DEFAULT_PACKAGES

" Make the file name of files to be sourced
if exists("g:R_remote_tmpdir")
    let s:Rsource_read = g:R_remote_tmpdir . "/Rsource-" . getpid()
else
    let s:Rsource_read = g:rplugin.tmpdir . "/Rsource-" . getpid()
endif
let s:Rsource_write = g:rplugin.tmpdir . "/Rsource-" . getpid()
call AddForDeletion(s:Rsource_write)

let s:running_objbr = 0
let s:running_rhelp = 0
let s:R_pid = 0
let s:docfile = g:rplugin.tmpdir . "/Rdoc"

" List of marks that the plugin seeks to find the block to be sent to R
let s:all_marks = "abcdefghijklmnopqrstuvwxyz"

if filewritable('/dev/null')
    let s:null = "'/dev/null'"
elseif has("win32") && filewritable('NUL')
    let s:null = "'NUL'"
else
    let s:null = 'tempfile()'
endif
