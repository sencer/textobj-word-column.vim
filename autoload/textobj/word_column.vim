function! textobj#word_column#select_iw()
    return s:select('iw')
endfunction

function! textobj#word_column#select_aw()
    return s:select('aw')
endfunction

function! textobj#word_column#select_iW()
    return s:select('iW')
endfunction

function! textobj#word_column#select_aW()
    return s:select('aW')
endfunction

function! s:create_col_obj(expr)
  let col_obj = {}
  let col_obj.vcol = virtcol(a:expr)
  let col_obj.bcol = col(a:expr)
  return col_obj
endf

function! s:min_col_obj(col_obj_1, col_obj_2)
  if a:col_obj_1.bcol < a:col_obj_2.bcol
    return a:col_obj_1
  else
    return a:col_obj_2
  endif
endf

function! s:max_col_obj(col_obj_1, col_obj_2)
  if a:col_obj_1.bcol > a:col_obj_2.bcol
    return a:col_obj_1
  else
    return a:col_obj_2
  endif
endf

function! s:select(textobj)
  let cursor_col = virtcol(".")
  exec "silent normal! v" . a:textobj . "\<Esc>"
  let col_bounds      = [s:create_col_obj("'<"), s:create_col_obj("'>")]
  let line_num        = line(".")

  if (exists("g:textobj_word_column_no_exact_boundary_cols"))
    let indent_level    = s:indent_level(".")

    let line_bounds     = []
    for step in [-1, 1]
      let line_bounds += [s:find_boundary_row(line_num, col_bounds[0], indent_level, step)]
    endfor

    let whitespace_only = s:whitespace_column_wanted(line_bounds[0], line_bounds[1], cursor_col)

    if (exists("g:textobj_word_column_no_smart_boundary_cols"))
      " Do nothing: keep use initial selection's col bounds.
    else
      let col_bounds.bcol = s:find_smart_boundary_cols(line_bounds[0], line_bounds[1], cursor_col, a:textobj, whitespace_only)
    endif
  else
    let [line_bounds, col_bounds] = s:find_rectangle(line_num, col_bounds, a:textobj)
    " Use smart boundary cols for 'around'.
    if a:textobj[0] == 'a'
      let whitespace_only = s:whitespace_column_wanted(line_bounds[0], line_bounds[1], cursor_col)
      let col_bounds = s:find_smart_boundary_cols(line_bounds[0], line_bounds[1], cursor_col, 'i'. a:textobj[1], whitespace_only)
    endif
  endif

  let [bufnum, _, _, off] = getpos('.')
  let result = ["\<C-v>"]
  for i in range(2)
    let result += [[bufnum, line_bounds[i], col_bounds[i].bcol, off]]
  endfor

  return result
endfunction

""""""""""""""""""""""""""""
"  New boundary discovery  "
""""""""""""""""""""""""""""

function! s:find_rectangle(start_line, col_bounds, textobj)
  " Check the surrounding lines for the same word boundaries.
  let r = s:check_matches_above(a:start_line, a:col_bounds)
  let has_start_match_above = r[0]
  let has_end_match_above = r[1]
  let has_exact_match_above = has_start_match_above && has_end_match_above

  let r = s:check_matches_after(a:start_line, a:col_bounds)
  let has_start_match_after = r[0]
  let has_end_match_after = r[1]
  let has_exact_match_after = has_start_match_after && has_end_match_after


  " When the line above or below has the same boundaries, find the matching
  " rectangle.
  if has_exact_match_above || has_exact_match_after
    return s:find_exact_rectangle(a:start_line, a:col_bounds)
  endif

  " We don't have exact matches above or below, so look for exact matches at
  if has_start_match_above || has_start_match_after
    return s:expand_to_find_rectangle(a:start_line, a:col_bounds, 0)
  elseif has_end_match_above || has_end_match_after
    return s:expand_to_find_rectangle(a:start_line, a:col_bounds, 1)
  endif

  " Fallback to current selection
  return [[a:start_line, a:start_line], a:col_bounds]
endf

function! s:find_exact_rectangle(start_line, col_bounds)
  let IsBoundaryAcceptableFn = s:create_both_check_fn()
  return s:find_rectangle_for_bounds(a:start_line, a:col_bounds, IsBoundaryAcceptableFn)
endf

function! s:expand_to_find_rectangle(start_line, col_bounds, bound_to_check)
  let IsBoundaryAcceptableFn = s:create_single_check_fn(a:bound_to_check)
  return s:find_rectangle_for_bounds(a:start_line, a:col_bounds, IsBoundaryAcceptableFn)
endf

function! s:create_single_check_fn(bound_idx)
  let bound_to_check = { 'bound_idx' : a:bound_idx }
  function! bound_to_check.eval(bounds) dict
    return a:bounds[self.bound_idx]
  endf

  return bound_to_check
endf

function! s:create_both_check_fn()
  let bound_to_check = { 'bound_idx' : 'both' }
  function! bound_to_check.eval(bounds) dict
    return a:bounds[0] && a:bounds[1]
  endf

  return bound_to_check
endf

function! s:find_rectangle_for_bounds(start_line, col_bounds, IsBoundaryAcceptableFn)
  let top    = s:find_rectangle_boundary_for_direction_and_bounds(a:start_line, a:col_bounds, -1, a:IsBoundaryAcceptableFn)
  let bottom = s:find_rectangle_boundary_for_direction_and_bounds(a:start_line, a:col_bounds, 1, a:IsBoundaryAcceptableFn)

  return [[top, bottom], a:col_bounds]
endf

function! s:find_rectangle_boundary_for_direction_and_bounds(start_line, col_bounds, delta, IsBoundaryAcceptableFn)
  let last_matching_line_num = a:start_line
  let r = [1,1]

  let test_line = last_matching_line_num
  while a:IsBoundaryAcceptableFn.eval(r)
    let last_matching_line_num = test_line
    let test_line = last_matching_line_num + a:delta
    let r = s:check_matches(last_matching_line_num, test_line, a:col_bounds)
  endwhile

  return last_matching_line_num
endf

function! s:is_valid_line(line_num)
  return 0 < a:line_num && a:line_num <= line('$')
endf

function! s:is_identical(ref_line, check_line, col_bounds)
  " Check if the column selection given by col_bounds is identical on both
  " input line numbers.
  "
  let ref_line = getline(a:ref_line)
  let check_line = getline(a:check_line)

  let char_bounds = [a:col_bounds[0].vcol - 1, a:col_bounds[1].vcol - 1]

  let ref_selection  = ref_line[char_bounds[0] : char_bounds[1]]
  let check_selection = check_line[char_bounds[0] : char_bounds[1]]

  return ref_selection ==# check_selection
endf

function! s:check_matches(ref_line, check_line, col_bounds)
  if s:is_valid_line(a:check_line)
    if s:is_identical(a:ref_line, a:check_line, a:col_bounds)
      " Handles symbols: requires them to be identical since they don't
      " every match word boundaries. Also looks for identical words which
      " seems useful.
      return [1,1]
    else
      let has_start_match = s:has_matching_start_boundary(a:check_line, a:col_bounds[0])
      let has_end_match = s:has_matching_end_boundary(a:check_line, a:col_bounds[1])
      return [has_start_match, has_end_match]
    endif
  else
    return [0,0]
  endif
endf

function! s:check_matches_above(start_line, col_bounds)
  let above_line = a:start_line - 1
  return s:check_matches(a:start_line, above_line, a:col_bounds)
endf

function! s:check_matches_after(start_line, col_bounds)
  let after_line = a:start_line + 1
  return s:check_matches(a:start_line, after_line, a:col_bounds)
endf

function! s:has_matching_boundaries(line_num, col_bounds)
  return s:has_matching_start_boundary(a:line_num, a:col_bounds[0]) && s:has_matching_end_boundary(a:line_num, a:col_bounds[1])
endf
function! s:has_matching_start_boundary(line_num, start_col)
  " Include the character before the column we're looking at. we want to see
  " the space or other word-boundary-breaking character before. 
  let check_col = a:start_col.vcol - 1
  let boundary_re = '^.\<.'
  if a:start_col.vcol == 1
    " Beginning of line won't have leading character. Make sure it's a word
    " boundary so we don't match every nonblank line.
    let boundary_re = '^\<.'
    let check_col = 1
  endif
  return s:has_matching_boundary(a:line_num, check_col, boundary_re)
endf
function! s:has_matching_end_boundary(line_num, end_col)
  let check_col = a:end_col.vcol
  let boundary_re = '^.\>.'
  if check_col == ( virtcol([a:line_num, "$"]) - 1 )
    " End of line won't have trailing character. Make sure it's a word
    " boundary so we don't match every nonblank line.
    let boundary_re = '^.\>'
  endif
  return s:has_matching_boundary(a:line_num, check_col, boundary_re)
endf
function! s:has_matching_boundary(line_num, col, boundary_re)
  let line = getline(a:line_num)
  if len(line) == 0
    " Empty lines never match
    return 0
  endif

  " Columns are one indexed but string index is zero indexed, so decrement
  " again.
  let re_col = a:col - 1
  if re_col >= 0
    return 0 <= match(line, a:boundary_re, re_col)
  endif

  return 0
endf


"""""""""""""""""""""""""""""""""
"  Original boundary discovery  "
"""""""""""""""""""""""""""""""""

function! s:find_smart_boundary_cols(start_line, stop_line, cursor_col, textobj, whitespace_only)
  let col_bounds = []
  let index      = a:start_line
  if a:whitespace_only
    let word_start = ""
    let s:col_bounds_fn = function("s:col_bounds_min")
  else
    let word_start = "lb"
    let s:col_bounds_fn = function("s:col_bounds_max")
  endif

  while index <= a:stop_line
    exec "keepjumps silent normal!" index . "gg" . a:cursor_col . "|" . word_start . "v" . a:textobj . "\<Esc>"
    let start_col  = s:create_col_obj("'<")
    let stop_col   = s:create_col_obj("'>")
    if len(col_bounds) == 0
      let col_bounds = [start_col, stop_col]
    else
      let col_bounds = s:col_bounds_fn(start_col, stop_col, col_bounds)
    endif
    let index      = index + 1
  endwhile

  return col_bounds
endfunction

function! s:col_bounds_max(start_col, stop_col, col_bounds)
  let a:col_bounds[0] = s:min_col_obj(a:start_col, a:col_bounds[0])
  let a:col_bounds[1] = s:max_col_obj(a:stop_col, a:col_bounds[1])
  return a:col_bounds
endfunction

function! s:col_bounds_min(start_col, stop_col, col_bounds)
  let a:col_bounds[0] = s:max_col_obj(a:start_col, a:col_bounds[0])
  let a:col_bounds[1] = s:min_col_obj(a:stop_col, a:col_bounds[1])
  return a:col_bounds
endfunction

function! s:whitespace_column_wanted(start_line, stop_line, cursor_col)
  let index = a:start_line
  let expanded_tabs = repeat(" ", &tabstop)
  while index <= a:stop_line
    let line = substitute(getline(index), "\t", expanded_tabs, "g")
    let char = line[a:cursor_col - 1]
    if char != " " && char != "\t"
      return 0
    end
    let index = index + 1
  endwhile
  return 1
endfunction

function! s:find_boundary_row(start_line, start_col, indent_level, step)
  let current_line = a:start_line
  let max_boundary = 0
  if a:step == 1
    let max_boundary = line("$")
  endif
  while current_line != max_boundary
    let next_line      = current_line + a:step
    let non_blank      = getline(next_line) =~ "[^ \t]"
    let same_indent    = s:indent_level(next_line) == a:indent_level
    let has_width      = getline(next_line) =~ '\%'. a:start_col.vcol .'v'
    let is_not_comment = ! s:is_comment(next_line, a:start_col.bcol)
    if same_indent && non_blank && has_width && is_not_comment
      let current_line = next_line
    else
      return current_line
    endif
  endwhile
  return max_boundary
endfunction

function! s:indent_level(line_num)
  let line = getline(a:line_num)
  return match(line, "[^ \t]")
endfunction

function! s:is_comment(line_num, column)
  return synIDattr(synIDtrans(synID(a:line_num, a:column, 1)),"name") == "Comment"
endfunction

" vim:set et sw=2 ts=2:
