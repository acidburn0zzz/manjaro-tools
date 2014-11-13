#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

sign_pkgs(){
    cd $pkgdir
    su $1 <<'EOF'
signpkgs
EOF
}

move_pkg(){
    local ext='pkg.tar.xz'
    if [[ -n $PKGDEST ]];then
	mv $PKGDEST/*{any,$arch}.${ext} ${pkgdir}/
    else
	mv *.${ext} ${pkgdir}/
    fi
    chown -R "$1:users" "${pkgdir}"
}

get_profiles(){
    local prof= temp=
    for item in $(ls ${profiledir}/*.set);do
	temp=${item##*/}
	prof=${prof:-}${prof:+|}${temp%.set}
    done
    echo $prof
}

prepare_dir(){
    if ! [[ -d $1 ]];then
	mkdir -p $1
	msg "Creating $1"
	chown -R "$2:users" "$(dirname $1)"
    fi
}

clean_up(){
    msg "Cleaning up ..."
    local query=$(find ${pkgdir} -maxdepth 1 -name "*.*")
    if [[ -n $query ]];then
	rm -v $query
    fi
    if [[ -z $LOGDEST ]];then
	query=$(find $(pwd) -maxdepth 2 -name '*.log')
	if [[ -n $query ]];then
	  rm -v $query
	fi
    fi
    if [[ -z $SRCDEST ]];then
	query=$(find $(pwd) -maxdepth 2 -name '*.?z?')
	if [[ -n $query ]];then
	    rm -v $query
	fi
    fi
}

eval_profile(){
    eval "case $1 in
	    $(get_profiles)) is_profile=true ;;
	    *) is_profile=false ;;
	esac"
}

blacklist_pkg(){
    local blacklist=('libsystemd') cmd=$(pacman -Q ${blacklist[@]} -r $1/root 2> /dev/null)
    if [[ -n $cmd ]] ; then
	msg2 "Removing blacklisted [${blacklist[@]}] ..."
	pacman -Rdd "${blacklist[@]}" -r $1/root --noconfirm
    else
	msg2 "Blacklisted [${blacklist[@]}] not present."
    fi
}


chroot_clean(){
    for copy in "$1"/*; do
	[[ -d ${copy} ]] || continue
	msg2 "Deleting chroot copy '$(basename "${copy}")'..."

	lock 9 "${copy}.lock" "Locking chroot copy '${copy}'"

	if [[ "$(stat -f -c %T "${copy}")" == btrfs ]]; then
	    { type -P btrfs && btrfs subvolume delete "${copy}"; } &>/dev/null
	fi
	rm -rf --one-file-system "${copy}"
    done
    exec 9>&-
    
    rm -rf --one-file-system "$1"
}