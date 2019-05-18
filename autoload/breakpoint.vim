" This is so my sign numbering (hopefully) doesn't collide
" with some other plugin
let g:breakpoint#counterOffset = 2000
let s:counter = g:breakpoint#counterOffset + 1


" retuns a string containing the name of the breakpoint file
function! s:get_breakpoint_file_path()
    let l:root = s:get_project_root()

    if l:root == ''
        echomsg 'No project root could be found. Defaulting to the current directory'
        return '.breakpoints'
    endif

	return l:root . '/.breakpoints'
endfunction


function! s:get_cmake_project_root()
    let l:directory = expand('%:p:h')
    let l:possible_root = ''

    while 1
        if !filereadable(l:directory . '/CMakeLists.txt')
            return l:possible_root
        endif

        let l:new_root = fnamemodify(l:directory, ':h')

        if l:new_root == l:directory
            " If this happens then it means we reached the root
            " filesystem No project root could be found
            "
            return ''
        endif

        let l:possible_root = l:directory
        let l:directory = l:new_root
    endwhile
endfunction


function! s:get_git_project_root()
    let l:directory = expand('%:p')

    while 1
        let l:possible_root = l:directory . '/.git'
        if isdirectory(l:possible_root) || filereadable(l:possible_root)
            return l:directory
        else
            let l:new_root = fnamemodify(l:directory, ':h')

            if l:new_root == l:directory
                " If this happens then it means we reached the root
                " filesystem No project root could be found
                "
                return ''
            endif

            let l:directory = l:new_root
        endif
    endwhile
endfunction


function! s:get_project_root()
    let l:root = s:get_cmake_project_root()

    if l:root != ''
        return l:root
    endif


    let l:root = s:get_git_project_root()
    return l:root
endfunction


function! s:read_breakpoint_lines(breakpoints_file_path)
    if !filereadable(a:breakpoints_file_path)
        return []
    endif

    let l:lines = []
    for l:line in readfile(a:breakpoints_file_path)
        if l:line !~? '^break\s\+.\+:\d\+$'
            continue
        endif

        let l:info = split(l:line, " ")[1]
        let l:file = split(l:info, ":")[0]
        let l:line_number = split(l:info, ":")[1]
        call add(l:lines, [file, l:line_number])
    endfor

    return l:lines
endfunction


" Places a breakpoint mark. Either at the current line at the number
" defined by the first argument.
" Return 1 if attempting to place outside valid range.
" Return 2 if a breakpoint already exists at that line
" Return 0 if successfully placed
function! breakpoint#place(...)
	let l:lnum = a:0 == 1 ? a:1 : line(".")
	" can't place breakpoint outside file
	if l:lnum > line("$") || l:lnum < 1
		return 1
	endif
	let l:fname = expand("%:p")

	" Make sure that no duplicate breakpoints exists in file
	let l:signs = execute(printf("sign place file=%s", l:fname))
	for line in split(l:signs, "\n")[2:]
		let [line, id, name, prio] = split(line, "  *")
		if name == "name=breakpoint" && split(line, "=")[1] == l:lnum
			return 2
		endif
	endfor

	execute printf(":sign place %d line=%d name=breakpoint file=%s",
				\ s:counter,
				\ l:lnum,
				\ l:fname)

	let s:counter += 1
	return 0
endfunction


" Remove the breakpoint at the cursors current line
" returns 1 if breakpoint was removed, 0 otherwise
" Takes one optional argument which is a line number, uses the
" current line if no number is given
function! breakpoint#remove(...)
	let l:lnum = a:0 == 1 ? a:1 : line(".")
	" can't place breakpoint outside file
	if l:lnum > line("$") || l:lnum < 1
		return 1
	endif
	let l:fname = expand("%:p")

	let l:signs = execute(printf("sign place file=%s", l:fname))

	for line in split(l:signs, "\n")[2:]
		let [line, id, name, prio] = split(line, "  *")
		if (name != "name=breakpoint")
			continue
		endif

		let l:cline = split(line, "=")[1]
		if (l:cline == l:lnum)
			execute printf(":sign unplace %d file=%s",
						\ split(id, "=")[1],
						\ l:fname)
			return 1
		endif

	endfor

	return 0
endfunction


function! breakpoint#toggle(...)
	if a:0 == 1
		if !breakpoint#remove(a:1)
			call breakpoint#place(a:1)
		endif
	else
		if !breakpoint#remove()
			call breakpoint#place()
		endif
	endif
endfunction


function! s:writelines(path, lines, file_path)
    let l:lines = []
    for [l:break_file_path, l:line_number] in s:read_breakpoint_lines(a:path)
        if l:break_file_path != a:file_path
            call add(l:lines, printf("break %s:%s", l:break_file_path, l:line_number))
        endif
    endfor

    call add(l:lines, '# START Auto-generated breakpoints')
    for l:line in a:lines
        call add(l:lines, l:line)
    endfor
    call add(l:lines, '# END Auto-generated breakpoints')

    call delete(a:path)
    if l:lines != []
        call writefile(l:lines, a:path)
    endif
endfunction


" saves to file if breakpoints are set
" deletes the file if no breakpoints exist
"
" Errors if trying to save breakpoints where it isn't allowed to.
" This is good.
function! breakpoint#save()
	let l:file_path = expand("%:p")
	let l:lines = []
	let l:signs = execute(printf("sign place file=%s", l:file_path))

	for line in split(l:signs, "\n")[2:]
		let [line, id, name, prio] = split(line, "  *")

		if (name != "name=breakpoint")
			continue
		endif

		let l:lines += [printf("break %s:%d",
            \ l:file_path,
            \ split(line, "=")[1])]
	endfor

    call s:writelines(s:get_breakpoint_file_path(), l:lines, l:file_path)
endfunction


" returns a -1 if file can't be read
" otherwise return number of breakpoints loaded
function! breakpoint#load()
    let l:current_file = expand('%:p')

    let l:breakpoint_file = s:get_breakpoint_file_path()
    for [l:file, l:line] in s:read_breakpoint_lines(l:breakpoint_file)
        if l:file != l:current_file
            continue
        endif

        call breakpoint#place(l:line)
    endfor
endfunction
