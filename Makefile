
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# A copy of the GNU General Public License is available at
# http://www.r-project.org/Licenses/


###########################################################
#   This script builds both the Vimball and the deb       #
#   files of released versions of the plugin. The files   #
#   are created at the /tmp directory.                    #
###########################################################



PLUGINHOME=`pwd`
PLUGINVERSION=0.9.0
DEBIANTIME=`date -R`
PLUGINRELEASEDATE=`date +"%Y-%m-%d"`
VIM2HTML=/usr/local/share/vim/vim74/doc/vim2html.pl 


vimball:
	# Update the version date in doc/Nvim-R.txt header and in the news
	sed -i -e "s/^Version: [0-9].[0-9].[0-9].[0-9]/Version: $(PLUGINVERSION)/" doc/Nvim-R.txt
	sed -i -e "s/^$(PLUGINVERSION) (201[0-9]-[0-9][0-9]-[0-9][0-9])$$/$(PLUGINVERSION) ($(PLUGINRELEASEDATE))/" doc/Nvim-R.txt
	sed -i -e "s/^let g:Nvim_R_version =.*/let g:Nvim_R_version = '$(PLUGINVERSION)'/" r-plugin/common_global.vim
	nvim -c "%MkVimball Nvim-R ." -c "q" list_for_vimball
	mv Nvim-R.vmb /tmp

deb:
	# Clean previously created files
	(cd /tmp ; rm -rf nvim-r-tmp )
	# Create the directory of a Debian package
	( cd /tmp ;\
	    mkdir -p nvim-r-tmp/usr/share/nvim/addons ;\
	    mkdir -p nvim-r-tmp/usr/share/nvim/registry ;\
	    mkdir -p nvim-r-tmp/usr/share/doc/nvim-r )
	# Create the Debian changelog
	echo $(DEBCHANGELOG) "nvim-r ($(PLUGINVERSION)-1) unstable; urgency=low\n\
	\n\
	  * Initial Release.\n\
	\n\
	 -- Jakson Alves de Aquino <jalvesaq@gmail.com>  $(DEBIANTIME)\n\
	" | gzip --best > /tmp/nvim-r-tmp/usr/share/doc/nvim-r/changelog.gz
	# Create the yaml script
	echo "addon: r-plugin\n\
	description: \"Filetype plugin to work with R\"\n\
	disabledby: \"let disable_r_ftplugin = 1\"\n\
	files:\n\
	  - doc/Nvim-R.txt\n\
	  - ftplugin/rbrowser.vim\n\
	  - ftplugin/rdoc.vim\n\
	  - ftplugin/rhelp_rplugin.vim\n\
	  - ftplugin/rhelp.vim\n\
	  - ftplugin/rmd_rplugin.vim\n\
	  - ftplugin/rmd.vim\n\
	  - ftplugin/rnoweb_rplugin.vim\n\
	  - ftplugin/rnoweb.vim\n\
	  - ftplugin/r_rplugin.vim\n\
	  - ftplugin/rrst_rplugin.vim\n\
	  - ftplugin/rrst.vim\n\
	  - ftplugin/r.vim\n\
	  - R/common_buffer.vim\n\
	  - R/common_global.vim\n\
	  - R/functions.vim\n\
	  - R/global_r_plugin.vim\n\
	  - R/gui_running.vim\n\
	  - R/nvimbuffer.vim\n\
	  - R/osx.vim\n\
	  - R/rmd.snippets\n\
	  - R/r.snippets\n\
	  - R/setcompldir.vim\n\
	  - R/synctex_evince_backward.py\n\
	  - R/synctex_evince_forward.py\n\
	  - R/synctex_okular_backward.sh\n\
	  - indent/rhelp.vim\n\
	  - indent/rmd.vim\n\
	  - indent/rnoweb.vim\n\
	  - indent/rrst.vim\n\
	  - indent/r.vim\n\
	  - syntax/rbrowser.vim\n\
	  - syntax/rdoc.vim\n\
	  - syntax/rhelp.vim\n\
	  - syntax/rmd.vim\n\
	  - syntax/rout.vim\n\
	  - syntax/rrst.vim\n\
	  - syntax/r.vim\n\
	" > /tmp/nvim-r-tmp/usr/share/nvim/registry/nvim-r.yaml
	# Create the copyright
	echo "Copyright (C) 2011-2014 Jakson Aquino\n\
	\n\
	License: GPLv2+\n\
	\n\
	This program is free software; you can redistribute it and/or modify\n\
	it under the terms of the GNU General Public License as published by\n\
	the Free Software Foundation; either version 2 of the License, or\n\
	(at your option) any later version.\n\
	\n\
	This program is distributed in the hope that it will be useful,\n\
	but WITHOUT ANY WARRANTY; without even the implied warranty of\n\
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n\
	GNU General Public License for more details.\n\
	\n\
	You should have received a copy of the GNU General Public License\n\
	along with this program; if not, write to the Free Software\n\
	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.\n\
	\n\
	See /usr/share/common-licenses/GPL-2, or\n\
	<http://www.gnu.org/copyleft/gpl.txt> for the terms of the latest version\n\
	of the GNU General Public License.\n\
	" > /tmp/nvim-r-tmp/usr/share/doc/nvim-r/copyright
	# Unpack the plugin
	nvim -c 'set nomore' -c 'let g:vimball_home="/tmp/nvim-r-tmp/usr/share/nvim/addons"' -c "so %" -c "q" /tmp/Nvim-R.vmb
	# Create the DEBIAN directory
	( cd /tmp/nvim-r-tmp ;\
	    mkdir DEBIAN ;\
	    INSTALLEDSIZE=`du -s | sed -e 's/\t.*//'` )
	# Create the control file
	echo "Package: nvim-r\n\
	Version: $(PLUGINVERSION)\n\
	Architecture: all\n\
	Maintainer: Jakson Alves de Aquino <jalvesaq@gmail.com>\n\
	Installed-Size: $(INSTALLEDSIZE)\n\
	Depends: nvim | nvim-gtk | nvim-gnome, tmux (>= 1.8), ncurses-term, nvim-addon-manager, r-base-core\n\
	Suggests: wmctrl, latexmk\n\
	Enhances: nvim\n\
	Section: text\n\
	Priority: extra\n\
	Homepage: http://www.lepem.ufc.br/jaa/Nvim-R.html\n\
	Description: Plugin to work with R\n\
	 This filetype plugin has the following main features:\n\
	       - Start/Close R.\n\
	       - Send lines, selection, paragraphs, functions, blocks, entire file.\n\
	       - Send commands with the object under cursor as argument:\n\
	         help, args, plot, print, str, summary, example, names.\n\
	       - Support for editing Rnoweb files.\n\
	       - Omni completion (auto-completion) for R objects.\n\
	       - Ability to see R documentation in a Nvim buffer.\n\
	       - Object Browser." > /tmp/nvim-r-tmp/DEBIAN/control
	# Create the md5sum file
	(cd /tmp/nvim-r-tmp/ ;\
	    find usr -type f -print0 | xargs -0 md5sum > DEBIAN/md5sums )
	# Create the posinst and postrm scripts
	echo '#!/bin/sh\n\
	set -e\n\
	\n\
	helpztags /usr/share/nvim/addons/doc\n\
	\n\
	exit 0\n\
	' > /tmp/nvim-r-tmp/DEBIAN/postinst
	echo '#!/bin/sh\n\
	set -e\n\
	\n\
	helpztags /usr/share/nvim/addons/doc\n\
	\n\
	exit 0\n\
	' > /tmp/nvim-r-tmp/DEBIAN/postrm
	# Fix permissions
	(cd /tmp/nvim-r-tmp ;\
	    chmod g-w -R * ;\
	    chmod +x DEBIAN/postinst DEBIAN/postrm )
	# Build the Debian package
	( cd /tmp ;\
	    fakeroot dpkg-deb -b nvim-r-tmp nvim-r_$(PLUGINVERSION)-1_all.deb )

htmldoc:
	nvim -c ":helptags ~/src/Nvim-R/doc" -c ":quit" ;\
	(cd doc ;\
	    $(VIM2HTML) tags Nvim-R.txt ;\
	    sed -i -e 's/<code class.*gmail.com.*code>//' Nvim-R.html ;\
	    sed -i -e 's/|<a href=/<a href=/g' Nvim-R.html ;\
	    sed -i -e 's/<\/a>|/<\/a>/g' Nvim-R.html ;\
	    sed -i -e 's/|<code /<code /g' Nvim-R.html ;\
	    sed -i -e 's/<\/code>|/<\/code>/g' Nvim-R.html ;\
	    sed -i -e 's/`//g' Nvim-R.html ;\
	    sed -i -e 's/\( *\)\(http\S*\)/\1<a href="\2">\2<\/a>/' Nvim-R.html ;\
	    sed -i -e 's/<\/pre><hr><pre>/  --------------------------------------------------------\n/' Nvim-R.html ;\
	    mv Nvim-R.html /tmp/nvim-r-doc.html ;\
	    mv vim-stylesheet.css /tmp )

all: vimball deb htmldoc

