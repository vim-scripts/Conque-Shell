" FILE:     syntax/conque.vim
" AUTHOR:   Nico Raffo <nicoraffo@gmail.com>
" MODIFIED: 2009-10-01
" VERSION:  0.2, for Vim 7.0
" LICENSE: {{{
" Conque - pty interaction in Vim
" Copyright (C) 2009 Nico Raffo 
"
" MIT License
" 
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
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
