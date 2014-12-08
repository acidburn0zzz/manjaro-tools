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
    local var
    
    [[ -f $1 ]] || return 1

    for var in {SRC,SRCPKG,PKG,LOG}DEST MAKEFLAGS PACKAGER CARCH GPGKEY; do
	    [[ -z ${!var} ]] && eval $(grep "^${var}=" "$1")
    done
    
    return 0
}

load_config(){

    [[ -f $1 ]] || return 1
    
    local manjaro_tools_conf="$1"

    [[ -r ${manjaro_tools_conf} ]] && source ${manjaro_tools_conf}
    
    ######################
    # manjaro-tools common
    ######################
    
    if [[ -n ${branch} ]];then
	branch=${branch}
    else
	branch='stable'
    fi
    
    if [[ -n ${arch} ]]; then
	arch=${arch}
    else
	arch=$(uname -m)
    fi
    
    ###################
    # manjaro-tools-pkg
    ###################
    
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

    if [[ -n ${chroots} ]];then
	chroots=${chroots}
    else
	chroots='/srv/manjarobuild'
    fi
    
    if [[ -n ${pkg_dir} ]];then
	pkg_dir=${pkg_dir}
    else
	pkg_dir='/var/cache/manjaro-tools'
    fi
    
    if [[ -n ${blacklist_trigger[@]} ]];then
	blacklist_trigger=${blacklist_trigger[@]}
    else
	blacklist_trigger=('eudev' 'lib32-eudev' 'upower-pm-utils' 'eudev-systemdcompat' 'lib32-eudev-systemdcompat')
    fi
    
    if [[ -n ${blacklist[@]} ]];then
	blacklist=${blacklist[@]}
    else
	blacklist=('libsystemd')
    fi
    
    ###################
    # manjaro-tools-iso
    ###################
    
    if [[ -n ${work_dir} ]];then
	work_dir=${work_dir}
    else
	work_dir=${PWD}
    fi
    
    if [[ -n ${target_dir} ]];then
	target_dir=${target_dir}
    else
	target_dir=${PWD}
    fi
    
    if [[ -n ${iso_label} ]];then
	iso_label=${iso_label}
    else
	source /etc/lsb-release
	iso_label="MJRO0${DISTRIB_RELEASE//.}"
    fi

    if [[ -n ${iso_version} ]];then
	iso_version=${iso_version}
    else	
	source /etc/lsb-release
	iso_version=${DISTRIB_RELEASE}
    fi

    if [[ -n ${manjaro_kernel} ]];then
	manjaro_kernel=${manjaro_kernel}
    else
	manjaro_kernel="linux316"
    fi

    manjaro_kernel_ver=${manjaro_kernel#*linux}
    
    if [[ -n ${manjaro_version} ]];then
	manjaro_version=${manjaro_version}
    else
	manjaro_version=$(date +%Y.%m)
    fi
    
    if [[ -n ${manjaroiso} ]];then
	manjaroiso=${manjaroiso}
    else
	manjaroiso="manjaroiso"
    fi
    
    if [[ -n ${code_name} ]];then
	code_name=${code_name}
    else
	source /etc/lsb-release
	code_name="${DISTRIB_CODENAME}"
    fi
    
    if [[ -n ${img_name} ]];then
	img_name=${img_name}
    else
	img_name=manjaro
    fi
    
    if [[ -n ${hostname} ]];then
	hostname=${hostname}
    else
	hostname="manjaro"
    fi
    
    if [[ -n ${username} ]];then
	username=${username}
    else
	username="manjaro"
    fi
    
    if [[ -n ${install_dir} ]];then
	install_dir=${install_dir}
    else
	install_dir=manjaro
    fi
    
    if [[ -n ${plymouth_theme} ]];then
	plymouth_theme=${plymouth_theme}
    else
	plymouth_theme=manjaro-elegant
    fi
    
    if [[ -n ${compression} ]];then
	compression=${compression}
    else
	compression=xz
    fi
    
    return 0
}

load_pacman_conf(){
    if [[ -n ${pacman_conf} ]];then
	pacman_conf=${pacman_conf}
    else
	pacman_conf="$1"
    fi
}

load_sets(){
    local prof temp
    for item in $(ls ${profiledir}/*.set); do
	temp=${item##*/}
	prof=${prof:-}${prof:+|}${temp%.set}
    done
    echo $prof
}

load_desktop_definitions(){
    if [ -e Packages-Xfce ] ; then
	pkgsfile="Packages-Xfce"
    fi
    if [ -e Packages-Kde ] ; then
    	pkgsfile="Packages-Kde"
    fi
    if [ -e Packages-Gnome ] ; then
   	pkgsfile="Packages-Gnome" 
    fi
    if [ -e Packages-Cinnamon ] ; then
   	pkgsfile="Packages-Cinnamon" 
    fi
    if [ -e Packages-Openbox ] ; then
  	pkgsfile="Packages-Openbox"  
    fi
    if [ -e Packages-Lxde ] ; then
 	pkgsfile="Packages-Lxde"   
    fi
    if [ -e Packages-Lxqt ] ; then
    	pkgsfile="Packages-Lxqt"
    fi
    if [ -e Packages-Mate ] ; then
    	pkgsfile="Packages-Mate"
    fi
    if [ -e Packages-Enlightenment ] ; then
    	pkgsfile="Packages-Enlightenment"
    fi
    if [ -e Packages-Net ] ; then
   	pkgsfile="Packages-Net" 
    fi
    if [ -e Packages-PekWM ] ; then
	pkgsfile="Packages-PekWM"
    fi
    if [ -e Packages-Custom ] ; then
    	pkgsfile="Packages-Custom"
    fi
    desktop=${pkgsfile#*-}
    desktop=${desktop,,}
}