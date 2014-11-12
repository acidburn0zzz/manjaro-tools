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

	for pkg in "$dir"/*.pkg.tar?(.?z); do
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

get_cache_dirs(){
    local cache_dirs
    if [[ -z ${cache_dir} ]]; then
	cache_dirs=($(pacman -v 2>&1 | grep '^Cache Dirs:' | sed 's/Cache Dirs:\s*//g'))
    else
	cache_dirs=("${cache_dir}")
    fi
    echo ${cache_dirs[@]}
}

copy_hostconf () {

    cp -a /etc/pacman.d/gnupg "$1/etc/pacman.d"
    
    [[ -n $pac_conf ]] && cp $pac_conf "$1/etc/pacman.conf"
    [[ -n $makepkg_conf ]] && cp $makepkg_conf "$1/etc/makepkg.conf"
    [[ -n $mirrors_conf ]] && cp ${mirrors_conf} "$1/etc/pacman-mirrors.conf"
       
    local host_mirror=$(echo "$host_mirror" | sed -E "s#/branch/#/${branch}/#")
    echo "Server = $host_mirror" >"$1/etc/pacman.d/mirrorlist"
    sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n $(get_cache_dirs))|g" -i "$1/etc/pacman.conf"
}
