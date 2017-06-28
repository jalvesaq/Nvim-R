
" g:rplugin_home should be the directory where the plugin files are.  For
" users following the installation instructions it will be at ~/.vim or
" ~/vimfiles, that is, the same value of g:rplugin_uservimfiles. However the
" variables will have different values if the plugin is installed somewhere
" else in the runtimepath.
let g:rplugin_home = expand("<sfile>:h:h")

" g:rplugin_uservimfiles must be a writable directory. It will be g:rplugin_home
" unless it's not writable. Then it wil be ~/.vim or ~/vimfiles.
if filewritable(g:rplugin_home) == 2
    let g:rplugin_uservimfiles = g:rplugin_home
else
    let g:rplugin_uservimfiles = split(&runtimepath, ",")[0]
endif

" From changelog.vim, with bug fixed by "Si" ("i5ivem")
" Windows logins can include domain, e.g: 'DOMAIN\Username', need to remove
" the backslash from this as otherwise cause file path problems.
if executable("whoami")
    let g:rplugin_userlogin = substitute(system('whoami'), '\W', '-', 'g')
elseif $USERNAME != ""
    let g:rplugin_userlogin = $USERNAME
elseif $USER != ""
    let g:rplugin_userlogin = $USER
else
    call RWarningMsgInp("Could not determine user name.")
    let g:rplugin_failed = 1
    finish
endif
let g:rplugin_userlogin = substitute(substitute(g:rplugin_userlogin, '.*\\', '', ''), '\W', '', 'g')
if g:rplugin_userlogin == ""
    call RWarningMsgInp("Could not determine user name.")
    let g:rplugin_failed = 1
    finish
endif

if has("win32")
    let g:rplugin_home = substitute(g:rplugin_home, "\\", "/", "g")
    let g:rplugin_uservimfiles = substitute(g:rplugin_uservimfiles, "\\", "/", "g")
    if $USERNAME != ""
        let g:rplugin_userlogin = substitute($USERNAME, '\W', '', 'g')
    endif
endif

if exists("g:R_compldir")
    let g:rplugin_compldir = expand(g:R_compldir)
elseif has("win32") && $APPDATA != "" && isdirectory($APPDATA)
    let g:rplugin_compldir = $APPDATA . "\\Nvim-R"
elseif $XDG_CACHE_HOME != "" && isdirectory($XDG_CACHE_HOME)
    let g:rplugin_compldir = $XDG_CACHE_HOME . "/Nvim-R"
elseif isdirectory(expand("~/.cache"))
    let g:rplugin_compldir = expand("~/.cache/Nvim-R")
elseif isdirectory(expand("~/Library/Caches"))
    let g:rplugin_compldir = expand("~/Library/Caches/Nvim-R")
else
    let g:rplugin_compldir = g:rplugin_uservimfiles . "/R/objlist/"
endif

" Create the directory if it doesn't exist yet
if !isdirectory(g:rplugin_compldir)
    call mkdir(g:rplugin_compldir, "p")
endif

" Create or update the README (omnils_ files will be regenerated if older than
" the README).
let s:need_readme = 0
if !filereadable(g:rplugin_compldir . "/README")
    let s:need_readme = 1
else
    let lines = readfile(g:rplugin_compldir . "/README")
    if lines[0] != "Files in this directory were generated by Nvim-R:"
        let s:need_readme = 1
    endif
endif
if s:need_readme
    let s:readme = ['Files in this directory were generated by Nvim-R:',
                \ 'The omnils_ and fun_ files are used for omni completion and syntax highlight.',
                \ 'If you delete them, they will be regenerated.',
                \ '',
                \ 'When you load a new version of a library, their files are replaced.',
                \ '',
                \ 'Files corresponding to uninstalled libraries are not automatically deleted.',
                \ 'You should manually delete them if you want to save disc space.',
                \ 'If you delete this file, all omnils_ and fun_ files will be regenerated.']
    call writefile(s:readme, g:rplugin_compldir . "/README")
    call delete(g:rplugin_compldir . "nvimcom_info") " FIXME : this line is unnecessary after merging the branch.
    unlet s:readme
endif
unlet s:need_readme

let $NVIMR_COMPLDIR = g:rplugin_compldir

