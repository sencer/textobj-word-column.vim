if (exists("g:loaded_textobj_word_column"))
  finish
endif

call textobj#user#plugin('wordcolumn', {
            \ 'w' : {
            \   'select-i' : 'iv', '*select-i-function*' : 'textobj#word_column#select_iw',
            \   'select-a' : 'av', '*select-a-function*' : 'textobj#word_column#select_aw',
            \   },
            \ 'W' : {
            \   'select-i' : 'iV', '*select-i-function*' : 'textobj#word_column#select_iW',
            \   'select-a' : 'aV', '*select-a-function*' : 'textobj#word_column#select_aW',
            \   },
            \ })

let g:loaded_textobj_word_column = 1
