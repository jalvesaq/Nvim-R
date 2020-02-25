" This file contains code used only if has("gui_running")

if exists("g:did_nvimr_gui_running")
    finish
endif
let g:did_nvimr_gui_running = 1

if exists('g:maplocalleader')
    let s:tll = '<Tab>' . g:maplocalleader
else
    let s:tll = '<Tab>\\'
endif

let s:ikblist = execute("imap")
let s:nkblist = execute("nmap")
let s:vkblist = execute("vmap")
let s:iskblist = split(s:ikblist, "\n")
let s:nskblist = split(s:nkblist, "\n")
let s:vskblist = split(s:vkblist, "\n")
let s:imaplist = []
let s:vmaplist = []
let s:nmaplist = []
for i in s:iskblist
    let si = split(i)
    if len(si) == 3 && si[2] =~ "<Plug>R"
        call add(s:imaplist, [si[1], si[2]])
    endif
endfor
for i in s:nskblist
    let si = split(i)
    if len(si) == 3 && si[2] =~ "<Plug>R"
        call add(s:nmaplist, [si[1], si[2]])
    endif
endfor
for i in s:vskblist
    let si = split(i)
    if len(si) == 3 && si[2] =~ "<Plug>R"
        call add(s:vmaplist, [si[1], si[2]])
    endif
endfor
unlet s:ikblist
unlet s:nkblist
unlet s:vkblist
unlet s:iskblist
unlet s:nskblist
unlet s:vskblist
unlet i
unlet si

function RNMapCmd(plug)
    for [el1, el2] in s:nmaplist
        if el2 == a:plug
            return el1
        endif
    endfor
endfunction

function RIMapCmd(plug)
    for [el1, el2] in s:imaplist
        if el2 == a:plug
            return el1
        endif
    endfor
endfunction

function RVMapCmd(plug)
    for [el1, el2] in s:vmaplist
        if el2 == a:plug
            return el1
        endif
    endfor
endfunction

function RCreateMenuItem(type, label, plug, combo, target)
    if index(g:R_disable_cmds, a:plug) > -1
        return
    endif
    if a:type =~ '0'
        let tg = a:target . '<CR>0'
        let il = 'i'
    else
        let tg = a:target . '<CR>'
        let il = 'a'
    endif
    if a:type =~ "n"
        if hasmapto('<Plug>' . a:plug, "n")
            let boundkey = RNMapCmd('<Plug>' . a:plug)
            exec 'nmenu <silent> &R.' . a:label . '<Tab>' . boundkey . ' ' . tg
        else
            exec 'nmenu <silent> &R.' . a:label . s:tll . a:combo . ' ' . tg
        endif
    endif
    if a:type =~ "v"
        if hasmapto('<Plug>' . a:plug, "v")
            let boundkey = RVMapCmd('<Plug>' . a:plug)
            exec 'vmenu <silent> &R.' . a:label . '<Tab>' . boundkey . ' ' . '<Esc>' . tg
        else
            exec 'vmenu <silent> &R.' . a:label . s:tll . a:combo . ' ' . '<Esc>' . tg
        endif
    endif
    if a:type =~ "i"
        if hasmapto('<Plug>' . a:plug, "i")
            let boundkey = RIMapCmd('<Plug>' . a:plug)
            exec 'imenu <silent> &R.' . a:label . '<Tab>' . boundkey . ' ' . '<Esc>' . tg . il
        else
            exec 'imenu <silent> &R.' . a:label . s:tll . a:combo . ' ' . '<Esc>' . tg . il
        endif
    endif
endfunction

function RBrowserMenu()
    call RCreateMenuItem('nvi', 'Object\ browser.Open/Close', 'RUpdateObjBrowser', 'ro', ':call RObjBrowser()')
    call RCreateMenuItem('nvi', 'Object\ browser.Expand\ (all\ lists)', 'ROpenLists', 'r=', ':call RBrOpenCloseLs(1)')
    call RCreateMenuItem('nvi', 'Object\ browser.Collapse\ (all\ lists)', 'RCloseLists', 'r-', ':call RBrOpenCloseLs(0)')
    if &filetype == "rbrowser"
        imenu <silent> R.Object\ browser.Toggle\ (cur)<Tab>Enter <Esc>:call RBrowserDoubleClick()<CR>
        nmenu <silent> R.Object\ browser.Toggle\ (cur)<Tab>Enter :call RBrowserDoubleClick()<CR>
    endif
    let g:rplugin.hasmenu = 1
endfunction

function RControlMenu()
    call RCreateMenuItem('nvi', 'Command.List\ space', 'RListSpace', 'rl', ':call g:SendCmdToR("ls()")')
    call RCreateMenuItem('nvi', 'Command.Clear\ console\ screen', 'RClearConsole', 'rr', ':call RClearConsole()')
    call RCreateMenuItem('nvi', 'Command.Clear\ all', 'RClearAll', 'rm', ':call RClearAll()')
    "-------------------------------
    menu R.Command.-Sep1- <nul>
    call RCreateMenuItem('nvi', 'Command.Print\ (cur)', 'RObjectPr', 'rp', ':call RAction("print")')
    call RCreateMenuItem('nvi', 'Command.Names\ (cur)', 'RObjectNames', 'rn', ':call RAction("nvim.names")')
    call RCreateMenuItem('nvi', 'Command.Structure\ (cur)', 'RObjectStr', 'rt', ':call RAction("str")')
    call RCreateMenuItem('nvi', 'Command.View\ data\.frame\ (cur)', 'RViewDF', 'rv', ':call RAction("viewdf")')
    call RCreateMenuItem('nvi', 'Command.View\ data\.frame\ (cur)\ in\ horizontal\ split', 'RViewDF', 'vs', ':call RAction("viewdf", ", location=''split''")')
    call RCreateMenuItem('nvi', 'Command.View\ data\.frame\ (cur)\ in\ vertical\ split', 'RViewDF', 'vv', ':call RAction("viewdf", ", location=''vsplit''")')
    call RCreateMenuItem('nvi', 'Command.View\ head(data\.frame)\ (cur)\ in\ horizontal\ split', 'RViewDF', 'vh', ':call RAction("viewdf", ", location=''above 7split'', nrows=6")')
    call RCreateMenuItem('nvi', 'Command.Run\ dput(cur)\ and\ show\ output\ in\ new\ tab', 'RDputObj', 'td', ':call RAction("dputtab")')
    "-------------------------------
    menu R.Command.-Sep2- <nul>
    call RCreateMenuItem('nvi', 'Command.Arguments\ (cur)', 'RShowArgs', 'ra', ':call RAction("args")')
    call RCreateMenuItem('nvi', 'Command.Example\ (cur)', 'RShowEx', 're', ':call RAction("example")')
    call RCreateMenuItem('nvi', 'Command.Help\ (cur)', 'RHelp', 'rh', ':call RAction("help")')
    "-------------------------------
    menu R.Command.-Sep3- <nul>
    call RCreateMenuItem('nvi', 'Command.Summary\ (cur)', 'RSummary', 'rs', ':call RAction("summary")')
    call RCreateMenuItem('nvi', 'Command.Plot\ (cur)', 'RPlot', 'rg', ':call RAction("plot")')
    call RCreateMenuItem('nvi', 'Command.Plot\ and\ summary\ (cur)', 'RSPlot', 'rb', ':call RAction("plotsumm")')
    let g:rplugin.hasmenu = 1
endfunction

function MakeRMenu()
    if g:rplugin.hasmenu == 1
        return
    endif

    " Do not translate "File":
    menutranslate clear

    "----------------------------------------------------------------------------
    " Start/Close
    "----------------------------------------------------------------------------
    call RCreateMenuItem('nvi', 'Start/Close.Start\ R\ (default)', 'RStart', 'rf', ':call StartR("R")')
    call RCreateMenuItem('nvi', 'Start/Close.Start\ R\ (custom)', 'RCustomStart', 'rc', ':call StartR("custom")')
    "-------------------------------
    menu R.Start/Close.-Sep1- <nul>
    call RCreateMenuItem('nvi', 'Start/Close.Close\ R\ (no\ save)', 'RClose', 'rq', ":call RQuit('no')")
    menu R.Start/Close.-Sep2- <nul>

    nmenu <silent> R.Start/Close.Stop\ R<Tab>:RStop :RStop<CR>

    "----------------------------------------------------------------------------
    " Send
    "----------------------------------------------------------------------------
    if &filetype == "r" || g:R_never_unmake_menu
        call RCreateMenuItem('ni', 'Send.File', 'RSendFile', 'aa', ':call SendFileToR("silent")')
        call RCreateMenuItem('ni', 'Send.File\ (echo)', 'RESendFile', 'ae', ':call SendFileToR("echo")')
        call RCreateMenuItem('ni', 'Send.File\ (open\ \.Rout)', 'RShowRout', 'ao', ':call ShowRout()')
    endif
    "-------------------------------
    menu R.Send.-Sep1- <nul>
    call RCreateMenuItem('ni', 'Send.Block\ (cur)', 'RSendMBlock', 'bb', ':call SendMBlockToR("silent", "stay")')
    call RCreateMenuItem('ni', 'Send.Block\ (cur,\ echo)', 'RESendMBlock', 'be', ':call SendMBlockToR("echo", "stay")')
    call RCreateMenuItem('ni', 'Send.Block\ (cur,\ down)', 'RDSendMBlock', 'bd', ':call SendMBlockToR("silent", "down")')
    call RCreateMenuItem('ni', 'Send.Block\ (cur,\ echo\ and\ down)', 'REDSendMBlock', 'ba', ':call SendMBlockToR("echo", "down")')
    "-------------------------------
    if &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst" || g:R_never_unmake_menu
        menu R.Send.-Sep2- <nul>
        call RCreateMenuItem('ni', 'Send.Chunk\ (cur)', 'RSendChunk', 'cc', ':call b:SendChunkToR("silent", "stay")')
        call RCreateMenuItem('ni', 'Send.Chunk\ (cur,\ echo)', 'RESendChunk', 'ce', ':call b:SendChunkToR("echo", "stay")')
        call RCreateMenuItem('ni', 'Send.Chunk\ (cur,\ down)', 'RDSendChunk', 'cd', ':call b:SendChunkToR("silent", "down")')
        call RCreateMenuItem('ni', 'Send.Chunk\ (cur,\ echo\ and\ down)', 'REDSendChunk', 'ca', ':call b:SendChunkToR("echo", "down")')
        call RCreateMenuItem('ni', 'Send.Chunk\ (from\ first\ to\ here)', 'RSendChunkFH', 'ch', ':call SendFHChunkToR()')
    endif
    "-------------------------------
    menu R.Send.-Sep3- <nul>
    call RCreateMenuItem('ni', 'Send.Function\ (cur)', 'RSendFunction', 'ff', ':call SendFunctionToR("silent", "stay")')
    call RCreateMenuItem('ni', 'Send.Function\ (cur,\ echo)', 'RESendFunction', 'fe', ':call SendFunctionToR("echo", "stay")')
    call RCreateMenuItem('ni', 'Send.Function\ (cur\ and\ down)', 'RDSendFunction', 'fd', ':call SendFunctionToR("silent", "down")')
    call RCreateMenuItem('ni', 'Send.Function\ (cur,\ echo\ and\ down)', 'REDSendFunction', 'fa', ':call SendFunctionToR("echo", "down")')
    "-------------------------------
    menu R.Send.-Sep4- <nul>
    call RCreateMenuItem('v', 'Send.Selection', 'RSendSelection', 'ss', ':call SendSelectionToR("silent", "stay")')
    call RCreateMenuItem('v', 'Send.Selection\ (echo)', 'RESendSelection', 'se', ':call SendSelectionToR("echo", "stay")')
    call RCreateMenuItem('v', 'Send.Selection\ (and\ down)', 'RDSendSelection', 'sd', ':call SendSelectionToR("silent", "down")')
    call RCreateMenuItem('v', 'Send.Selection\ (echo\ and\ down)', 'REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down")')
    call RCreateMenuItem('v', 'Send.Selection\ (and\ insert\ output)', 'RSendSelAndInsertOutput', 'so', ':call SendSelectionToR("echo", "stay", "NewtabInsert")')
    "-------------------------------
    menu R.Send.-Sep5- <nul>
    call RCreateMenuItem('ni', 'Send.Paragraph', 'RSendParagraph', 'pp', ':call SendParagraphToR("silent", "stay")')
    call RCreateMenuItem('ni', 'Send.Paragraph\ (echo)', 'RESendParagraph', 'pe', ':call SendParagraphToR("echo", "stay")')
    call RCreateMenuItem('ni', 'Send.Paragraph\ (and\ down)', 'RDSendParagraph', 'pd', ':call SendParagraphToR("silent", "down")')
    call RCreateMenuItem('ni', 'Send.Paragraph\ (echo\ and\ down)', 'REDSendParagraph', 'pa', ':call SendParagraphToR("echo", "down")')
    "-------------------------------
    menu R.Send.-Sep6- <nul>
    call RCreateMenuItem('ni0', 'Send.Line', 'RSendLine', 'l', ':call SendLineToR("stay")')
    call RCreateMenuItem('ni0', 'Send.Line\ (and\ down)', 'RDSendLine', 'd', ':call SendLineToR("down")')
    call RCreateMenuItem('ni0', 'Send.Line\ (and\ insert\ output)', 'RDSendLineAndInsertOutput', 'o', ':call SendLineToRAndInsertOutput()')
    call RCreateMenuItem('i', 'Send.Line\ (and\ new\ one)', 'RSendLAndOpenNewOne', 'q', ':call SendLineToR("newline")')
    call RCreateMenuItem('n', 'Send.Left\ part\ of\ line\ (cur)', 'RNLeftPart', 'r<Left>', ':call RSendPartOfLine("left", 0)')
    call RCreateMenuItem('n', 'Send.Right\ part\ of\ line\ (cur)', 'RNRightPart', 'r<Right>', ':call RSendPartOfLine("right", 0)')
    call RCreateMenuItem('i', 'Send.Left\ part\ of\ line\ (cur)', 'RILeftPart', 'r<Left>', 'l:call RSendPartOfLine("left", 1)')
    call RCreateMenuItem('i', 'Send.Right\ part\ of\ line\ (cur)', 'RIRightPart', 'r<Right>', 'l:call RSendPartOfLine("right", 1)')
    if &filetype == "r"
        call RCreateMenuItem('ni', 'Send.Line \(above\ ones)', 'RSendAboveLines', 'su', ':call SendAboveLinesToR()')
    endif

    "----------------------------------------------------------------------------
    " Control
    "----------------------------------------------------------------------------
    call RControlMenu()
    "-------------------------------
    menu R.Command.-Sep4- <nul>
    if &filetype != "rdoc"
        call RCreateMenuItem('nvi', 'Command.Set\ working\ directory\ (cur\ file\ path)', 'RSetwd', 'rd', ':call RSetWD()')
    endif
    "-------------------------------
    if &filetype == "rnoweb" || g:R_never_unmake_menu
        menu R.Command.-Sep5- <nul>
        call RCreateMenuItem('nvi', 'Command.Sweave\ (cur\ file)', 'RSweave', 'sw', ':call RWeave("nobib", 0, 0)')
        call RCreateMenuItem('nvi', 'Command.Sweave\ and\ PDF\ (cur\ file)', 'RMakePDF', 'sp', ':call RWeave("nobib", 0, 1)')
        call RCreateMenuItem('nvi', 'Command.Sweave,\ BibTeX\ and\ PDF\ (cur\ file)', 'RBibTeX', 'sb', ':call RWeave("bibtex", 0, 1)')
    endif
    menu R.Command.-Sep6- <nul>
    if &filetype == "rnoweb"
        call RCreateMenuItem('nvi', 'Command.Knit\ (cur\ file)', 'RKnit', 'kn', ':call RWeave("nobib", 1, 0)')
        call RCreateMenuItem('nvi', 'Command.Knit\ and\ PDF\ (cur\ file)', 'RMakePDFK', 'kp', ':call RWeave("nobib", 1, 1)')
        call RCreateMenuItem('nvi', 'Command.Knit,\ BibTeX\ and\ PDF\ (cur\ file)', 'RBibTeXK', 'kb', ':call RWeave("bibtex", 1, 1)')
    else
        call RCreateMenuItem('nvi', 'Command.Knit\ (cur\ file)', 'RKnit', 'kn', ':call RKnit()')
        call RCreateMenuItem('nvi', 'Command.Knit\ and\ PDF\ (cur\ file)', 'RMakePDFK', 'kp', ':call RMakeRmd("pdf_document")')
        call RCreateMenuItem('nvi', 'Command.Knit\ and\ Beamer\ PDF\ (cur\ file)', 'RMakePDFKb', 'kl', ':call RMakeRmd("beamer_presentation")')
        call RCreateMenuItem('nvi', 'Command.Knit\ and\ HTML\ (cur\ file)', 'RMakeHTML', 'kh', ':call RMakeRmd("html_document")')
        call RCreateMenuItem('nvi', 'Command.Knit\ and\ ODT\ (cur\ file)', 'RMakeODT', 'ko', ':call RMakeRmd("odt_document")')
        call RCreateMenuItem('nvi', 'Command.Knit\ and\ Word\ Document\ (cur\ file)', 'RMakeWord', 'kw', ':call RMakeRmd("word_document")')
        call RCreateMenuItem('nvi', 'Command.Markdown\ render\ (cur\ file)', 'RMakeRmd', 'kr', ':call RMakeRmd("default")')
    endif
    if &filetype == "r" || g:R_never_unmake_menu
        call RCreateMenuItem('nvi', 'Command.Spin\ (cur\ file)', 'RSpin', 'ks', ':call RSpin()')
    endif
    if ($DISPLAY != "" && g:R_synctex && &filetype == "rnoweb") || g:R_never_unmake_menu
        menu R.Command.-Sep61- <nul>
        call RCreateMenuItem('nvi', 'Command.Open\ PDF\ (cur\ file)', 'ROpenPDF', 'op', ':call ROpenPDF("Get Master")')
        call RCreateMenuItem('nvi', 'Command.Search\ forward\ (SyncTeX)', 'RSyncFor', 'gp', ':call SyncTeX_forward()')
        call RCreateMenuItem('nvi', 'Command.Go\ to\ LaTeX\ (SyncTeX)', 'RSyncTex', 'gt', ':call SyncTeX_forward(1)')
    endif
    "-------------------------------
    if &filetype == "r" || &filetype == "rnoweb" || g:R_never_unmake_menu
        menu R.Command.-Sep72- <nul>
        nmenu <silent> R.Command.Build\ tags\ file\ (cur\ dir)<Tab>:RBuildTags :call RBuildTags()<CR>
        imenu <silent> R.Command.Build\ tags\ file\ (cur\ dir)<Tab>:RBuildTags <Esc>:call RBuildTags()<CR>a
    endif

    menu R.-Sep7- <nul>

    "----------------------------------------------------------------------------
    " Edit
    "----------------------------------------------------------------------------
    if &filetype == "r" || &filetype == "rnoweb" || &filetype == "rrst" || &filetype == "rhelp" || g:R_never_unmake_menu
        if g:R_assign == 1 || g:R_assign == 2
            silent exe 'imenu <silent> R.Edit.Insert\ \"\ <-\ \"<Tab>' . g:R_assign_map . ' <Esc>:call ReplaceUnderS()<CR>a'
        endif
        imenu <silent> R.Edit.Complete\ object\ name<Tab>^X^O <C-X><C-O>
        menu R.Edit.-Sep71- <nul>
        nmenu <silent> R.Edit.Indent\ (line)<Tab>== ==
        vmenu <silent> R.Edit.Indent\ (selected\ lines)<Tab>= =
        nmenu <silent> R.Edit.Indent\ (whole\ buffer)<Tab>gg=G gg=G
        menu R.Edit.-Sep72- <nul>
        call RCreateMenuItem('ni', 'Edit.Toggle\ comment\ (line/sel)', 'RToggleComment', 'xx', ':call RComment("normal")')
        call RCreateMenuItem('v',  'Edit.Toggle\ comment\ (line/sel)', 'RToggleComment', 'xx', ':call RComment("selection")')
        call RCreateMenuItem('ni', 'Edit.Comment\ (line/sel)', 'RSimpleComment', 'xc', ':call RSimpleCommentLine("normal", "c")')
        call RCreateMenuItem('v',  'Edit.Comment\ (line/sel)', 'RSimpleComment', 'xc', ':call RSimpleCommentLine("selection", "c")')
        call RCreateMenuItem('ni', 'Edit.Uncomment\ (line/sel)', 'RSimpleUnComment', 'xu', ':call RSimpleCommentLine("normal", "u")')
        call RCreateMenuItem('v',  'Edit.Uncomment\ (line/sel)', 'RSimpleUnComment', 'xu', ':call RSimpleCommentLine("selection", "u")')
        call RCreateMenuItem('ni', 'Edit.Add/Align\ right\ comment\ (line,\ sel)', 'RRightComment', ';', ':call MovePosRCodeComment("normal")')
        call RCreateMenuItem('v',  'Edit.Add/Align\ right\ comment\ (line,\ sel)', 'RRightComment', ';', ':call MovePosRCodeComment("selection")')
        if &filetype == "rnoweb" || &filetype == "rrst" || &filetype == "rmd" || g:R_never_unmake_menu
            menu R.Edit.-Sep73- <nul>
            call RCreateMenuItem('n', 'Edit.Go\ (next\ R\ chunk)', 'RNextRChunk', 'gn', ':call b:NextRChunk()')
            call RCreateMenuItem('n', 'Edit.Go\ (previous\ R\ chunk)', '', 'gN', ':call b:PreviousRChunk()')
        endif
    endif

    "----------------------------------------------------------------------------
    " Object Browser
    "----------------------------------------------------------------------------
    call RBrowserMenu()

    "----------------------------------------------------------------------------
    " Help
    "----------------------------------------------------------------------------
    menu R.-Sep8- <nul>
    amenu R.Help\ (plugin).Overview :help Nvim-R-overview<CR>
    amenu R.Help\ (plugin).Main\ features :help Nvim-R-features<CR>
    amenu R.Help\ (plugin).Installation :help Nvim-R-installation<CR>
    amenu R.Help\ (plugin).Use :help Nvim-R-use<CR>
    amenu R.Help\ (plugin).Known\ bugs\ and\ workarounds :help Nvim-R-known-bugs<CR>

    amenu R.Help\ (plugin).Options.Assignment\ operator\ and\ Rnoweb\ code :help R_assign<CR>
    amenu R.Help\ (plugin).Options.Object\ Browser :help R_objbr_place<CR>
    amenu R.Help\ (plugin).Options.Vim\ as\ pager\ for\ R\ help :help R_nvimpager<CR>
    if !has("win32")
        amenu R.Help\ (plugin).Options.Terminal\ emulator :help R_term<CR>
    endif
    if g:rplugin.is_darwin
        amenu R.Help\ (plugin).Options.Integration\ with\ Apple\ Script :help R_applescript<CR>
    endif
    amenu R.Help\ (plugin).Options.R\ path :help R_path<CR>
    amenu R.Help\ (plugin).Options.Arguments\ to\ R :help R_args<CR>
    amenu R.Help\ (plugin).Options.Omni\ completion\ when\ R\ not\ running :help R_start_libs<CR>
    amenu R.Help\ (plugin).Options.Syntax\ highlighting\ of\ \.Rout\ files :help R_routmorecolors<CR>
    amenu R.Help\ (plugin).Options.Automatically\ open\ the\ \.Rout\ file :help R_routnotab<CR>
    amenu R.Help\ (plugin).Options.Special\ R\ functions :help R_listmethods<CR>
    amenu R.Help\ (plugin).Options.Indent\ commented\ lines :help R_indent_commented<CR>
    amenu R.Help\ (plugin).Options.LaTeX\ command :help R_latexcmd<CR>
    amenu R.Help\ (plugin).Options.Never\ unmake\ the\ R\ menu :help R_never_unmake_menu<CR>

    amenu R.Help\ (plugin).Custom\ key\ bindings :help Nvim-R-key-bindings<CR>
    amenu R.Help\ (plugin).Files :help Nvim-R-files<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.All\ tips :help Nvim-R-tips<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.Indenting\ setup :help Nvim-R-indenting<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.Folding\ setup :help Nvim-R-folding<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.Remap\ LocalLeader :help Nvim-R-localleader<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.Customize\ key\ bindings :help Nvim-R-bindings<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.ShowMarks :help Nvim-R-showmarks<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.SnipMate :help Nvim-R-snippets<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.LaTeX-Box :help Nvim-R-latex-box<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.Highlight\ marks :help Nvim-R-showmarks<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.Global\ plugin :help Nvim-R-global<CR>
    amenu R.Help\ (plugin).FAQ\ and\ tips.Jump\ to\ function\ definitions :help Nvim-R-tagsfile<CR>
    amenu R.Help\ (plugin).News :help Nvim-R-news<CR>

    amenu R.Help\ (R)<Tab>:Rhelp :call g:SendCmdToR("help.start()")<CR>
    let g:rplugin.hasmenu = 1
endfunction

function UnMakeRMenu()
    if g:rplugin.hasmenu == 0 || g:R_never_unmake_menu == 1 || &previewwindow || (&buftype == "nofile" && &filetype != "rbrowser")
        return
    endif
    aunmenu R
    let g:rplugin.hasmenu = 0
endfunction

function MakeRBrowserMenu()
    let g:rplugin.curbuf = bufname("%")
    if g:rplugin.hasmenu == 1
        return
    endif
    menutranslate clear
    call RControlMenu()
    call RBrowserMenu()
endfunction

