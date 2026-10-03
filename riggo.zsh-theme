setopt prompt_subst

RESET_CLR="%f"
RUN_CLR="%F{#3ba5ff}"
USER_CLR="%F{#fc0384}"
MACHINE_CLR="%F{#c5c2d1}"
GIT_CLR="%F{#fcba03}"
GIT_DIRTY_CLR="%F{#ff5555}"
GIT_CLEAN_CLR="%F{#8ff586}"
TIMER_CLR="%F{#888888}"
UNSTAGED_CLR="%F{#ffaa00}"
MIN_DURATION=0

autoload -Uz add-zsh-hook
zmodload zsh/datetime

riggo_git_prompt() {
  local branch clr mark
  branch=$(command git symbolic-ref --short HEAD 2>/dev/null) || \
    branch=$(command git rev-parse --short HEAD 2>/dev/null) || return
  if [[ -n $riggo_dirty ]]; then
    clr="$GIT_DIRTY_CLR"
    mark="✦"
  else
    clr="$GIT_CLEAN_CLR"
    mark="✓"
  fi
  print -rn -- "[${GIT_CLR}git:${clr}${branch:l} ${mark}] "
}

riggo_git_status() {
  riggo_dirty=""
  riggo_unstaged=0
  riggo_in_repo=0
  local out line
  out=$(command git status --porcelain --ignore-submodules 2>/dev/null) || return
  riggo_in_repo=1
  [[ -n $out ]] || return
  riggo_dirty=1
  for line in ${(f)out}; do
    [[ ${line[2]} != ' ' ]] && (( riggo_unstaged++ ))
  done
}

riggo_format_duration() {
  local -F d=$1
  local -i h=$(( d / 3600 ))
  local -i m=$(( (d % 3600) / 60 ))
  local -F s=$(( d % 60 ))
  if (( h )); then
    printf '%dh %dm %.0fs' $h $m $s
  elif (( m )); then
    printf '%dm %.0fs' $m $s
  else
    printf '%.2fs' $s
  fi
}

riggo_pad() {
  (( riggo_timer_len )) || return
  local dir=${PWD/#$HOME/~}
  local left="[${USER}@${${HOST:-localhost}%%.*}:${dir}]"
  local pad=$(( COLUMNS - ${#left} - riggo_timer_len - 1 ))
  (( pad < 1 )) && pad=1
  printf '%*s' $pad ''
}

riggo_preexec() {
  riggo_cmd_start=$EPOCHREALTIME
}

riggo_precmd() {
  local -F elapsed
  riggo_timer=""
  riggo_timer_len=0
  if [[ -n $riggo_cmd_start ]]; then
    elapsed=$(( EPOCHREALTIME - riggo_cmd_start ))
    unset riggo_cmd_start
    if (( elapsed >= MIN_DURATION )); then
      local dur=$(riggo_format_duration $elapsed)
      riggo_timer="${TIMER_CLR}${dur}%f"
      riggo_timer_len=${#dur}
    fi
  fi
  riggo_git_status
  if (( ! riggo_in_repo )); then
    RPS1=""
  elif (( riggo_unstaged )); then
    local noun="files"
    (( riggo_unstaged == 1 )) && noun="file"
    RPS1="${UNSTAGED_CLR}${riggo_unstaged} ${noun} unstaged%f "
  else
    RPS1="${GIT_CLEAN_CLR}clean%f "
  fi
}

add-zsh-hook preexec riggo_preexec
add-zsh-hook precmd riggo_precmd

PROMPT='[${USER_CLR}%n${MACHINE_CLR}@%m:${RESET_CLR}%~]$(riggo_pad)${riggo_timer}'$'\n''$(riggo_git_prompt)'"${RUN_CLR}"'run:%f '
