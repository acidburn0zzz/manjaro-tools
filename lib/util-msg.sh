#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

export LC_MESSAGES=C
export LANG=C

# check if messages are to be printed using color
unset ALL_OFF BOLD BLUE GREEN RED YELLOW
if [[ -t 2 ]]; then
	# prefer terminal safe colored and bold text when tput is supported
	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		BLUE="${BOLD}$(tput setaf 4)"
		GREEN="${BOLD}$(tput setaf 2)"
		RED="${BOLD}$(tput setaf 1)"
		YELLOW="${BOLD}$(tput setaf 3)"
	else
		ALL_OFF="\e[1;0m"
		BOLD="\e[1;1m"
		BLUE="${BOLD}\e[1;34m"
		GREEN="${BOLD}\e[1;32m"
		RED="${BOLD}\e[1;31m"
		YELLOW="${BOLD}\e[1;33m"
	fi
fi
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW

plain() {
	local mesg=$1; shift
	printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
	local mesg=$1; shift
	printf "${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
	local mesg=$1; shift
	printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

stat_busy() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}...${ALL_OFF}" >&2
}

stat_done() {
	printf "${BOLD}done${ALL_OFF}\n" >&2
}

setup_workdir() {
	[[ -z $WORKDIR ]] && WORKDIR=$(mktemp -d --tmpdir "${0##*/}.XXXXXXXXXX")
}

cleanup() {
	[[ -n $WORKDIR ]] && rm -rf "$WORKDIR"
	exit ${1:-0}
}

abort() {
	error 'Aborting...'
	cleanup 255
}

trap_abort() {
	trap - EXIT INT QUIT TERM HUP
	abort
}

trap_exit() {
	local r=$?
	trap - EXIT INT QUIT TERM HUP
	cleanup $r
}

die() {
	(( $# )) && error "$@"
	cleanup 255
}

lock() {
	eval "exec $1>"'"$2"'
	if ! flock -n $1; then
		stat_busy "$3"
		flock $1
		stat_done
	fi
}

slock() {
	eval "exec $1>"'"$2"'
	if ! flock -sn $1; then
		stat_busy "$3"
		flock -s $1
		stat_done
	fi
}

trap 'trap_abort' INT QUIT TERM HUP
trap 'trap_exit' EXIT

# get_colors() {
#     _r="\033[00;31m"
#     _y="\033[00;33m"
#     _g="\033[00;32m"
#     _b="\033[00;34m"
#     _B="\033[01;34m"
#     _W="\033[01;37m"
#     _n="\033[00;0m"
# }
# 
# banner() {
# 	echo -e "${_g}"
# 	echo "    _     _              _                  _             "
# 	echo "   | |   | |            (_)                (_)            "
# 	echo "   | | _ | | ____ ____   _  ____  ____ ___  _  ___  ___   "
# 	echo "   | || || |/ _  |  _ \ | |/ _  |/ ___) _ \| |/___)/ _ \  "
# 	echo "   | || || ( ( | | | | || ( ( | | |  | |_| | |___ | |_| | "
# 	echo "   |_||_||_|\_||_|_| |_|| |\_||_|_|   \___/|_(___/ \___/  "
# 	echo -e "${_g}                      (__/  ${_n}    v${isoversion}"
# 	echo -e "${_n}"
# }

title() {
	local mesg=$1; shift
	echo " "
	printf "\033[1;33m>>>\033[1;0m\033[1;1m ${mesg}\033[1;0m\n"
	echo " "
}

title2() {
	local mesg=$1; shift
	printf "\033[1;33m >>\033[1;0m\033[1;1m ${mesg}\033[1;0m\n"
}

# msg() {
# 	local mesg=$1; shift
# 	printf "\033[1;32m ::\033[1;0m\033[1;0m ${mesg}\033[1;0m\n"
# }

warning() {
	local mesg=$1; shift
	printf "\033[1;33m ::\033[1;0m\033[1;0m ${mesg}\033[1;0m\n"
}

error() {
	local mesg=$1; shift
	printf "\033[1;31m ::\033[1;0m\033[1;0m ${mesg}\033[1;0m\n"
}

exit2() {
    local mesg=$1; shift
    printf "\033[1;31m ::\033[1;0m\033[1;0m ${mesg}\033[1;0m\n"
    exit 1
}

newline() {
	echo " "
}

status_start() {
	local mesg=$1; shift
	echo -e -n "\033[1;32m ::\033[1;0m\033[1;0m ${mesg}\033[1;0m"
}

status_ok() {
	echo -e "\033[1;32m OK \033[1;0m"
}

status_done() {
	echo -e "\033[1;32m DONE \033[1;0m"
}

status_fail() {
	echo -e "\033[1;31m FAIL \033[1;0m"
}
