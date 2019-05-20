" re-sourcing guard
if exists("g:loaded_breakpoint")
	finish
endif
let g:loaded_breakpoint = 1

highlight Breakpoint ctermfg=Red

sign define breakpoint text=* texthl=Breakpoint

command! -count -bar BreakpointPlace
			\ call breakpoint#place(<count> ? <count> : line('.'))
command! -count -bar BreakpointRemove
			\ call breakpoint#remove(<count> ? <count> : line('.'))
command! -count -bar BreakpointToggle
			\ call breakpoint#toggle(<count> ? <count> : line('.'))
command! -bar BreakpointSetCommand call breakpoint#set_sign_command()
command! -bar BreakpointLoad call breakpoint#load()
command! -bar BreakpointSave call breakpoint#save()

nnoremap <Plug>BreakpointToggle :BreakpointToggle<cr>
