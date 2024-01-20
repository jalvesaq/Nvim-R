" Functions that are called only after omni completion is triggered
"
" The menu must be built and rendered very quickly (< 100ms) to make auto
" completion feasible. That is, the data must be cached (OK, nvim.bol.R),
" indexed (not yet) and processed quickly (OK, nvimrserver.c).
"
" The float window that appears when an item is selected can be slower.
" That is, we can call a function in nvimcom to get the contents of the float
" window.

if exists("*CompleteR")
    finish
endif

let s:float_win = 0
let s:compl_event = {}
let g:rplugin.compl_cls = ''

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
            let info = ' ' . FormatTxt(ud['descr'], ' ', " \n ", a:width - 1)
        endif
        if ud['cls'] == 'f'
            if s:usage != ''
                if ud['descr'] != ''
                    let info .= "\n————\n"
                endif
                let usg = "```{R} \n "
                " Avoid the prefix ', \n  ' if function name + first argment is longer than a:width
                let usg .= FormatTxt(s:usage, ', ', ",  \n   ", a:width)
                let usg = substitute(usg, "^,  \n   ", "", "")
                let usg .= "\n```\n"
                let info .= usg
            endif
        endif
        if a:width > 29 && has_key(ud, 'summary')
            let info .= "\n```{Rout} \n" . join(ud['summary'], "\n ") . "\n```\n"
        endif
    endif

    if info == ''
        return []
    endif
    if a:needblank
        let lines = [''] + split(info, "\n")
    else
        let lines = split(info, "\n")
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
    let mc = float2nr(s:compl_event['col'])
    let mr = float2nr(s:compl_event['row'])
    let mw = float2nr(s:compl_event['width'])
    let mh = float2nr(s:compl_event['height'])

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
        call nvim_set_option_value('syntax', 'rdocpreview', {'buf': s:float_buf})

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
            call setwinvar(s:float_win, '&conceallevel', 3)
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
                call JobStdin(g:rplugin.jobs["Server"], "6" . wrd . "\002" . pkg . "\n")
            elseif has_key(s:compl_event['completed_item']['user_data'], 'cls')
                if s:compl_event['completed_item']['user_data']['cls'] == 'v'
                    let pkg = s:compl_event['completed_item']['user_data']['env']
                    let wrd = s:compl_event['completed_item']['user_data']['word']
                    call JobStdin(g:rplugin.jobs["Server"], "6" . wrd . "\002" . pkg . "\n")
                else
                    " Neovim doesn't allow to open a float window from here:
                    call timer_start(1, 'CreateNewFloat', {})
                endif
            elseif s:float_win
                call CloseFloatWin()
            endif
        endif
    elseif s:float_win
        call CloseFloatWin()
    endif
endfunction

function FinishGlbEnvFunArgs(fnm, txt)
        let usage = substitute(a:txt, "\x14", "\n", "g")
        let usage = substitute(usage, "\x13", "''", "g")
        let usage = substitute(usage, "\005", '\\"', "g")
        let usage = substitute(usage, "\x12", "'", "g")
        let usage = '[' . usage . ']'
        let usage = eval(usage)
        call map(usage, 'join(v:val, " = ")')
        let usage = join(usage, ", ")
        let s:usage = a:fnm . '(' . usage . ')'
    let s:compl_event['completed_item']['user_data']['descr'] = ''
    call CreateNewFloat()
endfunction

function FinishGetSummary(txt)
    let summary = split(substitute(a:txt, "\x13", "'", "g"), "\x14")
    let s:compl_event['completed_item']['user_data']['summary'] = summary
    call CreateNewFloat()
endfunction

function SetComplInfo(dctnr)
    " Replace user_data with the complete version
    let s:compl_event['completed_item']['user_data'] = deepcopy(a:dctnr)

    if has_key(a:dctnr, 'cls') && a:dctnr['cls'] == 'f'
        let usage = deepcopy(a:dctnr['usage'])
        call map(usage, 'join(v:val, " = ")')
        let usage = join(usage, ", ")
        let s:usage = a:dctnr['word'] . '(' . usage . ')'
    elseif has_key(a:dctnr, 'word') && a:dctnr['word'] =~ '\k\{-}\$\k\{-}'
        call SendToNvimcom("E", 'nvimcom:::nvim.get.summary(' . a:dctnr['word'] . ', 59)')
        return
    endif

    if len(a:dctnr) > 0
        call CreateNewFloat()
    else
        call CloseFloatWin()
    endif
endfunction

" We can't transfer this function to the nvimrserver because
" nvimcom:::nvim_complete_args runs the function methods(), and we couldn't do
" something similar in the nvimrserver.
function GetRArgs(id, base, rkeyword0, listdf, firstobj, pkg, isfarg)
    if a:rkeyword0 == ""
        return
    endif
    let msg = 'nvimcom:::nvim_complete_args("' . a:id . '", "' . a:rkeyword0 . '", "' . a:base . '"'
    if a:firstobj != ""
        let msg .= ', firstobj = "' . a:firstobj . '"'
    elseif a:pkg != ""
        let msg .= ', pkg = ' . a:pkg
    endif
    if a:firstobj != '' && ((a:listdf == 1 && !a:isfarg) || a:listdf == 2)
        let msg .= ', ldf = TRUE'
    endif
    let msg .= ')'

    " Save documentation of arguments to be used by nvimrserver
    call SendToNvimcom("E", msg)
endfunction

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

function NeedRArguments(line, cpos)
    " Check if we need function arguments
    let line = a:line
    let lnum = line(".")
    let cpos = a:cpos
    let idx = cpos[2] - 2
    let np = 1
    let nl = 0
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
            let ispiped = v:false
            let listdf = 0
            if rkeyword0 =~ "::"
                let pkg = '"' . substitute(rkeyword0, "::.*", "", "") . '"'
                let rkeyword0 = substitute(rkeyword0, ".*::", "", "")
            else
                let rkeyword1 = rkeyword0
                if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                    for fnm in g:R_fun_data_1
                        if fnm == rkeyword0
                            let listdf = 1
                            break
                        endif
                    endfor
                    for key in keys(g:R_fun_data_2)
                        if g:R_fun_data_2[key][0] == '*' || index(g:R_fun_data_2[key], rkeyword0) > -1
                            let listdf = 2
                            let rkeyword1 = key
                            break
                        endif
                    endfor
                    if listdf == 2
                        " Get first object of nesting function, if any
                        if line =~ rkeyword1 . '\s*('
                            let idx = stridx(line, rkeyword1)
                        else
                            let line = getline(lnum - 1)
                            if line =~ rkeyword1 . '\s*('
                                let idx = stridx(line, rkeyword1)
                            else
                                let rkeyword1 = rkeyword0
                                let listdf = v:false
                            endif
                        endif
                    endif
                    let ro = RGetFirstObj(rkeyword1, line, idx, listdf)
                    let firstobj = ro[0]
                    let ispiped = ro[1]
                endif
                let pkg = ""
            endif
            return [rkeyword0, listdf, firstobj, ispiped, pkg, lnum, cpos]
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
    let s:compl_menu = deepcopy(a:cmn)
    for idx in range(len(s:compl_menu))
        let s:compl_menu[idx]['word'] = substitute(s:compl_menu[idx]['word'], "\x13", "'", "g")
    endfor
    let s:waiting_compl_menu = 0
endfunction

let s:completion_id = 0
function CompleteR(findstart, base)
    if a:findstart
        let lin = getline(".")
        let isInR = b:IsInRCode(0)
        if (&filetype == 'quarto' || &filetype == 'rmd') && isInR == 1 && lin =~ '^#| ' && lin !~ '^#| \k.*:'
            let s:compl_type = 4
            let ywrd = substitute(lin, '^#| *', '', '')
            return stridx(lin, ywrd)
        elseif b:rplugin_knitr_pattern != '' && lin =~ b:rplugin_knitr_pattern
            let s:compl_type = 3
            return FindStartRObj()
        elseif isInR == 0 && b:rplugin_non_r_omnifunc != ''
            let s:compl_type = 2
            let Ofun = function(b:rplugin_non_r_omnifunc)
            return Ofun(a:findstart, a:base)
        else
            let s:compl_type = 1
            return FindStartRObj()
        endif
    else
        if s:compl_type == 4
            return CompleteQuartoCellOptions(a:base)
        elseif s:compl_type == 3
            return CompleteChunkOptions(a:base)
        elseif s:compl_type == 2
            let Ofun = function(b:rplugin_non_r_omnifunc)
            return Ofun(a:findstart, a:base)
        endif

        " The base might have changed because the user has hit the backspace key
        call CloseFloatWin()

        let nra = NeedRArguments(getline("."), getpos("."))
        if len(nra) > 0
            let isfa = nra[3] ? v:false : IsFirstRArg(getline("."), nra[6])
            if (nra[0] == "library" || nra[0] == "require") && isfa
                let s:waiting_compl_menu = 1
                call JobStdin(g:rplugin.jobs["Server"], "5" . s:completion_id . "\003" . "\004" . a:base . "\n")
                return WaitRCompletion()
            endif

            let s:waiting_compl_menu = 1
            if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                call GetRArgs(s:completion_id, a:base, nra[0], nra[1], nra[2], nra[4], isfa)
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
        let s:waiting_compl_menu = 1
        call JobStdin(g:rplugin.jobs["Server"], "5" . s:completion_id . "\003" .  a:base . "\n")
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

function CompleteChunkOptions(base)
    " https://yihui.org/knitr/options/#chunk-options (2021-04-19)
    let lines = json_decode(join(readfile(g:rplugin.home . '/R/chunk_options.json')))

    let ktopt = []
    for lin in lines
        let lin['abbr'] = lin['word']
        let lin['word'] = lin['word'] . '='
        let lin['menu'] = '= ' . lin['menu']
        let lin['user_data']['cls'] = 'k'
        let ktopt += [deepcopy(lin)]
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

function CompleteQuartoCellOptions(base)
    if !exists('s:qchunk_opt_list')
        call FillQuartoComplMenu()
    endif
    let s:cell_opt_list = deepcopy(s:qchunk_opt_list)
    if strlen(a:base) > 0
        let newbase = '^' . substitute(a:base, "\\$$", "", "")
        call filter(s:cell_opt_list, 'v:val["abbr"] =~ newbase')
    endif
    return s:cell_opt_list
endfunction

function IsFirstRArg(line, cpos)
    let ii = a:cpos[2] - 2
    while ii > 0
        if a:line[ii] == '('
            return 1
        endif
        if a:line[ii] == ','
            return 0
        endif
        let ii -= 1
    endwhile
    return 0
endfunction

function FillQuartoComplMenu()
    let s:qchunk_opt_list = []

    if exists('g:R_quarto_intel')
        let quarto_yaml_intel = g:R_quarto_intel
    else
        let quarto_yaml_intel = ''
        if has('win32')
            let paths = split($PATH, ';')
            call filter(paths, 'v:val =~? "quarto"')
            if len(paths) > 0
                let qjson = substitute(paths[0], 'bin$', 'share/editor/tools/yaml/yaml-intelligence-resources.json', '')
                let qjson = substitute(qjson, '\\', '/', 'g')
                if filereadable(qjson)
                    let quarto_yaml_intel = qjson
                endif
            endif
        elseif executable('quarto')
            let quarto_bin = system('which quarto')
            let quarto_dir1 = substitute(quarto_bin, '\(.*\)/.\{-}/.*', '\1', 'g')
            let quarto_yaml_intel = ''
            if filereadable(quarto_dir1 . '/share/editor/tools/yaml/yaml-intelligence-resources.json')
                let quarto_yaml_intel = quarto_dir1 . '/share/editor/tools/yaml/yaml-intelligence-resources.json'
            else
                let quarto_bin = system('readlink ' . quarto_bin)
                let quarto_dir2 = substitute(quarto_bin, '\(.*\)/.\{-}/.*', '\1', 'g')
                if quarto_dir2 =~ '^\.\./'
                    while quarto_dir2 =~ '^\.\./'
                        let quarto_dir2 = substitute(quarto_dir2, '^\.\./*', '', '')
                    endwhile
                    let quarto_dir2 = quarto_dir1 . '/' . quarto_dir2
                endif
                if filereadable(quarto_dir2 . '/share/editor/tools/yaml/yaml-intelligence-resources.json')
                    let quarto_yaml_intel = quarto_dir2 . '/share/editor/tools/yaml/yaml-intelligence-resources.json'
                endif
            endif
        endif
    endif

    if quarto_yaml_intel != ''
        let intel = json_decode(join(readfile(quarto_yaml_intel), "\n"))
        for key in ['schema/cell-attributes.yml',
                    \ 'schema/cell-cache.yml',
                    \ 'schema/cell-codeoutput.yml',
                    \ 'schema/cell-figure.yml',
                    \ 'schema/cell-include.yml',
                    \ 'schema/cell-layout.yml',
                    \ 'schema/cell-pagelayout.yml',
                    \ 'schema/cell-table.yml',
                    \ 'schema/cell-textoutput.yml']
            let tmp = intel[key]
            for item in tmp
                let abr = item['name']
                let wrd = abr . ': '
                let descr = type(item['description']) == v:t_string ? item['description'] : item['description']['long']
                let descr = substitute(descr, '\n', ' ', 'g')
                let dict = {'word': wrd, 'abbr': abr, 'menu': '[opt]', 'user_data': {'cls': 'k', 'descr': descr}}
                call add(s:qchunk_opt_list, dict)
            endfor
        endfor
    endif
endfunction

function RComplAutCmds()
    if &filetype == "rnoweb" || &filetype == "rrst" || &filetype == "rmd" || &filetype == "quarto"
        if &omnifunc == "CompleteR"
            let b:rplugin_non_r_omnifunc = ""
        else
            let b:rplugin_non_r_omnifunc = &omnifunc
        endif
    endif
    if index(g:R_set_omnifunc, &filetype) > -1
        setlocal omnifunc=CompleteR
    endif

    " Test whether the autocommands were already defined to avoid getting them
    " registered three times
    if !exists('b:did_RBuffer_au')
        augroup RBuffer
            if index(g:R_set_omnifunc, &filetype) > -1
                autocmd CompleteChanged <buffer> call AskForComplInfo()
                autocmd CompleteDone <buffer> call OnCompleteDone()
            endif
        augroup END
    endif
    let b:did_RBuffer_au = 1
endfunction
