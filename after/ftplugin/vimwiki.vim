augroup vimwiki
  if !exists('g:zettel_synced')
    let g:zettel_synced = 0
  else
    finish
  endif

  " g:zettel_dir is defined by vim_zettel
  if !exists('g:zettel_dir')
    let g:zettel_dir = vimwiki#vars#get_wikilocal('path') "VimwikiGet('path',g:vimwiki_current_idx)
  endif

  " make the Git branch used for synchronization configurable
  if !exists('g:vimwiki_sync_branch')
    let g:vimwiki_sync_branch = "HEAD"
  endif

  " enable disabling of Taskwarrior synchronization
  if !exists("g:sync_taskwarrior")
    let g:sync_taskwarrior = 1
  endif

  " don't try to start synchronization if the opend file is not in vimwiki
  " path
  let current_dir = expand("%:p:h")
  if !current_dir ==# fnamemodify(g:zettel_dir, ":h")
    finish
  endif

  if !exists('g:vimwiki_sync_commit_message')
    let g:vimwiki_sync_commit_message = 'Auto commit %c'
  endif

  " don't sync temporary wiki
  if vimwiki#vars#get_wikilocal('is_temporary_wiki') == 1
    finish
  endif
  

  " execute vim function. because vimwiki can be started from any directory,
  " we must use pushd and popd commands to execute git commands in wiki root
  " dir. silent is used to disable necessity to press <enter> after each
  " command. the downside is that the command output is not displayed at all.
  " One idea: what about running git asynchronously?
  function! s:git_action(action)
    execute ':silent !' . a:action 
    " prevent screen artifacts
    redraw!
  endfunction

  function! My_exit_cb(channel,msg )
    echom "[vimiwiki sync] Sync done"
    execute 'checktime' 
  endfunction

  function! My_close_cb(channel)
    " it seems this callback is necessary to really pull the repo
  endfunction


  " pull changes from git origin and sync task warrior for taskwiki
  " using asynchronous jobs
  " we should add some error handling
  function! s:pull_changes()
    if g:zettel_synced==0
      echom "[vimwiki sync] pulling changes"
      let g:zettel_synced = 1
      if has("nvim")
        let gitjob = jobstart("git -C " . g:zettel_dir . " pull origin " . g:vimwiki_sync_branch, {"exit_cb": "My_exit_cb", "close_cb": "My_close_cb"})
        if g:sync_taskwarrior==1
          let taskjob = jobstart("task sync")
        endif
      else
        let gitjob = job_start("git -C " . g:zettel_dir . " pull origin " . g:vimwiki_sync_branch, {"exit_cb": "My_exit_cb", "close_cb": "My_close_cb"})
        if g:sync_taskwarrior==1
          let taskjob = job_start("task sync")
        endif
      endif
    endif
  endfunction


  " save buffer, commit and push changes
  function! s:save_and_push()
    execute ':silent write'
    call <sid>git_action("git -C " . g:zettel_dir . " add . && git -C " . g:zettel_dir . " commit -m \"" . strftime(g:vimwiki_sync_commit_message) . "\" ")
    call <sid>git_action("git -C " . g:zettel_dir . " push origin " . g:vimwiki_sync_branch . " >/home/nik/wikidebug.log 2>&1 &")
  endfunction

  " sync changes at the start
  au! VimEnter * call <sid>pull_changes()
  au! BufRead * call <sid>pull_changes()
  au! BufEnter * call <sid>pull_changes()

  autocmd CursorHold * call <sid>save_and_push()
  au! VimLeave * call <sid>save_and_push()
  au! BufWritePost * call <sid>save_and_push()
augroup END
