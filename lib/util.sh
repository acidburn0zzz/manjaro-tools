#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

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

##
#  usage : get_full_version( [$pkgname] )
# return : full version spec, including epoch (if necessary), pkgver, pkgrel
##
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

##
#  usage: find_cached_package( $pkgname, $pkgver, $arch )
#
#    $pkgver can be supplied with or without a pkgrel appended.
#    If not supplied, any pkgrel will be matched.
##
find_cached_package() {
    local searchdirs=("$PWD" "$PKGDEST") results=()
    local targetname=$1 targetver=$2 targetarch=$3
    local dir pkg pkgbasename pkgparts name ver rel arch size r results

    for dir in "${searchdirs[@]}"; do
	[[ -d $dir ]] || continue

	for pkg in "$dir"/*.pkg.tar.xz; do
	    [[ -f $pkg ]] || continue

	    # avoid adding duplicates of the same inode
	    for r in "${results[@]}"; do
		[[ $r -ef $pkg ]] && continue 2
	    done

	    # split apart package filename into parts
	    pkgbasename=${pkg##*/}
	    pkgbasename=${pkgbasename%.pkg.tar?(.?z)}

	    arch=${pkgbasename##*-}
	    pkgbasename=${pkgbasename%-"$arch"}

	    rel=${pkgbasename##*-}
	    pkgbasename=${pkgbasename%-"$rel"}

	    ver=${pkgbasename##*-}
	    name=${pkgbasename%-"$ver"}

	    if [[ $targetname = "$name" && $targetarch = "$arch" ]] &&
			    pkgver_equal "$targetver" "$ver-$rel"; then
		results+=("$pkg")
	    fi
	done
    done

    case ${#results[*]} in
	    0)
		return 1
	    ;;
	    1)
		printf '%s\n' "$results"
		return 0
	    ;;
	    *)
		error 'Multiple packages found:'
		printf '\t%s\n' "${results[@]}" >&2
		return 1
	    ;;
    esac
}

##
# usage: pkgver_equal( $pkgver1, $pkgver2 )
##
pkgver_equal() {
	local left right

	if [[ $1 = *-* && $2 = *-* ]]; then
		# if both versions have a pkgrel, then they must be an exact match
		[[ $1 = "$2" ]]
	else
		# otherwise, trim any pkgrel and compare the bare version.
		[[ ${1%%-*} = "${2%%-*}" ]]
	fi
}

check_root() {
    (( EUID == 0 )) && return
    if type -P sudo >/dev/null; then
	exec sudo -- "$@"
    else
	exec su root -c "$(printf ' %q' "$@")"
    fi
}

load_vars() {
    local mpkg_conf="$1" var

    [[ -f $mpkg_conf ]] || return 1

    for var in {SRC,SRCPKG,PKG,LOG}DEST MAKEFLAGS PACKAGER CARCH GPGKEY; do
	    [[ -z ${!var} ]] && eval $(grep "^${var}=" "$mpkg_conf")
    done

    return 0
}

load_config(){
    manjaro_tools_conf="$1/manjaro-tools.conf"

    [[ -r ${manjaro_tools_conf} ]] && source ${manjaro_tools_conf}

    if [[ -n ${profiledir} ]];then
	profiledir=${profiledir}
    else
	profiledir="$1/sets"
    fi

    if [[ -n ${profile} ]];then
	profile=${profile}
    else
	profile='default'
    fi

    if [[ -n ${branch} ]];then
	branch=${branch}
    else
	branch='stable'
    fi

    if [[ -n ${chroots} ]];then
	chroots=${chroots}
    else
	chroots='/srv/manjarobuild'
    fi
    
    if [[ -n ${pkgdir} ]];then
	pkgdir=${pkgdir}
    else
	pkgdir='/var/cache/manjaro-tools/pkg'
    fi
}

load_sets(){
    local prof= temp=
    for item in $(ls ${profiledir}/*.set);do
	temp=${item##*/}
	prof=${prof:-}${prof:+|}${temp%.set}
    done
    echo $prof
}

prepare_dir(){
    mkdir -p "${pkgdir}"
    chown -R "$1:users" "$(dirname ${pkgdir})"
}