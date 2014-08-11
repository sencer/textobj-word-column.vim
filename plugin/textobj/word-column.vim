if (exists("g:loaded_textobj_word_column"))
  finish
endif

call textobj#user#plugin('wordcolumn', {
            \ 'w' : {
            \   'select-i' : 'ic', '*select-i-function*' : 'textobj#word_column#select_iw',
            \   'select-a' : 'ac', '*select-a-function*' : 'textobj#word_column#select_aw',
            \   },
            \ 'W' : {
            \   'select-i' : 'iC', '*select-i-function*' : 'textobj#word_column#select_iW',
            \   'select-a' : 'aC', '*select-a-function*' : 'textobj#word_column#select_aW',
            \   },
            \ })

let g:loaded_textobj_word_column = 1
