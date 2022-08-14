" Functions that are called only after omni completion is triggered
"
" The menu must be built and rendered very quickly (< 100ms) to make auto
" completion feasible. That is, the data must be cached (OK, nvim.bol.R),
" indexed (not yet) and processed quickly (OK, nclientserver.c).
"
" The float window that appears when an item is selected can be slower.
" That is, we can call a function in nvimcom to get the contents of the float
" window.

if exists("*FormatInfo")
    finish
endif

let s:float_win = 0
let s:compl_event = {}
let g:rplugin.compl_cls = ''

" If omni completion is called at least once, increase the value of
" g:R_hi_fun_globenv to 1.
if g:R_hi_fun_globenv == 0
    let g:R_hi_fun_globenv = 1
endif

function FormatInfo(width, needblank)
    let ud = s:compl_event['completed_item']['user_data']
    let g:rplugin.compl_cls = ud['cls']

    " Some regions delimited by non separable spaces (digraph NS)
    let info = ''
    if ud['cls'] == 'a'
        let info = ' ' . FormatTxt(ud['argument'], ' ', " \n  ", a:width - 1)
    elseif ud['cls'] == 'l'
        let info = ' ' . FormatTxt(ud['ttl'], ' ', " \n ", a:width - 1) . ' '
        let info .= "\n————\n"
        let info .= ' ' . FormatTxt(ud['descr'], ' ', " \n ", a:width - 1)
    else
        if ud['descr'] != ''
            let info = ' ' . FormatTxt(ud['descr'], ' ', " \n ", a:width - 1) . ' '
        endif
        if ud['cls'] == 'f'
            if ud['descr'] != '' && s:usage != ''
                let info .= "\n————\n"
            endif
            if s:usage != ''
                " Avoid the prefix ', \n  ' if function name + first argment is longer than a:width
                let usg = FormatTxt(s:usage, ', ', ",  \n   ", a:width)
                let usg = substitute(usg, "^,  \n   ", "", "")
                let info .= ' ' . usg . ' '
            endif
        endif
        if a:width > 59 && has_key(ud, 'summary')
            if ud['descr'] != ''
                let info .= "\n————\n"
            endif
            let info .= " " . join(ud['summary'], "\n ") . " "
        endif
    endif

    if info == ''
        return []
    endif
    if a:needblank
        let lines = [''] + split(info, "\n") + ['']
    else
        let lines = split(info, "\n") + ['']
    endif
    return lines
endfunction

function CreateNewFloat(...)
    " The popup menu might already be closed.
    if !pumvisible()
        return
    endif

    if len(s:compl_event) == 0
        return
    endif

    let wrd = s:compl_event['completed_item']['word']

    " Get the required height for a standard float preview window
    let flines = FormatInfo(60, 1)
    if len(flines) == 0
        call CloseFloatWin()
        return
    endif
    let reqh = len(flines) > 15 ? 15 : len(flines)

    " Ensure that some variables are integers:
    exe 'let mc = ' . substitute(string(s:compl_event['col']), '\..*', '', '')
    exe 'let mr = ' . substitute(string(s:compl_event['row']), '\..*', '', '')
    exe 'let mw = ' . substitute(string(s:compl_event['width']), '\..*', '', '')
    exe 'let mh = ' . substitute(string(s:compl_event['height']), '\..*', '', '')

    " Default position and size of float window (at the right side of the popup menu)
    let has_space = 1
    let needblank = 0
    let frow = mr
    let flwd = 60
    let fanchor = 'NW'
    let fcol = mc + mw + s:compl_event['scrollbar']

    " Required to fix the position and size of the float window
    let dspwd = &columns
    let freebelow = (mr == (line('.') - line('w0')) ? &lines - mr - mh : &lines - mr) - 3
    let freeright = dspwd - mw - mc - s:compl_event['scrollbar']
    let freeleft = mc - 1
    let freetop = mr - 1

    " If there is enough vertical space, open the window beside the menu
    if freebelow > reqh && (freeright > 30 || freeleft > 30)
        if freeright > 30
            " right side
            let flwd = freeright > 60 ? 60 : freeright
        else
            " left side
            let flwd = (mc - 1) > 60 ? 60 : (mc - 1)
            let fcol = mc - 1
            let fanchor = 'NE'
        endif
    else
        " If there is enough vertical space and enough right space, then, if the menu
        "   - is below the current line, open the window below the menu
        "   - is above the current line, open the window above the menu
        let freeright = dspwd - mc
        let freeabove = mr - 1
        let freebelow = &lines - mr - mh - 3

        if freeright > 45 && (mr == (line('.') - line('w0') + 1)) && freebelow > reqh
            " below the menu
            let flwd = freeright > 60 ? 60 : freeright
            let fcol = mc - 1
            let frow = mr + mh
            let needblank = 1
        elseif freeright > 45 && (line('.') - line('w0') + 1) > mr && freeabove > reqh
            " above the menu
            let flwd = freeright > 60 ? 60 : freeright
            let fcol = mc - 1
            let frow = mr
            let fanchor = 'SW'
        else
            " Finally, check if it's possible to open the window
            " either on the top or on the bottom of the display
            let flwd = dspwd
            let flines = FormatInfo(flwd, 0)
            let reqh = len(flines) > 15 ? 15 : len(flines)
            let fcol = 0

            if freeabove > reqh || (freeabove > 3 && freeabove > freebelow)
                " top
                let frow = 0
            elseif freebelow > 3
                " bottom
                let frow = &lines
                let fanchor = 'SW'
            else
                " no space available
                let has_space = 0
            endif
        endif
    endif

    if len(flines) == 0 || has_space == 0
        return
    endif

    " Now that the position is defined, calculate the available height
    if frow == &lines
        if mr == (line('.') - line('w0') + 1)
            let maxh = &lines - mr - mh - 2
        else
            let maxh = &lines - line('.') + line('w0') - 2
        endif
        let needblank = 1
    elseif frow == 0
        let maxh = mr - 3
    else
        let maxh = &lines - frow - 2
    endif

    " Open the window if there is enough available height
    if maxh < 2
        return
    endif

    let flines = FormatInfo(flwd, needblank)
    " replace ———— with a complete line
    let realwidth = 10
    for lin in flines
        if strdisplaywidth(lin) > realwidth
            let realwidth = strdisplaywidth(lin)
        endif
    endfor

    if has("win32") && !has("nvim")
        call map(flines, 'substitute(v:val, "^————$", repeat("-", realwidth), "")')
    else
        call map(flines, 'substitute(v:val, "^————$", repeat("—", realwidth), "")')
    endif

    let flht = (len(flines) > maxh) ? maxh : len(flines)

    if has('nvim')
        if !exists('s:float_buf')
            let s:float_buf = nvim_create_buf(v:false, v:true)
            call setbufvar(s:float_buf, '&buftype', 'nofile')
            call setbufvar(s:float_buf, '&bufhidden', 'hide')
            call setbufvar(s:float_buf, '&swapfile', 0)
            call setbufvar(s:float_buf, '&tabstop', 2)
            call setbufvar(s:float_buf, '&undolevels', -1)
        endif
        call nvim_buf_set_option(s:float_buf, 'syntax', 'rdocpreview')

        call nvim_buf_set_lines(s:float_buf, 0, -1, v:true, flines)

        let opts = {'relative': 'editor', 'width': realwidth, 'height': flht,
                    \ 'col': fcol, 'row': frow, 'anchor': fanchor, 'style': 'minimal'}
        if s:float_win
            call nvim_win_set_config(s:float_win, opts)
        else
            let s:float_win = nvim_open_win(s:float_buf, 0, opts)
            call setwinvar(s:float_win, '&wrap', 1)
            call setwinvar(s:float_win, '&colorcolumn', 0)
            call setwinvar(s:float_win, '&signcolumn', 'no')
        endif
    else
        if fanchor == 'NE'
            let fpos = 'topright'
        elseif fanchor == 'SW'
            let fpos = 'botleft'
            let frow -= 1
        else
            let fpos = 'topleft'
        endif
        if s:float_win
            call popup_close(s:float_win)
        endif
        let s:float_win = popup_create(flines, #{
                    \ line: frow + 1, col: fcol, pos: fpos,
                    \ maxheight: flht})
    endif
endfunction

function CloseFloatWin(...)
    if has('nvim')
        let id = win_id2win(s:float_win)
        if id > 0
            let ok = 1
            try
                call nvim_win_close(s:float_win, 1)
            catch /E5/
                " Cannot close the float window after cycling through all the
                " items and going back to the original uncompleted pattern
                let ok = 0
            finally
                if ok
                    let s:float_win = 0
                endif
            endtry
        endif
    else
        call popup_close(s:float_win)
        let s:float_win = 0
    endif
endfunction

function OnCompleteDone()
    call CloseFloatWin()
    let s:auto_compl_col = 0
endfunction

function AskForComplInfo()
    if ! pumvisible()
        return
    endif
    " Other plugins fill the 'user_data' dictionary
    if has_key(v:event, 'completed_item') && has_key(v:event['completed_item'], 'word')
        let s:compl_event = deepcopy(v:event)
        if has_key(s:compl_event['completed_item'], 'user_data') &&
                    \ type(s:compl_event['completed_item']['user_data']) == v:t_dict
            if has_key(s:compl_event['completed_item']['user_data'], 'pkg')
                let pkg = s:compl_event['completed_item']['user_data']['pkg']
                let wrd = s:compl_event['completed_item']['word']
                " Request function description and usage
                call JobStdin(g:rplugin.jobs["ClientServer"], "6" . wrd . "\002" . pkg . "\n")
            elseif has_key(s:compl_event['completed_item']['user_data'], 'cls')
                " Neovim doesn't allow to open a float window from here:
                call timer_start(1, 'CreateNewFloat', {})
            elseif s:float_win
                call CloseFloatWin()
            endif
        endif
    elseif s:float_win
        call CloseFloatWin()
    endif
endfunction

function FinishGlbEnvFunArgs(fnm)
    if filereadable(g:rplugin.tmpdir . "/args_for_completion")
        let usage = readfile(g:rplugin.tmpdir . "/args_for_completion")[0]
        let usage = '[' . substitute(usage, "\004", "'", 'g') . ']'
        let usage = eval(usage)
        call map(usage, 'join(v:val, " = ")')
        let usage = join(usage, ", ")
        let s:usage = a:fnm . '(' . usage . ')'
    else
        let s:usage = "COULD NOT GET ARGUMENTS"
    endif
    let s:compl_event['completed_item']['user_data']['descr'] = ''
    call CreateNewFloat()
endfunction

function FinishGetSummary()
    if filereadable(g:rplugin.tmpdir . "/args_for_completion")
        let s:compl_event['completed_item']['user_data']['summary'] = readfile(g:rplugin.tmpdir . "/args_for_completion")
    endif
    call CreateNewFloat()
endfunction

function SetComplInfo(dctnr)
    " Replace user_data with the complete version
    let s:compl_event['completed_item']['user_data'] = deepcopy(a:dctnr)

    if a:dctnr['cls'] == 'f'
        let usage = deepcopy(a:dctnr['usage'])
        call map(usage, 'join(v:val, " = ")')
        let usage = join(usage, ", ")
        let s:usage = a:dctnr['word'] . '(' . usage . ')'
    elseif a:dctnr['word'] =~ '\k\{-}\$\k\{-}'
        call delete(g:rplugin.tmpdir . "/args_for_completion")
        call SendToNvimcom("E", 'nvimcom:::nvim.get.summary(' . a:dctnr['word'] . ', 59)')
        return
    endif

    if len(a:dctnr) > 0
        call CreateNewFloat()
    endif
endfunction

function GetRArgs(id, base, rkeyword0, firstobj, pkg)
    if a:rkeyword0 == ""
        return
    endif
    call delete(g:rplugin.tmpdir . "/args_for_completion")
    let msg = 'nvimcom:::nvim_complete_args("' . a:id . '", "' . a:rkeyword0 . '", "' . a:base . '"'
    if a:firstobj != ""
        let msg .= ', firstobj = "' . a:firstobj . '"'
    elseif a:pkg != ""
        let msg .= ', pkg = ' . a:pkg
    endif
    let msg .= ')'

    " Save documentation of arguments to be used by nclientserver
    call SendToNvimcom("E", msg)
endfunction

function GetListOfRLibs(base)
    let argls = []
    let lsd = glob(g:rplugin.compldir . '/descr_*', 0, 1)
    for fl in lsd
        if fl =~ 'descr_' . a:base
            let pnm = substitute(fl, '.*/descr_\(.\{-}\)_.*', '\1', 'g')
            let lin = readfile(fl)[0]
            let dsc = substitute(lin, ".*\t", "", "")
            let ttl = substitute(lin, "\t.*", "", "")
            call add(argls, {'word': pnm, 'user_data': {'ttl': ttl, 'descr': dsc, 'cls': 'l'}})
        endif
    endfor
    return argls
endfunction

" TODO: Create a copy of this function at nclientserver.c
" We still need this here for omnifunc
function FindStartRObj()
    let line = getline(".")
    let lnum = line(".")
    let cpos = getpos(".")
    let idx = cpos[2] - 2
    let idx2 = cpos[2] - 2
    if line[idx2] == ' ' || line[idx2] == ',' || line[idx2] == '('
        let idx2 = cpos[2]
        let s:argkey = ''
    else
        let idx1 = idx2
        while line[idx1] =~ '\w' || line[idx1] == '.' || line[idx1] == '_' ||
                    \ line[idx1] == ':' || line[idx1] == '$' || line[idx1] == '@' ||
                    \ (line[idx1] > "\x80" && line[idx1] < "\xf5")
            let idx1 -= 1
        endwhile
        let idx1 += 1
        let argkey = strpart(line, idx1, idx2 - idx1 + 1)
        let idx2 = cpos[2] - strlen(argkey)
        let s:argkey = argkey
    endif
    return idx2 - 1
endfunction

" TODO: Transfer this function to nclientserver.c
function NeedRArguments(line, cpos)
    " Check if we need function arguments
    let line = a:line
    let lnum = line(".")
    let cpos = a:cpos
    let idx = cpos[2] - 2
    let idx2 = cpos[2] - 2
    let np = 1
    let nl = 0
    let argls = []
    " Look up to 10 lines above for an opening parenthesis
    while nl < 10
        if line[idx] == '('
            let np -= 1
        elseif line[idx] == ')'
            let np += 1
        endif
        if np == 0
            " The opening parenthesis was found
            let rkeyword0 = RGetKeyword(lnum, idx)
            let firstobj = ""
            if rkeyword0 =~ "::"
                let pkg = '"' . substitute(rkeyword0, "::.*", "", "") . '"'
                let rkeyword0 = substitute(rkeyword0, ".*::", "", "")
            else
                if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                    let firstobj = RGetFirstObj(rkeyword0, lnum, idx)
                endif
                let pkg = ""
            endif
            return [rkeyword0, firstobj, pkg, lnum, cpos]
        endif
        let idx -= 1
        if idx <= 0
            let lnum -= 1
            if lnum == 0
                break
            endif
            let line = getline(lnum)
            let idx = strlen(line)
            let nl +=1
        endif
    endwhile
    return []
endfunction

function SetComplMenu(id, cmn)
    if s:is_auto_completing
        let s:is_auto_completing = 0
        if a:id == s:completion_id
            " The completion_id will be invalid if nclientserver is too slow
            " and the user has already pressed another key
            call complete(s:auto_compl_col + 1, a:cmn)
        endif
    else
        let s:compl_menu = deepcopy(a:cmn)
        let s:waiting_compl_menu = 0
    endif
endfunction

function AutoComplLibname(...)
    let s:is_completing = 1
    call complete(s:auto_compl_col + 1, s:libnames_list)
endfunction

function AutoComplChunkOpts(...)
    let s:is_completing = 1
    call complete(s:auto_compl_col + 1, s:chunk_opt_list)
endfunction

let s:completion_id = 0
let s:is_auto_completing = 0
function RTriggerCompletion()
    let s:completion_id += 1

    " We are within the InsertCharPre event
    if v:char =~ '\k\|@\|\$\|\:\|_\|\.'
        let s:auto_compl_col = FindStartRObj()
        let wrd = RGetKeyword(line("."), s:auto_compl_col) . v:char
    else
        let wrd = ""
        let s:auto_compl_col = col(".")
    endif

    if b:IsInRCode(0) == 2
        if wrd == ''
            return
        endif
        let s:compl_type = 3
        let s:chunk_opt_list = CompleteChunkOptions(wrd)
        " Can't call complete() here [E523]
        call timer_start(1, 'AutoComplChunkOpts', {})
        return
    endif

    let snm = synIDattr(synID(line("."), col(".") - 1, 1), "name")
    if snm == "rComment"
        return
    endif

    let lin = getline(".")
    let lin = strpart(lin, 0, col(".")) . v:char
    let cpos = getpos(".")
    let cpos[2] = cpos[2] + 1
    let nra = NeedRArguments(lin, cpos)
    if len(nra) > 0
        if (nra[0] == "library" || nra[0] == "require") && IsFirstRArg(lin, nra[3], nra[4])
            let s:libnames_list = GetListOfRLibs(wrd)
            if len(s:libnames_list)
                " Can't call complete() here [E523]
                call timer_start(1, 'AutoComplLibname', {})
                return
            endif
        endif

        if snm == "rString"
            return
        endif

        let s:is_auto_completing = 1
        if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
            call GetRArgs(s:completion_id, wrd, nra[0], nra[1], nra[2])
        endif
        return
    endif

    if wrd == '' || snm == "rString"
        return
    endif

    let s:compl_type = 1
    let s:is_auto_completing = 1
    call JobStdin(g:rplugin.jobs["ClientServer"], "5" . s:completion_id . "\003" . wrd . "\n")
endfunction

function CompleteR(findstart, base)
    if a:findstart
        let line = getline(".")
        if b:rplugin_knitr_pattern != '' && line =~ b:rplugin_knitr_pattern
            let s:compl_type = 3
            return FindStartRObj()
        elseif b:IsInRCode(0) == 0 && b:rplugin_non_r_omnifunc != ''
            let s:compl_type = 2
            let Ofun = function(b:rplugin_non_r_omnifunc)
            return Ofun(a:findstart, a:base)
        else
            let s:compl_type = 1
            return FindStartRObj()
        endif
    else
        if s:compl_type == 3
            return CompleteChunkOptions(a:base)
        elseif s:compl_type == 2
            let Ofun = function(b:rplugin_non_r_omnifunc)
            return Ofun(a:findstart, a:base)
        endif

        " The base might have changed because the user has hit the backspace key
        call CloseFloatWin()

        let nra = NeedRArguments(getline("."), getpos("."))
        if len(nra) > 0
            if (nra[0] == "library" || nra[0] == "require") && IsFirstRArg(getline("."), nra[3], nra[4])
                let argls = GetListOfRLibs(a:base)
                if len(argls)
                    let s:is_completing = 1
                    return argls
                endif
            endif

            call UpdateRGlobalEnv(1)
            let s:waiting_compl_menu = 1
            if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                call GetRArgs(s:completion_id, a:base, nra[0], nra[1], nra[2])
                return WaitRCompletion()
            endif
        endif

        if a:base == ''
            " Require at least one character to try omni completion
            return []
        endif

        if exists('s:compl_menu')
            unlet s:compl_menu
        endif
        call UpdateRGlobalEnv(1)
        let s:waiting_compl_menu = 1
        call JobStdin(g:rplugin.jobs["ClientServer"], "5" . s:completion_id . "\003" .  a:base . "\n")
        return WaitRCompletion()
    endif
endfunction

function WaitRCompletion()
    sleep 10m
    let nwait = 0
    while s:waiting_compl_menu && nwait < 100
        let nwait += 1
        sleep 10m
    endwhile
    if exists('s:compl_menu')
        let s:is_completing = 1
        return s:compl_menu
    endif
    return []
endfunction

" TODO: Transfer this function to nclientserver.c
function CompleteChunkOptions(base)
    " https://yihui.org/knitr/options/#chunk-options (2021-04-19)
    let lines = readfile(g:rplugin.home . '/R/chunk_options')

    let ktopt = []
    for lin in lines
        let dict = eval(lin)
        let dict['abbr'] = dict['word']
        let dict['word'] = dict['word'] . '='
        let dict['menu'] = '= ' . dict['menu']
        let dict['user_data']['cls'] = 'k'
        let ktopt += [deepcopy(dict)]
    endfor

    let rr = []

    if strlen(a:base) > 0
        let newbase = '^' . substitute(a:base, "\\$$", "", "")
        call filter(ktopt, 'v:val["abbr"] =~ newbase')
    endif

    call sort(ktopt)
    for kopt in ktopt
        call add(rr, kopt)
    endfor
    return rr
endfunction

function IsFirstRArg(line, lnum, cpos)
    let line = a:line
    let ii = a:cpos[2] - 2
    let cchar = line[ii]
    while ii > 0 && cchar != '('
        let cchar = line[ii]
        if cchar == ','
            return 0
        endif
        let ii -= 1
    endwhile
    return 1
endfunction
