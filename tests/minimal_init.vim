set rtp+=.

let s:plenary = finddir('plenary.nvim', stdpath('data') . '/**5')
if s:plenary == ''
  echoerr 'plenary.nvim not found under ' . stdpath('data')
  quit
endif
execute 'set rtp+=' . fnameescape(fnamemodify(s:plenary, ':p'))

runtime plugin/plenary.vim
