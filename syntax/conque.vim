" FILE:     syntax/conque.vim
" AUTHOR:   Nico Raffo <nicoraffo@gmail.com>
"           Shougo Matsushita <Shougo.Matsu@gmail.com> (original VimShell)
"           Yukihiro Nakadaira (vimproc)
" MODIFIED: 2009-09-02
" VERSION:  0.1, for Vim 7.0
" LICENSE: {{{
" Conque - pty interaction in Vim
" Copyright (C) 2009 Nico Raffo 
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.
" }}}

" MySQL
syn match MySQLTableHead "^|.*|$" nextgroup=MySQLTableDivide contains=MySQLTableBar oneline skipwhite skipnl
syn match MySQLTableBody "^|.*|$" nextgroup=MySQLTableBody,MySQLTableEnd contains=MySQLTableBar,MySQLNull,MySQLSpecial,MySQLNumber,String,Number oneline skipwhite skipnl
syn match MySQLTableEnd "^+[+-]\++$" oneline 
syn match MySQLTableDivide "^+[+-]\++$" nextgroup=MySQLTableBody oneline skipwhite skipnl
syn match MySQLTableStart "^+[+-]\++$" nextgroup=MySQLTableHead oneline skipwhite skipnl
syn match MySQLTableBar "|" contained
syn match MySQLNull " NULL " contained
syn match MySQLSpecial " YES " contained
syn match MySQLSpecial " NO " contained
syn match MySQLSpecial " PRI " contained
syn match MySQLSpecial " MUL " contained
syn match MySQLSpecial " CURRENT_TIMESTAMP " contained
syn match MySQLSpecial " auto_increment " contained
syn match MySQLNumber " \d\+ " contained
syn match MySQLQueryStat "^\d\+ rows\? in set.*" oneline
syn match MySQLPrompt "^.\?mysql> " oneline
syn match MySQLPrompt "^    -> " oneline

syn case ignore
syn keyword Keyword select count max show table status like as from left right outer inner join where group by having limit offset order desc asc show
syn case match

" Typical Prompt
syn match ConquePrompt "^\[.\+\]\$" oneline
syn match ConqueWait "^\.\.\.$" oneline
syn region String start=+'+ end=+'+ skip=+\\'+  oneline
syn region String start=+"+ end=+"+ skip=+\\"+  oneline
syn region String start=+`+ end=+`+ skip=+\\`+ oneline



" vim: foldmethod=marker
