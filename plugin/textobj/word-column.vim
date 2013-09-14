if (exists("g:loaded_textobj_word_column"))
  finish
endif

if (!exists("g:skip_default_textobj_word_column_mappings"))
  xnoremap <silent> ac :<C-u>call textobj#word_column#select("aw")<cr>
  xnoremap <silent> aC :<C-u>call textobj#word_column#select("aW")<cr>
  xnoremap <silent> ic :<C-u>call textobj#word_column#select("iw")<cr>
  xnoremap <silent> iC :<C-u>call textobj#word_column#select("iW")<cr>
  onoremap <silent> ac :call textobj#word_column#select("aw")<cr>
  onoremap <silent> aC :call textobj#word_column#select("aW")<cr>
  onoremap <silent> ic :call textobj#word_column#select("iw")<cr>
  onoremap <silent> iC :call textobj#word_column#select("iW")<cr>
endif

let g:loaded_textobj_word_column = 1
