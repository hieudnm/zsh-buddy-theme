#!/usr/bin/env zsh
# Zsh Buddy Theme test suite.
#
#   zsh tests/run.zsh
#
# Pure zsh, no dependencies besides git. Runs the theme in an isolated $HOME so
# nothing on the machine is touched. Exit code is the number of failed checks.

ROOT="${0:A:h:h}"
typeset -gi PASS=0 FAIL=0

section() { print; print "== $1"; }
ok()      { (( PASS++ )); print "  ok    $1"; }
fail()    { (( FAIL++ )); print "  FAIL  $1"; [[ -n "$2" ]] && print "        $2"; }

assert_eq()       { [[ "$1" == "$2" ]] && ok "$3" || fail "$3" "expected [$2], got [$1]"; }
assert_contains() { [[ "$1" == *"$2"* ]] && ok "$3" || fail "$3" "[$1] does not contain [$2]"; }
assert_absent()   { [[ "$1" != *"$2"* ]] && ok "$3" || fail "$3" "[$1] must not contain [$2]"; }
# assert_true / assert_false take a snippet of zsh code as a string
assert_true()     { eval "$1" && ok "$1" || fail "$1" "expected success"; }
assert_false()    { eval "$1" && fail "! $1" "expected failure" || ok "! $1"; }

# ---------------------------------------------------------------------------
# Isolated environment
export HOME="$(mktemp -d)"
mkdir -p "$HOME/.troll_themer/lang"
cp "$ROOT/.troll_themer/config" "$HOME/.troll_themer/config"
cp "$ROOT/.troll_themer/lang/"*.txt "$HOME/.troll_themer/lang/"
unset TROLL_LANG TROLL_MODE VIRTUAL_ENV GIT_DIR
unset -m 'ZBT_*'
export ZBT_UPDATE_CHECK=false
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

section "load theme"
source "$ROOT/.zshrc"
assert_eq "$?" 0 "sourcing .zshrc succeeds"
assert_true '(( ${#MESSAGES} > 50 ))'
assert_eq "$CURRENT_LANG" "vi" "default language is vi"

# ---------------------------------------------------------------------------
section "config loader"
cat > "$HOME/.troll_themer/config" <<'EOF'
# comment line
TROLL_LANG="en"   # trailing comment
ZBT_TROLL_INTERVAL=600
ZBT_TROLL_CHANCE='50'
ZBT_OVERTIME_START="18:00"
PATH=/should/not/be/touched
ZBT_EMPTY=""
EOF
unset TROLL_LANG ZBT_TROLL_INTERVAL ZBT_OVERTIME_START ZBT_EMPTY
export ZBT_TROLL_CHANCE=5
_zbt_load_config
assert_eq "$TROLL_LANG" "en"            "quoted value with trailing comment"
assert_eq "$ZBT_TROLL_INTERVAL" "600"   "unquoted value"
assert_eq "$ZBT_TROLL_CHANCE" "5"       "environment variable beats config file"
assert_eq "$ZBT_OVERTIME_START" "18:00" "value containing a colon"
assert_absent "$PATH" "/should/not"     "non-whitelisted keys are ignored"
assert_eq "${ZBT_EMPTY-unset}" "unset"  "empty values are ignored"
load_language_config
assert_eq "$REPLY" "en" "load_language_config reflects TROLL_LANG"
unset TROLL_LANG ZBT_TROLL_INTERVAL ZBT_TROLL_CHANCE ZBT_OVERTIME_START
load_language_config
assert_eq "$REPLY" "vi" "load_language_config falls back to vi"

printf 'TROLL_LANG="en"\r\n' > "$HOME/.troll_themer/config"
_zbt_load_config
assert_eq "$TROLL_LANG" "en" "CRLF config file"
unset TROLL_LANG

# ---------------------------------------------------------------------------
section "version_gt"
assert_true  'version_gt 1.4.1 1.4.0'
assert_false 'version_gt 1.4.0 1.4.0'
assert_true  'version_gt 2.0 1.9.9'
assert_true  'version_gt 1.10.0 1.9.0'
assert_false 'version_gt 1.9.0 1.10.0'

# ---------------------------------------------------------------------------
section "history filter and hooks"
zshaddhistory $'definitely_not_a_command_xyz\n'; assert_eq "$?" 2 "unknown command is kept out of the history file"
zshaddhistory $'echo hi\n';                      assert_eq "$?" 0 "known command is recorded"
zshaddhistory $'FOO=bar\n';                      assert_eq "$?" 0 "assignment is recorded"
zshaddhistory $'\n';                             assert_eq "$?" 0 "empty line is accepted"
assert_false 'functions precmd  >/dev/null'
assert_false 'functions preexec >/dev/null'
zshaddhistory $'ls\n';                           assert_eq "$?" 0 "single-word command is recorded"
assert_true  '(( ${precmd_functions[(I)_zbt_precmd]} ))'
assert_true  '(( ${preexec_functions[(I)_zbt_preexec]} ))'
REPLY=keep-me
_zbt_preexec "echo"; _zbt_precmd
assert_eq "$REPLY" "keep-me" "hooks do not clobber the user's \$REPLY"
# zsh runs preexec hooks for every top-level line of this script too; from here
# on the hooks are called explicitly where a test needs them.
add-zsh-hook -d preexec _zbt_preexec
add-zsh-hook -d precmd  _zbt_precmd

# ---------------------------------------------------------------------------
section "troll_cmd word matching"
_get_message cmd_ls;         typeset msg_ls="$REPLY"
_get_message cmd_cd;         typeset msg_cd="$REPLY"
_get_message cmd_git_commit; typeset msg_commit="$REPLY"
assert_contains "$(troll_cmd 'ls -la')"           "$msg_ls"     "ls -la"
assert_contains "$(troll_cmd 'cd x && ls')"       "$msg_cd"     "first word wins in a compound command"
assert_contains "$(troll_cmd 'git  commit -m x')" "$msg_commit" "extra spaces are tolerated"
assert_eq "$(troll_cmd 'tools')"      "" "tools does not match ls"
assert_eq "$(troll_cmd 'false')"      "" "false does not match ls"
assert_eq "$(troll_cmd 'update')"     "" "update does not match date"
assert_eq "$(troll_cmd 'git stash')"  "" "git stash does not match git st"
assert_eq "$(troll_cmd 'locate foo')" "" "locate does not match cat"

# ---------------------------------------------------------------------------
section "troll_by_time"
ZBT_OVERTIME_START=00:00 ZBT_OVERTIME_END=23:59
assert_true '[[ -n "$(troll_by_time)" ]]'
ZBT_OVERTIME_START=25:00 ZBT_OVERTIME_END=25:01 ZBT_TROLL_CHANCE=0
assert_eq "$(troll_by_time)" "" "outside window with 0% chance prints nothing"
assert_true '[[ -n "$(troll_by_time true)" ]]'
unset ZBT_OVERTIME_START ZBT_OVERTIME_END ZBT_TROLL_CHANCE

# ---------------------------------------------------------------------------
section "timer"
_zbt_now_ms; typeset t1=$REPLY
assert_true '[[ "$t1" == <-> ]]'
_zbt_now_ms; typeset t2=$REPLY
assert_true '(( t2 >= t1 ))'

# ---------------------------------------------------------------------------
section "git info"
typeset work="$(mktemp -d)" remote="$(mktemp -d)"
cd "$work"
_zbt_git_info
assert_eq "$REPLY" "" "no output outside a repository"
assert_false '_zbt_in_git_repo'

git init -q -b main . 2>/dev/null || { git init -q . && git checkout -q -b main; }
assert_true '_zbt_in_git_repo'
mkdir -p sub/dir && cd sub/dir
assert_true '_zbt_in_git_repo'
cd "$work"

_zbt_git_info
assert_contains "$REPLY" "(main)" "branch shown before the first commit"
assert_contains "$REPLY" "%F{"    "prompt escapes are used"
assert_absent   "$REPLY" $'\e'    "no raw ANSI escapes"

print a > a.txt && git add a.txt && git commit -q -m one
_zbt_git_info
assert_eq "$REPLY" "%F{10}🌿(main)%f" "clean repository"

print b > b.txt
_zbt_git_info
assert_eq "$REPLY" "%F{9}🌟(main*)%f" "untracked file marks the repo dirty"
ZBT_GIT_UNTRACKED=false _zbt_git_info
assert_eq "$REPLY" "%F{10}🌿(main)%f" "ZBT_GIT_UNTRACKED=false ignores untracked files"
ZBT_COLOR_GIT_DIRTY=red _zbt_git_info
assert_eq "$REPLY" "%F{red}🌟(main*)%f" "custom color"
ZBT_GIT_SHOW=false _zbt_git_info
assert_eq "$REPLY" "" "ZBT_GIT_SHOW=false hides the block"
rm b.txt

git init -q --bare "$remote"
git remote add origin "$remote" && git push -q -u origin main 2>/dev/null
print c > c.txt && git add c.txt && git commit -q -m two
_zbt_git_info
assert_eq "$REPLY" "%F{10}🌿(main ⇡1)%f" "one commit ahead of upstream"
git push -q origin main 2>/dev/null
git reset -q --hard HEAD~1
_zbt_git_info
assert_eq "$REPLY" "%F{10}🌿(main ⇣1)%f" "one commit behind upstream"
ZBT_GIT_AHEAD_BEHIND=false _zbt_git_info
assert_eq "$REPLY" "%F{10}🌿(main)%f" "ZBT_GIT_AHEAD_BEHIND=false hides the counters"
git pull -q origin main 2>/dev/null

git checkout -q -b '50%done'
_zbt_git_info
assert_eq "$REPLY" "%F{10}🌿(50%%done)%f" "percent sign in branch name is escaped for the prompt"
git checkout -q main

git checkout -q --detach
_zbt_git_info
typeset short="$(git rev-parse --short HEAD)"
assert_contains "$REPLY" "($short)" "detached HEAD shows the short hash"
git checkout -q main

# ---------------------------------------------------------------------------
section "prompt hooks"
_zbt_preexec "sleep 0"
_zbt_precmd
assert_absent "$PS1" $'\e' "PS1 has no raw ANSI escapes"
# Compare the git segment exactly: glob substring matching across 4-byte emoji
# is unreliable on some zsh builds (MSYS/Windows), exact comparison is not.
typeset seg="${PS1#*  }"; seg="${seg%%$'\n'*}"
assert_eq "$seg" "%F{10}🌿(main)%f" "PS1 contains the git block"
assert_true '[[ "$RPROMPT" == "%F{cyan}["<->"ms]%f" ]]'
ZBT_EXEC_TIME_MIN_MS=999999
_zbt_preexec "sleep 0"; _zbt_precmd
assert_eq "$RPROMPT" "" "ZBT_EXEC_TIME_MIN_MS hides fast commands"
unset ZBT_EXEC_TIME_MIN_MS
_zbt_precmd
assert_eq "$RPROMPT" "" "no timer without a preceding command"

VIRTUAL_ENV=/tmp/venvs/my%env _zbt_venv_info
assert_eq "$REPLY" "%F{11}🐍 (my%%env)%f" "virtualenv block with escaped percent"
unset VIRTUAL_ENV; _zbt_venv_info
assert_eq "$REPLY" "" "no virtualenv block when inactive"

cd "$ROOT"

# ---------------------------------------------------------------------------
print
print "passed: $PASS   failed: $FAIL"
exit $FAIL
