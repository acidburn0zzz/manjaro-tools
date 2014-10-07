#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

ignore_error() {
	"$@" 2>/dev/null
	return 0
}

# in_array() {
#   local i
#   for i in "${@:2}"; do
#     [[ $1 = "$i" ]] && return
#   done
# }

##
#  usage : in_array( $needle, $haystack )
# return : 0 - found
#          1 - not found
##
in_array() {
	local needle=$1; shift
	local item
	for item in "$@"; do
		[[ $item = $needle ]] && return 0 # Found
	done
	return 1 # Not Found
}

##
#  usage : get_full_version( [$pkgname] )
# return : full version spec, including epoch (if necessary), pkgver, pkgrel
##

# $1: sofile
# $2: soarch
process_sofile() {
	# extract the library name: libfoo.so
	local soname="${1%.so?(+(.+([0-9])))}".so
	# extract the major version: 1
	soversion="${1##*\.so\.}"
	if [[ "$soversion" = "$1" ]] && (($IGNORE_INTERNAL)); then
		continue
	fi
	if ! in_array "${soname}=${soversion}-$2" ${soobjects[@]}; then
		# libfoo.so=1-64
		msg "${soname}=${soversion}-$2"
		soobjects=(${soobjects[@]} "${soname}=${soversion}-$2")
	fi
}

get_full_version() {
	# set defaults if they weren't specified in buildfile
	pkgbase=${pkgbase:-${pkgname[0]}}
	epoch=${epoch:-0}
	if [[ -z $1 ]]; then
		if [[ $epoch ]] && (( ! $epoch )); then
			echo $pkgver-$pkgrel
		else
			echo $epoch:$pkgver-$pkgrel
		fi
	else
		for i in pkgver pkgrel epoch; do
			local indirect="${i}_override"
			eval $(declare -f package_$1 | sed -n "s/\(^[[:space:]]*$i=\)/${i}_override=/p")
			[[ -z ${!indirect} ]] && eval ${indirect}=\"${!i}\"
		done
		if (( ! $epoch_override )); then
			echo $pkgver_override-$pkgrel_override
		else
			echo $epoch_override:$pkgver_override-$pkgrel_override
		fi
	fi
}
