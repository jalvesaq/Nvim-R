"==============================================================================
" Functions that might be called even before R is started.
"
" The functions and variables defined here are common for all buffers of all
" file types supported by Nvim-R and must be defined only once.
"==============================================================================


set encoding=utf-8
scriptencoding utf-8

" Do this only once
if exists("s:did_global_stuff")
    finish
endif
let s:did_global_stuff = 1

if !exists('g:rplugin')
    " Attention: also in functions.vim because either of them might be sourced first.
    let g:rplugin = {'debug_info': {}, 'libs_in_nrs': [], 'nrs_running': 0, 'myport': 0, 'R_pid': 0}
endif

let g:rplugin.debug_info['Time'] = {'common_global.vim': reltime()}

"==============================================================================
" Check if there is more than one copy of Nvim-R
" (e.g. from the Vimballl and from a plugin manager)
"==============================================================================

if exists("*RWarningMsg")
    " A common_global.vim script was sourced from another version of NvimR.
    finish
endif


"==============================================================================
" WarningMsg
"==============================================================================

function CloseRWarn(timer)
    let id = win_id2win(s:float_warn)
    if id > 0
        call nvim_win_close(s:float_warn, 1)
    endif
endfunction

function FormatPrgrph(text, splt, jn, maxlen)
    let wlist = split(a:text, a:splt)
    let txt = ['']
    let ii = 0
    for wrd in wlist
        if strdisplaywidth(txt[ii] . a:splt . wrd) < a:maxlen
            let txt[ii] .= a:splt . wrd
        else
            let ii += 1
            let txt += [wrd]
        endif
    endfor
    let txt[0] = substitute(txt[0], '^' . a:splt, '', '')
    return join(txt, a:jn)
endfunction

function FormatTxt(text, splt, jn, maxl)
    let maxlen = a:maxl - len(a:jn)
    let atext = substitute(a:text, "\x13", "'", "g")
    let plist = split(atext, "\x14")
    let txt = ''
    for prg in plist
        let txt .= "\n " . FormatPrgrph(prg, a:splt, a:jn, maxlen)
    endfor
    let txt = substitute(txt, "^\n ", "", "")
    return txt
endfunction

let s:float_warn = 0
let g:rplugin.has_notify = v:false
if has('nvim')
    lua if pcall(require, 'notify') then vim.cmd('let g:rplugin.has_notify = v:true') end
endif
function RFloatWarn(wmsg)
    if g:rplugin.has_notify
        let qmsg = substitute(a:wmsg, "'", "\\\\'", "g")
        exe "lua require('notify')('" . qmsg . "', 'warn', {title = 'Nvim-R'})"
        return
    endif

    " Close any float warning eventually still open
    let id = win_id2win(s:float_warn)
    if id > 0
        call nvim_win_close(s:float_warn, 1)
    endif

    let fmsg = ' ' . FormatTxt(a:wmsg, ' ', " \n ", 60)
    let fmsgl = split(fmsg, "\n")
    let realwidth = 10
    for lin in fmsgl
        if strdisplaywidth(lin) > realwidth
            let realwidth = strdisplaywidth(lin)
        endif
    endfor
    let wht = len(fmsgl) > 3 ? 3 : len(fmsgl)
    if has('nvim')
        if !exists('s:warn_buf')
            let s:warn_buf = nvim_create_buf(v:false, v:true)
            call setbufvar(s:warn_buf, '&buftype', 'nofile')
            call setbufvar(s:warn_buf, '&bufhidden', 'hide')
            call setbufvar(s:warn_buf, '&swapfile', 0)
            call setbufvar(s:warn_buf, '&tabstop', 2)
            call setbufvar(s:warn_buf, '&undolevels', -1)
        endif
        call nvim_set_option_value('syntax', 'off', {'buf': s:warn_buf})
        call nvim_buf_set_lines(s:warn_buf, 0, -1, v:true, fmsgl)
        let opts = {'relative': 'editor', 'width': realwidth, 'height': wht,
                    \ 'col': winwidth(0) - realwidth,
                    \ 'row': &lines - 3 - wht, 'anchor': 'NW', 'style': 'minimal'}
        let s:float_warn = nvim_open_win(s:warn_buf, 0, opts)
        hi FloatWarnNormal ctermfg=196 guifg=#ff0000 guibg=#222200
        call nvim_win_set_option(s:float_warn, 'winhl', 'Normal:FloatWarnNormal')
        call timer_start(2000 * len(fmsgl), 'CloseRWarn')
    else
        let fline = &lines - 2 - wht
        let fcol = winwidth(0) - realwidth
        let s:float_warn = popup_create(fmsgl, #{
                    \ line: fline,
                    \ col: fcol,
                    \ highlight: 'WarningMsg',
                    \ time: 2000 * len(fmsgl),
                    \ })
    endif
endfunction

function WarnAfterVimEnter1()
    call timer_start(1000, 'WarnAfterVimEnter2')
endfunction

function WarnAfterVimEnter2(...)
    for msg in s:start_msg
        call RWarningMsg(msg)
    endfor
endfunction

function RWarningMsg(wmsg)
    if v:vim_did_enter == 0
        if !exists('s:start_msg')
            let s:start_msg = [a:wmsg]
            exe 'autocmd VimEnter * call WarnAfterVimEnter1()'
        else
            let s:start_msg += [a:wmsg]
        endif
        return
    endif
    if mode() == 'i' && (has('nvim-0.5.0') || has('patch-8.2.84'))
        call RFloatWarn(a:wmsg)
    endif
    echohl WarningMsg
    echomsg a:wmsg
    echohl None
endfunction


"==============================================================================
" Check Vim/Neovim version
"==============================================================================

if has("nvim")
    if !has("nvim-0.6.0")
        call RWarningMsg("Nvim-R requires Neovim >= 0.6.0.")
        let g:rplugin.failed = 1
        finish
    endif
elseif v:version < "802"
    call RWarningMsg("Nvim-R requires either Neovim >= 0.6.0 or Vim >= 8.2.84")
    let g:rplugin.failed = 1
    finish
elseif !has("channel") || !has("job") || !has('patch-8.2.84')
    call RWarningMsg("Nvim-R requires either Neovim >= 0.6.0 or Vim >= 8.2.84\nIf using Vim, it must have been compiled with both +channel and +job features.\n")
    let g:rplugin.failed = 1
    finish
endif

" Convert _ into <-
function ReplaceUnderS()
    if g:R_assign == 0
        " See https://github.com/jalvesaq/Nvim-R/issues/668
        exe 'iunmap <buffer> ' g:R_assign_map
        exe "normal! a" . g:R_assign_map
        return
    endif
    if &filetype != "r" && b:IsInRCode(0) != 1
        let isString = 1
    else
        let save_unnamed_reg = @@
        let j = col(".")
        let s = getline(".")
        if g:R_assign == 1 && g:R_assign_map == "_" && j > 3 && s[j-3] == "<" && s[j-2] == "-" && s[j-1] == " "
            exe "normal! 3h3xr_"
            let @@ = save_unnamed_reg
            return
        endif
        let isString = 0
        let synName = synIDattr(synID(line("."), j, 1), "name")
        if synName == "rSpecial"
            let isString = 1
        else
            if synName == "rString"
                let isString = 1
                if s[j-1] == '"' || s[j-1] == "'" && g:R_assign == 1
                    let synName = synIDattr(synID(line("."), j-2, 1), "name")
                    if synName == "rString" || synName == "rSpecial"
                        let isString = 0
                    endif
                endif
            else
                if g:R_assign == 2
                    if s[j-1] != "_" && !(j > 3 && s[j-3] == "<" && s[j-2] == "-" && s[j-1] == " ")
                        let isString = 1
                    elseif j > 3 && s[j-3] == "<" && s[j-2] == "-" && s[j-1] == " "
                        exe "normal! 3h3xr_a_"
                        let @@ = save_unnamed_reg
                        return
                    else
                        if j == len(s)
                            exe "normal! 1x"
                            let @@ = save_unnamed_reg
                        else
                            exe "normal! 1xi <- "
                            let @@ = save_unnamed_reg
                            return
                        endif
                    endif
                endif
            endif
        endif
    endif
    if isString
        exe "normal! a" . g:R_assign_map
    else
        exe "normal! a <- "
    endif
endfunction

" Get the word either under or after the cursor.
" Works for word(| where | is the cursor position.
function RGetKeyword(...)
    " Go back some columns if character under cursor is not valid
    if a:0 == 2
        let line = getline(a:1)
        let i = a:2
    else
        let line = getline(".")
        let i = col(".") - 1
    endif
    if strlen(line) == 0
        return ""
    endif
    " line index starts in 0; cursor index starts in 1:
    " Skip opening braces
    while i > 0 && line[i] =~ '(\|\[\|{'
        let i -= 1
    endwhile
    " Go to the beginning of the word
    " See https://en.wikipedia.org/wiki/UTF-8#Codepage_layout
    while i > 0 && line[i-1] =~ '\k\|@\|\$\|\:\|_\|\.' || (line[i-1] > "\x80" && line[i-1] < "\xf5")
        let i -= 1
    endwhile
    " Go to the end of the word
    let j = i
    while line[j] =~ '\k\|@\|\$\|\:\|_\|\.' || (line[j] > "\x80" && line[j] < "\xf5")
        let j += 1
    endwhile
    let rkeyword = strpart(line, i, j - i)
    return rkeyword
endfunction

" Get the name of the first object after the opening parenthesis. Useful to
" call a specific print, summary, ..., method instead of the generic one.
function RGetFirstObj(rkeyword, ...)
    let firstobj = ""
    if a:0 == 3
        let line = substitute(a:1, '#.*', '', "")
        let begin = a:2
        let listdf = a:3
    else
        let line = substitute(getline("."), '#.*', '', "")
        let begin = col(".")
        let listdf = v:false
    endif
    if strlen(line) > begin
        let piece = strpart(line, begin)
        while piece !~ '^' . a:rkeyword && begin >= 0
            let begin -= 1
            let piece = strpart(line, begin)
        endwhile

        " check if the first argument is being passed through a pipe operator
        if begin > 2
            let part1 = strpart(line, 0, begin)
            if part1 =~ '\k\+\s*\(|>\|%>%\)'
                let pipeobj = substitute(part1, '.\{-}\(\k\+\)\s*\(|>\|%>%\)\s*', '\1', '')
                return [pipeobj, v:true]
            endif
        endif
        let pline = substitute(getline(line('.') - 1), '#.*$', '', '')
        if pline =~ '\k\+\s*\(|>\|%>%\)\s*$'
            let pipeobj = substitute(pline, '.\{-}\(\k\+\)\s*\(|>\|%>%\)\s*$', '\1', '')
            return [pipeobj, v:true]
        endif

        let line = piece
        if line !~ '^\k*\s*('
            return [firstobj, v:false]
        endif
        let begin = 1
        let linelen = strlen(line)
        while line[begin] != '(' && begin < linelen
            let begin += 1
        endwhile
        let begin += 1
        let line = strpart(line, begin)
        let line = substitute(line, '^\s*', '', "")
        if (line =~ '^\k*\s*(' || line =~ '^\k*\s*=\s*\k*\s*(') && line !~ '[.*('
            let idx = 0
            while line[idx] != '('
                let idx += 1
            endwhile
            let idx += 1
            let nparen = 1
            let len = strlen(line)
            let lnum = line(".")
            while nparen != 0
                if idx == len
                    let lnum += 1
                    while lnum <= line("$") && strlen(substitute(getline(lnum), '#.*', '', "")) == 0
                        let lnum += 1
                    endwhile
                    if lnum > line("$")
                        return ["", v:false]
                    endif
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
                if line[idx] == '('
                    let nparen += 1
                else
                    if line[idx] == ')'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
            endwhile
            let firstobj = strpart(line, 0, idx)
        elseif line =~ '^\(\k\|\$\)*\s*[' || line =~ '^\(k\|\$\)*\s*=\s*\(\k\|\$\)*\s*[.*('
            let idx = 0
            while line[idx] != '['
                let idx += 1
            endwhile
            let idx += 1
            let nparen = 1
            let len = strlen(line)
            let lnum = line(".")
            while nparen != 0
                if idx == len
                    let lnum += 1
                    while lnum <= line("$") && strlen(substitute(getline(lnum), '#.*', '', "")) == 0
                        let lnum += 1
                    endwhile
                    if lnum > line("$")
                        return ["", v:false]
                    endif
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
                if line[idx] == '['
                    let nparen += 1
                else
                    if line[idx] == ']'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
            endwhile
            let firstobj = strpart(line, 0, idx)
        else
            let firstobj = substitute(line, ').*', '', "")
            let firstobj = substitute(firstobj, ',.*', '', "")
            let firstobj = substitute(firstobj, ' .*', '', "")
        endif
    endif

    if firstobj =~ "="
        let firstobj = ""
    endif

    if firstobj[0] == '"' || firstobj[0] == "'"
        let firstobj = "#c#"
    elseif firstobj[0] >= "0" && firstobj[0] <= "9"
        let firstobj = "#n#"
    endif


    if firstobj =~ '"'
        let firstobj = substitute(firstobj, '"', '\\"', "g")
    endif

    return [firstobj, v:false]
endfunction

function ROpenPDF(fullpath)
    if g:R_openpdf == 0
        return
    endif

    if a:fullpath == "Get Master"
        let fpath = SyncTeX_GetMaster() . ".pdf"
        let fpath = b:rplugin_pdfdir . "/" . substitute(fpath, ".*/", "", "")
        call ROpenPDF(fpath)
        return
    endif

    if b:pdf_is_open == 0
        if g:R_openpdf == 1
            let b:pdf_is_open = 1
        endif
        call ROpenPDF2(a:fullpath)
    endif
endfunction

" For each noremap we need a vnoremap including <Esc> before the :call,
" otherwise nvim will call the function as many times as the number of selected
" lines. If we put <Esc> in the noremap, nvim will bell.
" RCreateMaps Args:
"   type : modes to which create maps (normal, visual and insert) and whether
"          the cursor have to go the beginning of the line
"   plug : the <Plug>Name
"   combo: combination of letters that make the shortcut
"   target: the command or function to be called
function RCreateMaps(type, plug, combo, target)
    if index(g:R_disable_cmds, a:plug) > -1
        return
    endif
    if a:type =~ '0'
        let tg = a:target . '<CR>0'
        let il = 'i'
    elseif a:type =~ '\.'
        let tg = a:target
        let il = 'a'
    else
        let tg = a:target . '<CR>'
        let il = 'a'
    endif
    if a:type =~ "n"
        exec 'noremap <buffer><silent> <Plug>' . a:plug . ' ' . tg
        if g:R_user_maps_only != 1 && !hasmapto('<Plug>' . a:plug, "n")
            exec 'noremap <buffer><silent> <LocalLeader>' . a:combo . ' ' . tg
        endif
    endif
    if a:type =~ "v"
        exec 'vnoremap <buffer><silent> <Plug>' . a:plug . ' <Esc>' . tg
        if g:R_user_maps_only != 1 && !hasmapto('<Plug>' . a:plug, "v")
            exec 'vnoremap <buffer><silent> <LocalLeader>' . a:combo . ' <Esc>' . tg
        endif
    endif
    if g:R_insert_mode_cmds == 1 && a:type =~ "i"
        exec 'inoremap <buffer><silent> <Plug>' . a:plug . ' <Esc>' . tg . il
        if g:R_user_maps_only != 1 && !hasmapto('<Plug>' . a:plug, "i")
            exec 'inoremap <buffer><silent> <LocalLeader>' . a:combo . ' <Esc>' . tg . il
        endif
    endif
endfunction

function RControlMaps()
    " List space, clear console, clear all
    "-------------------------------------
    call RCreateMaps('nvi', 'RListSpace',    'rl', ':call g:SendCmdToR("ls()")')
    call RCreateMaps('nvi', 'RClearConsole', 'rr', ':call RClearConsole()')
    call RCreateMaps('nvi', 'RClearAll',     'rm', ':call RClearAll()')

    " Print, names, structure
    "-------------------------------------
    call RCreateMaps('ni', 'RObjectPr',    'rp', ':call RAction("print")')
    call RCreateMaps('ni', 'RObjectNames', 'rn', ':call RAction("nvim.names")')
    call RCreateMaps('ni', 'RObjectStr',   'rt', ':call RAction("str")')
    call RCreateMaps('ni', 'RViewDF',      'rv', ':call RAction("viewobj")')
    call RCreateMaps('ni', 'RViewDFs',     'vs', ':call RAction("viewobj", ", howto=''split''")')
    call RCreateMaps('ni', 'RViewDFv',     'vv', ':call RAction("viewobj", ", howto=''vsplit''")')
    call RCreateMaps('ni', 'RViewDFa',     'vh', ':call RAction("viewobj", ", howto=''above 7split'', nrows=6")')
    call RCreateMaps('ni', 'RDputObj',     'td', ':call RAction("dputtab")')

    call RCreateMaps('v', 'RObjectPr',     'rp', ':call RAction("print", "v")')
    call RCreateMaps('v', 'RObjectNames',  'rn', ':call RAction("nvim.names", "v")')
    call RCreateMaps('v', 'RObjectStr',    'rt', ':call RAction("str", "v")')
    call RCreateMaps('v', 'RViewDF',       'rv', ':call RAction("viewobj", "v")')
    call RCreateMaps('v', 'RViewDFs',      'vs', ':call RAction("viewobj", "v", ", howto=''split''")')
    call RCreateMaps('v', 'RViewDFv',      'vv', ':call RAction("viewobj", "v", ", howto=''vsplit''")')
    call RCreateMaps('v', 'RViewDFa',      'vh', ':call RAction("viewobj", "v", ", howto=''above 7split'', nrows=6")')
    call RCreateMaps('v', 'RDputObj',      'td', ':call RAction("dputtab", "v")')

    " Arguments, example, help
    "-------------------------------------
    call RCreateMaps('nvi', 'RShowArgs',   'ra', ':call RAction("args")')
    call RCreateMaps('nvi', 'RShowEx',     're', ':call RAction("example")')
    call RCreateMaps('nvi', 'RHelp',       'rh', ':call RAction("help")')

    " Summary, plot, both
    "-------------------------------------
    call RCreateMaps('ni', 'RSummary',     'rs', ':call RAction("summary")')
    call RCreateMaps('ni', 'RPlot',        'rg', ':call RAction("plot")')
    call RCreateMaps('ni', 'RSPlot',       'rb', ':call RAction("plotsumm")')

    call RCreateMaps('v', 'RSummary',      'rs', ':call RAction("summary", "v")')
    call RCreateMaps('v', 'RPlot',         'rg', ':call RAction("plot", "v")')
    call RCreateMaps('v', 'RSPlot',        'rb', ':call RAction("plotsumm", "v")')

    " Build list of objects for omni completion
    "-------------------------------------
    call RCreateMaps('nvi', 'RUpdateObjBrowser', 'ro', ':call RObjBrowser()')
    call RCreateMaps('nvi', 'ROpenLists',        'r=', ':call RBrOpenCloseLs("O")')
    call RCreateMaps('nvi', 'RCloseLists',       'r-', ':call RBrOpenCloseLs("C")')

    " Render script with rmarkdown
    "-------------------------------------
    call RCreateMaps('nvi', 'RMakeRmd',    'kr', ':call RMakeRmd("default")')
    call RCreateMaps('nvi', 'RMakeAll',    'ka', ':call RMakeRmd("all")')
    if &filetype == "quarto"
        call RCreateMaps('nvi', 'RMakePDFK',   'kp', ':call RMakeRmd("pdf")')
        call RCreateMaps('nvi', 'RMakePDFKb',  'kl', ':call RMakeRmd("beamer")')
        call RCreateMaps('nvi', 'RMakeWord',   'kw', ':call RMakeRmd("docx")')
        call RCreateMaps('nvi', 'RMakeHTML',   'kh', ':call RMakeRmd("html")')
        call RCreateMaps('nvi', 'RMakeODT',    'ko', ':call RMakeRmd("odt")')
    else
        call RCreateMaps('nvi', 'RMakePDFK',   'kp', ':call RMakeRmd("pdf_document")')
        call RCreateMaps('nvi', 'RMakePDFKb',  'kl', ':call RMakeRmd("beamer_presentation")')
        call RCreateMaps('nvi', 'RMakeWord',   'kw', ':call RMakeRmd("word_document")')
        call RCreateMaps('nvi', 'RMakeHTML',   'kh', ':call RMakeRmd("html_document")')
        call RCreateMaps('nvi', 'RMakeODT',    'ko', ':call RMakeRmd("odt_document")')
    endif
endfunction

function RCreateStartMaps()
    " Start
    "-------------------------------------
    call RCreateMaps('nvi', 'RStart',       'rf', ':call StartR("R")')
    call RCreateMaps('nvi', 'RCustomStart', 'rc', ':call StartR("custom")')

    " Close
    "-------------------------------------
    call RCreateMaps('nvi', 'RClose',       'rq', ":call RQuit('nosave')")
    call RCreateMaps('nvi', 'RSaveClose',   'rw', ":call RQuit('save')")

endfunction

function RCreateEditMaps()
    " Edit
    "-------------------------------------
    if g:R_enable_comment
        call RCreateCommentMaps()
    endif
    " Replace 'underline' with '<-'
    if g:R_assign == 1 || g:R_assign == 2
        silent exe 'inoremap <buffer><silent> ' . g:R_assign_map . ' <Esc>:call ReplaceUnderS()<CR>a'
    endif
endfunction

function RCreateSendMaps()
    " Block
    "-------------------------------------
    call RCreateMaps('ni', 'RSendMBlock',     'bb', ':call SendMBlockToR("silent", "stay")')
    call RCreateMaps('ni', 'RESendMBlock',    'be', ':call SendMBlockToR("echo", "stay")')
    call RCreateMaps('ni', 'RDSendMBlock',    'bd', ':call SendMBlockToR("silent", "down")')
    call RCreateMaps('ni', 'REDSendMBlock',   'ba', ':call SendMBlockToR("echo", "down")')

    " Function
    "-------------------------------------
    call RCreateMaps('nvi', 'RSendFunction',  'ff', ':call SendFunctionToR("silent", "stay")')
    call RCreateMaps('nvi', 'RDSendFunction', 'fe', ':call SendFunctionToR("echo", "stay")')
    call RCreateMaps('nvi', 'RDSendFunction', 'fd', ':call SendFunctionToR("silent", "down")')
    call RCreateMaps('nvi', 'RDSendFunction', 'fa', ':call SendFunctionToR("echo", "down")')

    " Selection
    "-------------------------------------
    call RCreateMaps('n', 'RSendSelection',   'ss', ':call SendSelectionToR("silent", "stay", "normal")')
    call RCreateMaps('n', 'RESendSelection',  'se', ':call SendSelectionToR("echo", "stay", "normal")')
    call RCreateMaps('n', 'RDSendSelection',  'sd', ':call SendSelectionToR("silent", "down", "normal")')
    call RCreateMaps('n', 'REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down", "normal")')

    call RCreateMaps('v', 'RSendSelection',   'ss', ':call SendSelectionToR("silent", "stay")')
    call RCreateMaps('v', 'RESendSelection',  'se', ':call SendSelectionToR("echo", "stay")')
    call RCreateMaps('v', 'RDSendSelection',  'sd', ':call SendSelectionToR("silent", "down")')
    call RCreateMaps('v', 'REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down")')
    call RCreateMaps('v', 'RSendSelAndInsertOutput', 'so', ':call SendSelectionToR("echo", "stay", "NewtabInsert")')

    " Paragraph
    "-------------------------------------
    call RCreateMaps('ni', 'RSendParagraph',   'pp', ':call SendParagraphToR("silent", "stay")')
    call RCreateMaps('ni', 'RESendParagraph',  'pe', ':call SendParagraphToR("echo", "stay")')
    call RCreateMaps('ni', 'RDSendParagraph',  'pd', ':call SendParagraphToR("silent", "down")')
    call RCreateMaps('ni', 'REDSendParagraph', 'pa', ':call SendParagraphToR("echo", "down")')

    if &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "quarto" || &filetype == "rrst"
        call RCreateMaps('ni', 'RSendChunkFH', 'ch', ':call SendFHChunkToR()')
    endif

    " *Line*
    "-------------------------------------
    call RCreateMaps('ni',  'RSendLine', 'l', ':call SendLineToR("stay")')
    call RCreateMaps('ni0', 'RDSendLine', 'd', ':call SendLineToR("down")')
    call RCreateMaps('ni0', '(RDSendLineAndInsertOutput)', 'o', ':call SendLineToRAndInsertOutput()')
    call RCreateMaps('v',   '(RDSendLineAndInsertOutput)', 'o', ':call RWarningMsg("This command does not work over a selection of lines.")')
    call RCreateMaps('i',   'RSendLAndOpenNewOne', 'q', ':call SendLineToR("newline")')
    call RCreateMaps('ni.', 'RSendMotion', 'm', ':set opfunc=SendMotionToR<CR>g@')
    call RCreateMaps('n',   'RNLeftPart', 'r<left>', ':call RSendPartOfLine("left", 0)')
    call RCreateMaps('n',   'RNRightPart', 'r<right>', ':call RSendPartOfLine("right", 0)')
    call RCreateMaps('i',   'RILeftPart', 'r<left>', 'l:call RSendPartOfLine("left", 1)')
    call RCreateMaps('i',   'RIRightPart', 'r<right>', 'l:call RSendPartOfLine("right", 1)')
    if &filetype == "r"
        call RCreateMaps('n', 'RSendAboveLines',  'su', ':call SendAboveLinesToR()')
    endif

    " Debug
    call RCreateMaps('n',   'RDebug', 'bg', ':call RAction("debug")')
    call RCreateMaps('n',   'RUndebug', 'ud', ':call RAction("undebug")')
endfunction

function RBufEnter()
    let g:rplugin.curbuf = bufname("%")
    if has("gui_running")
        if &filetype != g:rplugin.lastft
            call UnMakeRMenu()
            if &filetype == "r" || &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "quarto" || &filetype == "rrst" || &filetype == "rdoc" || &filetype == "rbrowser" || &filetype == "rhelp"
                if &filetype == "rbrowser"
                    call MakeRBrowserMenu()
                else
                    call MakeRMenu()
                endif
            endif
        endif
        if &buftype != "nofile" || (&buftype == "nofile" && &filetype == "rbrowser")
            let g:rplugin.lastft = &filetype
        endif
    endif
    if &filetype == "r" || &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "quarto" || &filetype == "rrst" || &filetype == "rhelp"
        let g:rplugin.rscript_name = bufname("%")
    endif
endfunction

" Store list of files to be deleted on VimLeave
function AddForDeletion(fname)
    for fn in g:rplugin.del_list
        if fn == a:fname
            return
        endif
    endfor
    call add(g:rplugin.del_list, a:fname)
endfunction

function RVimLeave()
    if has('nvim')
        for job in keys(g:rplugin.jobs)
            if IsJobRunning(job)
                if job == 'Server' || job == 'BibComplete'
                    " Avoid warning of exit status 141
                    call JobStdin(g:rplugin.jobs[job], "9\n")
                    sleep 20m
                endif
            endif
        endfor
    endif

    for fn in g:rplugin.del_list
        call delete(fn)
    endfor
    if executable("rmdir")
        if has('nvim')
            call jobstart("rmdir '" . g:rplugin.tmpdir . "'", {'detach': v:true})
        else
            call system("rmdir '" . g:rplugin.tmpdir . "'")
        endif
        if g:rplugin.localtmpdir != g:rplugin.tmpdir
            if has('nvim')
                call jobstart("rmdir '" . g:rplugin.localtmpdir . "'", {'detach': v:true})
            else
                call system("rmdir '" . g:rplugin.localtmpdir . "'")
            endif
        endif
    endif
endfunction

function RSourceOtherScripts()
    if exists("g:R_source")
        let flist = split(g:R_source, ",")
        for fl in flist
            if fl =~ " "
                call RWarningMsg("Invalid file name (empty spaces are not allowed): '" . fl . "'")
            else
                exe "source " . escape(fl, ' \')
            endif
        endfor
    endif

    if (g:R_auto_start == 1 && v:vim_did_enter == 0) || g:R_auto_start == 2
        call timer_start(200, 'AutoStartR')
    endif
endfunction

function ShowRDebugInfo()
    for key in keys(g:rplugin.debug_info)
        if len(g:rplugin.debug_info[key]) == 0
            continue
        endif
        echohl Title
        echo key
        echohl None
        if key == 'Time' || key == 'nvimcom_info'
            for step in keys(g:rplugin.debug_info[key])
                echohl Identifier
                echo '  ' . step . ': '
                if key == 'Time'
                    echohl Number
                else
                    echohl String
                endif
                echon g:rplugin.debug_info[key][step]
                echohl None
            endfor
            echo ""
        else
            echo g:rplugin.debug_info[key]
        endif
        echo ""
    endfor
endfunction

" Function to send commands
" return 0 on failure and 1 on success
function SendCmdToR_fake(...)
    call RWarningMsg("Did you already start R?")
    return 0
endfunction

function AutoStartR(...)
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        return
    endif
    if v:vim_did_enter == 0 || g:rplugin.nrs_running == 0
        call timer_start(100, 'AutoStartR')
        return
    endif
    call StartR("R")
endfunction

command -nargs=1 -complete=customlist,RLisObjs Rinsert :call RInsert(<q-args>, "here")
command -range=% Rformat <line1>,<line2>:call RFormatCode()
command RBuildTags :call RBuildTags()
command -nargs=? -complete=customlist,RLisObjs Rhelp :call RAskHelp(<q-args>)
command -nargs=? -complete=dir RSourceDir :call RSourceDirectory(<q-args>)
command RStop :call SignalToR('SIGINT')
command RKill :call SignalToR('SIGKILL')
command -nargs=? RSend :call g:SendCmdToR(<q-args>)
command RDebugInfo :call ShowRDebugInfo()

"==============================================================================
" Temporary links to be deleted when start_r.vim is sourced

function RNotRunning(...)
    echohl WarningMsg
    echon "R is not running"
    echohl None
endfunction

let g:RAction = function('RNotRunning')
let g:RAskHelp = function('RNotRunning')
let g:RBrOpenCloseLs = function('RNotRunning')
let g:RBuildTags = function('RNotRunning')
let g:RClearAll = function('RNotRunning')
let g:RClearConsole = function('RNotRunning')
let g:RFormatCode = function('RNotRunning')
let g:RInsert = function('RNotRunning')
let g:RMakeRmd = function('RNotRunning')
let g:RObjBrowser = function('RNotRunning')
let g:RQuit = function('RNotRunning')
let g:RSendPartOfLine = function('RNotRunning')
let g:RSourceDirectory = function('RNotRunning')
let g:SendCmdToR = function('SendCmdToR_fake')
let g:SendFileToR = function('SendCmdToR_fake')
let g:SendFunctionToR = function('RNotRunning')
let g:SendLineToR = function('RNotRunning')
let g:SendLineToRAndInsertOutput = function('RNotRunning')
let g:SendMBlockToR = function('RNotRunning')
let g:SendParagraphToR = function('RNotRunning')
let g:SendSelectionToR = function('RNotRunning')
let g:SignalToR = function('RNotRunning')


"==============================================================================
" Global variables
" Convention: R_        for user options
"             rplugin_  for internal parameters
"==============================================================================

if !has_key(g:rplugin, "compldir")
    exe "source " . substitute(expand("<sfile>:h:h"), " ", "\\ ", "g") . "/R/setcompldir.vim"
endif

if exists("g:R_tmpdir")
    let g:rplugin.tmpdir = expand(g:R_tmpdir)
else
    if has("win32")
        if isdirectory($TMP)
            let g:rplugin.tmpdir = $TMP . "/NvimR-" . g:rplugin.userlogin
        elseif isdirectory($TEMP)
            let g:rplugin.tmpdir = $TEMP . "/Nvim-R-" . g:rplugin.userlogin
        else
            let g:rplugin.tmpdir = g:rplugin.uservimfiles . "/R/tmp"
        endif
        let g:rplugin.tmpdir = substitute(g:rplugin.tmpdir, "\\", "/", "g")
    else
        if isdirectory($TMPDIR)
            if $TMPDIR =~ "/$"
                let g:rplugin.tmpdir = $TMPDIR . "Nvim-R-" . g:rplugin.userlogin
            else
                let g:rplugin.tmpdir = $TMPDIR . "/Nvim-R-" . g:rplugin.userlogin
            endif
        elseif isdirectory("/dev/shm")
            let g:rplugin.tmpdir = "/dev/shm/Nvim-R-" . g:rplugin.userlogin
        elseif isdirectory("/tmp")
            let g:rplugin.tmpdir = "/tmp/Nvim-R-" . g:rplugin.userlogin
        else
            let g:rplugin.tmpdir = g:rplugin.uservimfiles . "/R/tmp"
        endif
    endif
endif

" When accessing R remotely, a local tmp directory is used by the
" nvimrserver to save the contents of the ObjectBrowser to avoid traffic
" over the ssh connection
let g:rplugin.localtmpdir = g:rplugin.tmpdir

if exists("g:R_remote_compldir")
    let $NVIMR_REMOTE_COMPLDIR = g:R_remote_compldir
    let $NVIMR_REMOTE_TMPDIR = g:R_remote_compldir . '/tmp'
    let g:rplugin.tmpdir = g:R_compldir . '/tmp'
    if !isdirectory(g:rplugin.tmpdir)
        call mkdir(g:rplugin.tmpdir, "p", 0700)
    endif
else
    let $NVIMR_REMOTE_COMPLDIR = g:rplugin.compldir
    let $NVIMR_REMOTE_TMPDIR = g:rplugin.tmpdir
endif
if !isdirectory(g:rplugin.localtmpdir)
    call mkdir(g:rplugin.localtmpdir, "p", 0700)
endif
let $NVIMR_TMPDIR = g:rplugin.tmpdir

" Delete options with invalid values
if exists("g:R_set_omnifunc") && type(g:R_set_omnifunc) != v:t_list
    call RWarningMsg('"R_set_omnifunc" must be a list')
    unlet g:R_set_omnifunc
endif

" Default values of some variables

let g:R_assign            = get(g:, "R_assign",             1)
if type(g:R_assign) == v:t_number && g:R_assign == 2
    let g:R_assign_map = '_'
endif
let g:R_assign_map        = get(g:, "R_assign_map",       "_")

let g:R_synctex           = get(g:, "R_synctex",            1)
let g:R_non_r_compl       = get(g:, "R_non_r_compl",        1)
let g:R_nvim_wd           = get(g:, "R_nvim_wd",            0)
let g:R_auto_start        = get(g:, "R_auto_start",         0)
let g:R_routnotab         = get(g:, "R_routnotab",          0)
let g:R_objbr_w           = get(g:, "R_objbr_w",           40)
let g:R_objbr_h           = get(g:, "R_objbr_h",           10)
let g:R_objbr_opendf      = get(g:, "R_objbr_opendf",       1)
let g:R_objbr_openlist    = get(g:, "R_objbr_openlist",     0)
let g:R_objbr_allnames    = get(g:, "R_objbr_allnames",     0)
let g:R_applescript       = get(g:, "R_applescript",        0)
let g:R_never_unmake_menu = get(g:, "R_never_unmake_menu",  0)
let g:R_insert_mode_cmds  = get(g:, "R_insert_mode_cmds",   0)
let g:R_disable_cmds      = get(g:, "R_disable_cmds",    [''])
let g:R_enable_comment    = get(g:, "R_enable_comment",     0)
let g:R_openhtml          = get(g:, "R_openhtml",           1)
let g:R_hi_fun_paren      = get(g:, "R_hi_fun_paren",       0)
let g:R_bib_compl         = get(g:, "R_bib_compl", ["rnoweb"])

if type(g:R_bib_compl) == v:t_string
    let g:R_bib_compl = [g:R_bib_compl]
endif

let g:R_fun_data_1 = get(g:, 'R_fun_data_1', ['select', 'rename', 'mutate', 'filter'])
let g:R_fun_data_2 = get(g:, 'R_fun_data_2', {'ggplot': ['aes'], 'with': ['*']})

if exists(":terminal") != 2
    let g:R_external_term = get(g:, "R_external_term", 1)
endif
if !has("nvim") && !exists("*term_start")
    " exists(':terminal') return 2 even when Vim does not have the +terminal feature
    let g:R_external_term = get(g:, "R_external_term", 1)
endif
let g:R_external_term = get(g:, "R_external_term", 0)

let s:editing_mode = "emacs"
if filereadable(expand("~/.inputrc"))
    let s:inputrc = readfile(expand("~/.inputrc"))
    call map(s:inputrc, 'substitute(v:val, "^\s*#.*", "", "")')
    call filter(s:inputrc, 'v:val =~ "set.*editing-mode"')
    if len(s:inputrc) && s:inputrc[len(s:inputrc) - 1] =~ '^\s*set\s*editing-mode\s*vi\>'
        let s:editing_mode = "vi"
    endif
    unlet s:inputrc
endif
let g:R_editing_mode = get(g:, "R_editing_mode", s:editing_mode)
unlet s:editing_mode

if has('win32') && !(type(g:R_external_term) == v:t_number && g:R_external_term == 0)
    " Sending multiple lines at once to Rgui on Windows does not work.
    let g:R_parenblock = get(g:, 'R_parenblock',         0)
else
    let g:R_parenblock = get(g:, 'R_parenblock',         1)
endif

if type(g:R_external_term) == v:t_number && g:R_external_term == 0
    let g:R_nvimpager = get(g:, 'R_nvimpager', 'vertical')
else
    let g:R_nvimpager = get(g:, 'R_nvimpager', 'tab')
endif

let g:R_objbr_place      = get(g:, "R_objbr_place",    "script,right")
let g:R_source_args      = get(g:, "R_source_args",                "")
let g:R_user_maps_only   = get(g:, "R_user_maps_only",              0)
let g:R_latexcmd         = get(g:, "R_latexcmd",          ["default"])
let g:R_texerr           = get(g:, "R_texerr",                      1)
let g:R_rmd_environment  = get(g:, "R_rmd_environment",  ".GlobalEnv")
let g:R_rmarkdown_args   = get(g:, "R_rmarkdown_args",             "")

if type(g:R_external_term) == v:t_number && g:R_external_term == 0
    let g:R_save_win_pos = 0
    let g:R_arrange_windows  = 0
endif
if has("win32")
    let g:R_save_win_pos    = get(g:, "R_save_win_pos",    1)
    let g:R_arrange_windows = get(g:, "R_arrange_windows", 1)
else
    let g:R_save_win_pos    = get(g:, "R_save_win_pos",    0)
    let g:R_arrange_windows = get(g:, "R_arrange_windows", 0)
endif

" The environment variables NVIMR_COMPLCB and NVIMR_COMPLInfo must be defined
" before starting the nvimrserver because it needs them at startup.
" The R_set_omnifunc must be defined before finalizing the source of common_buffer.vim.
let g:rplugin.update_glbenv = 0
if has('nvim') && type(luaeval("package.loaded['cmp_nvim_r']")) == v:t_dict
    let $NVIMR_COMPLCB = "v:lua.require'cmp_nvim_r'.asynccb"
    let $NVIMR_COMPLInfo = "v:lua.require'cmp_nvim_r'.complinfo"
    let g:R_set_omnifunc = []
    let g:rplugin.update_glbenv = 1
else
    let $NVIMR_COMPLCB = 'SetComplMenu'
    let $NVIMR_COMPLInfo = "SetComplInfo"
    let g:R_set_omnifunc = get(g:, "R_set_omnifunc", ["r",  "rmd", "quarto", "rnoweb", "rhelp", "rrst"])
endif

if len(g:R_set_omnifunc) > 0
    let g:rplugin.update_glbenv = 1
endif

" Look for invalid options

let objbrplace = split(g:R_objbr_place, ',')
if len(objbrplace) > 2
    call RWarningMsg('Too many options for R_objbr_place.')
    let g:rplugin.failed = 1
    finish
endif
for pos in objbrplace
    if pos !=? 'console' && pos !=? 'script' &&
                \ pos !=# 'left' && pos !=# 'right' &&
                \ pos !=# 'LEFT' && pos !=# 'RIGHT' &&
                \ pos !=# 'above' && pos !=# 'below' &&
                \ pos !=# 'TOP' && pos !=# 'BOTTOM'
        call RWarningMsg('Invalid value for R_objbr_place: "' . pos . ". Please see Nvim-R's documentation.")
        let g:rplugin.failed = 1
        finish
    endif
endfor
unlet pos
unlet objbrplace

"==============================================================================
" Check if default mean of communication with R is OK
"==============================================================================

" Minimum width for the Object Browser
if g:R_objbr_w < 10
    let g:R_objbr_w = 10
endif

" Minimum height for the Object Browser
if g:R_objbr_h < 4
    let g:R_objbr_h = 4
endif

" Control the menu 'R' and the tool bar buttons
if !has_key(g:rplugin, "hasmenu")
    let g:rplugin.hasmenu = 0
endif

autocmd BufEnter * call RBufEnter()
if &filetype != "rbrowser"
    autocmd VimLeave * call RVimLeave()
endif

if v:windowid != 0 && $WINDOWID == ""
    let $WINDOWID = v:windowid
endif

" Current view of the object browser: .GlobalEnv X loaded libraries
let g:rplugin.curview = "None"

if has("nvim")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/nvimrcom.vim"
else
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/vimrcom.vim"
endif

" SyncTeX options
let g:rplugin.has_wmctrl = 0

" Initial List of files to be deleted on VimLeave
let g:rplugin.del_list = [
            \ g:rplugin.tmpdir . '/run_R_stdout',
            \ g:rplugin.tmpdir . '/run_R_stderr']

" Set the name of R executable
if exists("g:R_app")
    let g:rplugin.R = g:R_app
    if !has("win32") && !exists("g:R_cmd")
        let g:R_cmd = g:R_app
    endif
else
    if has("win32")
        if type(g:R_external_term) == v:t_number && g:R_external_term == 0
            let g:rplugin.R = "Rterm.exe"
        else
            let g:rplugin.R = "Rgui.exe"
        endif
    else
        let g:rplugin.R = "R"
    endif
endif

" Set the name of R executable to be used in `R CMD`
if exists("g:R_cmd")
    let g:rplugin.Rcmd = g:R_cmd
else
    let g:rplugin.Rcmd = "R"
endif

if exists("g:RStudio_cmd")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/rstudio.vim"
endif

if has("win32")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/windows.vim"
else
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/unix.vim"
endif

if g:R_applescript
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/osx.vim"
endif

if type(g:R_external_term) == v:t_number && g:R_external_term == 0
    if has("nvim")
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/nvimbuffer.vim"
    else
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/vimbuffer.vim"
    endif
endif

if g:R_enable_comment
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/comment.vim"
endif

if has("gui_running")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/gui_running.vim"
endif

autocmd FuncUndefined StartR exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/start_r.vim"

function GlobalRInit(...)
    let g:rplugin.debug_info['Time']['GlobalRInit'] = reltime()
    exe 'source ' . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/start_nrs.vim"
    " Set security variables
    if has('nvim') && !has("nvim-0.7.0")
        let $NVIMR_ID = substitute(string(reltimefloat(reltime())), '.*\.', '', '')
        let $NVIMR_SECRET = substitute(string(reltimefloat(reltime())), '.*\.', '', '')
    else
        let $NVIMR_ID = rand(srand())
        let $NVIMR_SECRET = rand()
    end
    call CheckNvimcomVersion()
    let g:rplugin.debug_info['Time']['GlobalRInit'] = reltimefloat(reltime(g:rplugin.debug_info['Time']['GlobalRInit'], reltime()))
endfunction

if v:vim_did_enter == 0
    autocmd VimEnter * call timer_start(1, "GlobalRInit")
else
    call timer_start(1, "GlobalRInit")
endif
let g:rplugin.debug_info['Time']['common_global.vim'] = reltimefloat(reltime(g:rplugin.debug_info['Time']['common_global.vim'], reltime()))
