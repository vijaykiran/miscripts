# Based on http://muness.blogspot.com/2008/06/bash-dont-make-me-think.html
_bold=$(tput bold)
_normal=$(tput sgr0)

# http://gist.github.com/48207
function parse_git_deleted {
  [[ $(git status 2> /dev/null | grep deleted:) != "" ]] && echo "-"
}
function parse_git_added {
  [[ $(git status 2> /dev/null | grep "Untracked files:") != "" ]] && echo '+'
}
function parse_git_modified {
  [[ $(git status 2> /dev/null | grep modified:) != "" ]] && echo "*"
}
function git_state_indicators {
  echo "$(parse_git_added)$(parse_git_modified)$(parse_git_deleted)"
}

function git_divergence_indicator {
  git_status="$(git status 2> /dev/null)"
  remote_pattern="# Your branch is (.*) of"
  diverge_pattern="# Your branch and (.*) have diverged"
  if [[ ${git_status} =~ ${remote_pattern} ]]; then
    if [[ ${BASH_REMATCH[1]} == "ahead" ]]; then
      remote="↑"
    else
      remote="↓"
    fi
  fi
  if [[ ${git_status} =~ ${diverge_pattern} ]]; then
    remote="↕"
  fi
  echo $remote
}

function hg_branch_and_indicator {
	hg_branch="$(hg branch 2> /dev/null)"
	hg_id="$(hg id 2> /dev/null)"
	hg_status="$(hg status 2> /dev/null)"
	echo "${hg_branch} ${hg_id}"
}

function git_branch_and_indicator {
  git_status="$(git status 2> /dev/null)"
  branch_pattern="^# On branch ([^${IFS}]*)"
  if [[ ${git_status} =~ ${branch_pattern} ]]; then
    branch=${BASH_REMATCH[1]}
    echo "${branch}$_bold$(git_state_indicators)$(git_divergence_indicator)$_normal"
  fi
}

__prompt_command() {
	local vcs vcs_indicator base_dir sub_dir ref last_command
	sub_dir() {
		local sub_dir
		sub_dir=$(stat -f "${PWD}")
		sub_dir=${sub_dir#$1}
		echo ${sub_dir#/}
	}

	git_dir() {
		base_dir=$(git rev-parse --show-cdup 2>/dev/null) || return 1
		if [ -n "$base_dir" ]; then
			base_dir=`cd $base_dir; pwd`
		else
			base_dir=$PWD
		fi
		sub_dir=$(git rev-parse --show-prefix)
		sub_dir="/${sub_dir%/}"
    ref=$(git_branch_and_indicator)
		vcs='git'
		vcs_indicator=''
		alias pull='git pull'
		alias commit='git commit -v -a'
		alias push='commit ; git push'
		alias revert='git checkout'
	}

	svn_dir() {
		[ -d ".svn" ] || return 1
		base_dir="."
		while [ -d "$base_dir/../.svn" ]; do base_dir="$base_dir/.."; done
		base_dir=`cd $base_dir; pwd`
		sub_dir="/$(sub_dir "${base_dir}")"
		ref=`svnversion`
		vcs="svn"
		vcs_indicator="(svn)"
		alias pull="svn up"
		alias commit="svn commit"
		alias push="svn ci"
		alias revert="svn revert"
	}

	hg_dir() {
		base_dir=$(hg root 2>/dev/null) || return 1
		if [ -n "$base_dir" ]; then
			base_dir=`cd $base_dir; pwd`
		else
			base_dir=$PWD
		fi
		sub_dir="/$(sub_dir "${base_dir}")"
		# ref=$(hg id 2>/dev/null)
		ref=$(hg_branch_and_indicator)
		vcs="hg"
		vcs_indicator="(hg)"
		alias pull="hg pull"
		alias commit="hg commit"
		alias push="hg push"
		alias revert="hg revert"
	}


	git_dir || svn_dir || hg_dir

	if [ -n "$vcs" ]; then
		alias st="$vcs status"
		alias d="$vcs diff"
		alias up="pull"
		alias cdb="cd $base_dir"
		base_dir="$(basename "${base_dir}")"
        project="$base_dir:"
		__vcs_label="$vcs_indicator"
		__vcs_details="[$ref]"
		__vcs_sub_dir="${sub_dir}"
		__vcs_base_dir="${base_dir/$HOME/~}"
	else
		__vcs_label=''
		__vcs_details=''
		__vcs_sub_dir=''
		__vcs_base_dir="${PWD/$HOME/~}"
	fi

	last_command=$(history 5 | awk '{print $2}' | grep -v "^exit$" | tail -n 1)
	__tab_title="$project[$last_command]"
	__pretty_pwd="${PWD/$HOME/~}"
	hostname=`hostname -s`
}

PROMPT_COMMAND=__prompt_command
PS1='→ ${__vcs_label}\[$_bold\]${__vcs_base_dir}\[$_normal\]${__vcs_details}\[$_bold\]${__vcs_sub_dir}\[$_normal\]\$ '
