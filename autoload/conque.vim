" FILE:     autoload/conque.vim
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

" Open a command in Conque.
" This is the root function that is called from Vim to start up Conque.
function! conque#open(command)"{{{

    if empty(a:command)
        echohl WarningMsg | echomsg "No command found" | echohl None
        return 0
    endif

    " configure shell buffer display and key mappings
    call s:set_buffer_settings(a:command)

    " set global environment variables
    call s:set_environment()

    " load vimproc C library
    let l:proc_lib = proc#import()

    " open command
    try
        let l:proc = l:proc_lib.ptyopen(split(a:command))
    catch 
        let l:error = printf('File: "%s" is not found.', a:command)
        echohl WarningMsg | echomsg l:error | echohl None
        return 0
    endtry

    " always check for zombies before over-writing them
    if exists('b:proc')
        " more zombies than usual today
        call conque#force_exit()
    endif

    " Set variables.
    let b:vimproc_lib = l:proc_lib
    let b:proc = l:proc
    let b:command_history = []
    let b:prompt_history = {}
    let b:current_command = ''
    let b:command_position = 0
    let b:tab_complete_history = {}

    " read welcome message from command
    call s:read()


    startinsert!
    return 1
endfunction"}}}

" set shell environment vars
" XXX - probably should delegate this to logic in .bashrc?
function! s:set_environment()"{{{
    let $TERM = "dumb"
    let $TERMCAP = "COLUMNS=" . winwidth(0)
    let $VIMSHELL = 1
    let $COLUMNS = winwidth(0) " these get reset by terminal anyway
    let $LINES = winheight(0)
    
endfunction"}}}

" buffer settings, layout, key mappings, and auto commands
function! s:set_buffer_settings(command)"{{{
    split
    execute "edit " . substitute(a:command, ' ', '_', 'g') . "@conque"
    setlocal buftype=nofile  " this buffer is not a file, you can't save it
    setlocal nonumber        " hide line numbers
    setlocal foldcolumn=1    " reasonable left margin
    setlocal nowrap          " default to no wrap (esp with MySQL)
    setlocal noswapfile      " don't bother creating a .swp file
    setfiletype conque        " useful
    setlocal syntax=conque    " see syntax/conque.vim

    " run the current command
    nnoremap <buffer><silent><CR>        :<C-u>call conque#run()<CR>
    inoremap <buffer><silent><CR>        <ESC>:<C-u>call conque#run()<CR>
    " don't backspace over prompt
    inoremap <buffer><silent><expr><BS>  <SID>delete_backword_char()
    " clear current line
    inoremap <buffer><silent><C-u>       <ESC>:<C-u>call conque#kill_line()<CR>
    " tab complete
    inoremap <buffer><silent><Tab>       <ESC>:<C-u>call <SID>tab_complete()<CR>
    " previous/next command
    inoremap <buffer><silent><Up>        <ESC>:<C-u>call <SID>previous_command()<CR>
    inoremap <buffer><silent><Down>      <ESC>:<C-u>call <SID>next_command()<CR>
    " interrupt
    nnoremap <buffer><silent><C-c>       :<C-u>call conque#sigint()<CR>
    inoremap <buffer><silent><C-c>       <ESC>:<C-u>call conque#sigint()<CR>
    " escape
    nnoremap <buffer><silent><C-e>       :<C-u>call conque#escape()<CR>
    inoremap <buffer><silent><C-e>       <ESC>:<C-u>call conque#escape()<CR>

    " handle unexpected closing of shell
    " passes HUP to main and all child processes
    augroup conque
        autocmd BufUnload <buffer>   call conque#hang_up()
    augroup END
endfunction"}}}

" controller to execute current line
function! conque#run()"{{{

    if !exists('b:proc')
        echohl WarningMsg | echomsg "Not a shell" | echohl None
        return
    endif
    call conque#write(1)
    call s:read()

endfunction"}}}

" execute current line, but return output as string instead of printing to buffer
function! conque#run_return()"{{{
    if !exists('b:proc')
        echohl WarningMsg | echomsg "Not a shell" | echohl None
        return
    endif
    call conque#write(0)
    let l:output = conque#read_return_raw()
    return l:output
endfunction"}}}

" write current line to pty
function! conque#write(add_newline)"{{{

    " pull command from the buffer
    let l:in = s:get_command()
    
    " waiting
    if l:in == '...'
        call append(line('$'), '...')
        return
    endif

    " run the command!
    try
        if a:add_newline == 1
            call b:proc.write(l:in . "\<NL>")
        else
            call b:proc.write(l:in)
        endif
    catch
        echohl WarningMsg | echomsg 'command fail' | echohl None
        call conque#exit()
    endtry
    
    " record command history
    let l:hc = ''
    if exists("b:prompt_history['".line('.')."']")
        let l:hc = getline('.')
        let l:hc = l:hc[len(b:prompt_history[line('.')]) : ]
    else
        let l:hc = l:in
    endif
    if l:hc != '' && l:hc != '...' && l:hc !~ '\t$'
        call add(b:command_history, l:hc)
    endif
    let b:current_command = l:in
    let b:command_position = 0
    if exists("b:tab_complete_history['".line('.')."']")
        call remove(b:tab_complete_history, line('.'))
    endif

    " we're doing something
    if a:add_newline == 1
        call append(line('$'), '...')
    endif

    normal! G$
endfunction"}}}

" parse current line to remove prompt and return command.
" also manages multi-line commands.
function! s:get_command()"{{{
  let l:in = getline('.')

  if l:in == ''
    " Do nothing.

  elseif l:in == '...'
    " Working

  elseif exists("b:tab_complete_history['".line('.')."']")
    let l:in = l:in[len(b:tab_complete_history[line('.')]) : ]

  elseif exists("b:prompt_history['".line('.')."']")
    let l:in = l:in[len(b:prompt_history[line('.')]) : ]

  else
    " Maybe line numbering got disrupted, search for a matching prompt.
    let l:prompt_search = 0
    for pnr in reverse(sort(keys(b:prompt_history)))
      let l:prompt_length = len(b:prompt_history[pnr])
      " In theory 0 length or ' ' prompt shouldn't exist, but still...
      if l:prompt_length > 0 && b:prompt_history[pnr] != ' '
        " Does the current line have this prompt?
        if l:in[0 : l:prompt_length - 1] == b:prompt_history[pnr]
          let l:in = l:in[l:prompt_length : ]
          let l:prompt_search = pnr
        endif
      endif
    endfor

    " Still nothing? Maybe a multi-line command was pasted in.
    let l:max_prompt = max(keys(b:prompt_history)) " Only count once.
    if l:prompt_search == 0 && l:max_prompt < line('$')
    for i in range(l:max_prompt, line('$'))
      if i == l:max_prompt
        let l:in = getline(i)
        let l:in = l:in[len(b:prompt_history[i]) : ]
      else
        let l:in = l:in . getline(i)
      endif
    endfor
      let l:prompt_search = l:max_prompt
    endif

    " Still nothing? We give up.
    if l:prompt_search == 0
      echohl WarningMsg | echo "Invalid input." | echohl None
      normal! G$
      startinsert!
      return
    endif
  endif

  return l:in
endfunction"}}}

" read from pty and write to buffer
function! s:read()"{{{

    " read AND write to buffer
    let l:read = b:proc.read(-1, 40)
    let l:output = ''
    while l:read != ''
        let l:output = l:output . l:read
        let l:read = b:proc.read(-1, 40)
    endwhile
    " print to buffer
    call s:print_buffer(l:output)
    redraw


    " check for fail
    if b:proc.eof
        echohl WarningMsg | echomsg 'EOF' | echohl None
        call conque#exit()
        normal! G$
        return
    endif

    " record prompt used on this line
    let b:prompt_history[line('.')] = getline('.')

    " ready to insert now
    normal! G$
    startinsert!
endfunction"}}}

" read from pty and return output as string
function! conque#read_return_raw()"{{{

    " read AND write to buffer
    let l:read = b:proc.read(-1, 500)
    let l:output = l:read
    while l:read != ''
        let l:read = b:proc.read(-1, 500)
        let l:output = l:output . l:read
    endwhile

    " ready to insert now
    return l:output
endfunction"}}}

" parse output from pty and update buffer
function! s:print_buffer(string)"{{{
    if a:string == ''
        return
    endif

    " Convert encoding for system().
    let l:string = iconv(a:string, 'utf-8', &encoding) 

    " check for Bells
    if l:string =~ nr2char(7)
        let l:string = substitute(l:string, nr2char(7), '', 'g')
        echohl WarningMsg | echomsg "For shame!" | echohl None
    endif

    " Strip <CR>.
    let l:string = substitute(substitute(l:string, '\r', '', 'g'), '\n$', '', '')
    let l:lines = split(l:string, '\n', 1)

    " strip off command repeated by the ECHO terminal flag
    if l:lines[0] == b:current_command
        let l:lines = l:lines[1:]
    endif

    " special case: first line in buffer
    if line('$') == 1 && empty(getline('$'))
        call setline(line('$'), l:lines[0])
        let l:lines = l:lines[1:]
    endif

    " write to buffer
    call setline(line('$'), l:lines)

    " Set cursor.
    normal! G$
endfunction"}}}

" kill process pid with SIGTERM
" since most shells ignore SIGTERM there's a good chance this will do nothing
function! conque#exit()"{{{
    if !exists('b:proc')
        echohl WarningMsg | echomsg "huh no proc exists" | echohl None
        return
    endif

    " Kill process.
    try
        " 15 == SIGTERM
        call b:vimproc_lib.api.vp_kill(b:proc.pid, 15)
    catch /No such process/
    endtry

    unlet b:vimproc_lib
    unlet b:proc
endfunction"}}}

" kill process pid with SIGKILL
" undesirable, but effective
function! conque#force_exit()"{{{

    if !exists('b:proc')
        return
    endif

    " Kill processes.
    try
        " 9 == SIGKILL
        call b:vimproc_lib.api.vp_kill(b:proc.pid, 9)
        call append(line('$'), '*Killed*')
    catch /No such process/
    endtry

    unlet b:vimproc_lib
    unlet b:proc

endfunction"}}}

" kill process pid with SIGHUP
" this gets called if the buffer is unloaded before the program has been exited
" it should pass the signall to all children before killing the parent process
function! conque#hang_up()"{{{

    if !exists('b:proc')
        return
    endif

    " Kill processes.
    try
        " 1 == HUP
        call b:vimproc_lib.api.vp_kill(b:proc.pid, 1)
        call append(line('$'), '*Killed*')
    catch /No such process/
    endtry

    unlet b:vimproc_lib
    unlet b:proc

endfunction"}}}

" load previous command
" XXX - we should probably use native history instead, although it's slower
function! s:previous_command()"{{{
    " If this is the first up arrow use, save what's been typed in so far.
    if b:command_position == 0
        let b:current_working_command = strpart(getline('.'), len(b:prompt_history[line('.')]))
    endif
    " If there are no more previous commands.
    if len(b:command_history) == b:command_position
        echohl WarningMsg | echomsg "End of history" | echohl None
        startinsert!
        return
    endif
    let b:command_position = b:command_position + 1
    let l:prev_command = b:command_history[len(b:command_history) - b:command_position]
    call setline(line('.'), b:prompt_history[max(keys(b:prompt_history))] . l:prev_command)
    startinsert!
endfunction"}}}

" load next command
" XXX - we should probably use native history instead, although it's slower
function! s:next_command()"{{{
    " If we're already at the last command.
    if b:command_position == 0
        echohl WarningMsg | echomsg "End of history" | echohl None
        startinsert!
        return
    endif
    let b:command_position = b:command_position - 1
    " Back at the beginning, put back what had been typed.
    if b:command_position == 0
        call setline(line('.'), b:prompt_history[max(keys(b:prompt_history))] . b:current_working_command)
        startinsert!
        return
    endif
    let l:next_command = b:command_history[len(b:command_history) - b:command_position]
    call setline(line('.'), b:prompt_history[max(keys(b:prompt_history))] . l:next_command)
    startinsert!
endfunction"}}}

" catch <BS> to prevent deleting prompt
" if tab completion has initiated, prevent deleting partial command already sent to pty
function! s:delete_backword_char()"{{{
    " identify prompt
    if exists('b:tab_complete_history[line(".")]')
        let l:prompt = b:tab_complete_history[line('.')]
    elseif exists('b:prompt_history[line(".")]')
        let l:prompt = b:prompt_history[line('.')]
    else
        return "\<BS>"
    endif
    
    if getline(line('.')) != l:prompt
        return "\<BS>"
    else
        return ""
    endif
endfunction"}}}

" tab complete current line
" TODO: integrate multiple options with Vim auto-complete menu
function! s:tab_complete()"{{{
    " Insert <TAB>.
    if exists('b:tab_complete_history[line(".")]')
        let l:prompt = b:tab_complete_history[line('.')]
    elseif exists('b:prompt_history[line(".")]')
        let l:prompt = b:prompt_history[line('.')]
    else
        let l:prompt = ''
    endif

    let l:working_line = getline('.')
    let l:working_command = l:working_line[len(l:prompt) : len(l:working_line)]

    call setline(line('.'), getline('.') . "\<TAB>")

    let l:candidate = conque#run_return()
    let l:extra = substitute(l:candidate, '^'.l:working_command, '', '')

    if l:extra == nr2char(7)
        call setline(line('.'), l:working_line)
        let b:tab_complete_history[line('.')] = getline(line('.'))
        startinsert!
        echohl WarningMsg | echomsg "No completion found" | echohl None
        return
    endif

    call setline(line('.'), l:prompt . l:candidate)

    let b:tab_complete_history[line('.')] = getline(line('.'))

    startinsert!
endfunction"}}}

" implement <C-u>
" especially useful to clear a tab completion line already sent to pty
function! conque#kill_line()"{{{
  " send <C-u> to pty
  call b:proc.write("\<C-u>")

  " we are throwing away the output here, assuming <C-u> never fails to do as expected
  let l:hopefully_just_backspaces = conque#read_return_raw()

  " clear tab completion for this line
  if exists("b:tab_complete_history['".line('.')."']")
      call remove(b:tab_complete_history, line('.'))
  endif

  " restore empty prompt
  call setline(line('.'), b:prompt_history[line('.')])
  normal! G$
  startinsert!
endfunction"}}}

" implement <C-c>
" should send SIGINT to proc
function! conque#sigint()"{{{
  " send <C-c> to pty
  call b:proc.write("\<C-c>")
  call s:read()
endfunction"}}}

" implement <Esc>
" should send <Esc> to proc
" Useful if Vim is launched inside of conque
function! conque#escape()"{{{
  " send <Esc> to pty
  call b:proc.write("\<Esc>")
  call s:read()
endfunction"}}}


" vim: foldmethod=marker
