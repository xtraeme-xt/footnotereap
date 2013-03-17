" An example for a vimrc file.
"
" Maintainer:	Xtraeme <xthaus@yahoo.com>
" Last change:	2013 Mar 16
"
" To use it, reference it in:
"     for Unix and OS/2:  ~/.vimrc
"	      for Amiga:  s:.vimrc
"  for MS-DOS and Win32:  $VIM\_vimrc
"	    for OpenVMS:  sys$login:.vimrc

set tags=D:\projects\tags,C:\PROGRA~1\MID05A~1\VC\tags,C:\usr\local\cell\tags,C:\PROGRA~1\MI5E0B~1\tags
" C:\Program Files\Microsoft Visual Studio .NET 2003\Vc7\tags
nnoremap <silent> <F8> :TlistToggle<CR>
" Might want this if I'm doing massive bulk edits
" set autosave
" highlight Normal guibg=lightyellow
" set background=dark
hi Visual ctermbg=white
hi Visual guibg=yellow

let Perl_AuthorName='Xtraeme'
"let Perl_AuthorRef='xthaus'
let Perl_Email='xthaus@yahoo.com'
let Perl_Company='NA'
let Perl_Project='footnotereap'
let Perl_CopyrightHolder='Xtraeme - 2011'

set ts=4
set noexpandtab
