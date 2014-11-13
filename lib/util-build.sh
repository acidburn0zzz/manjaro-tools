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

ext='pkg.tar.xz'

ch_owner(){
    msg "chown -R [$pkg_owner:users] [$1]"
    chown -R "$pkg_owner:users" "$1"
}

sign_pkgs(){
    cd $pkgdir
    su $pkg_owner <<'EOF'
signpkgs
EOF
}

move_pkg(){
    msg2 "Moving [$1] to [${pkgdir}]"
    local 
    if [[ -n $PKGDEST ]];then
	mv $PKGDEST/*{any,$arch}.${ext} ${pkgdir}/
    else
	mv *.${ext} ${pkgdir}/
    fi
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
    fi
}

clean_up(){
    msg "Cleaning up ..."
    if [[ -n $LOGDEST ]];then
	msg2 "Cleaning logs $LOGDEST ..."
	rm $LOGDEST/*.log
    else
	msg2 "Cleaning logs $(pwd) ..."
	rm $(pwd)/*.log
    fi
    msg2 "Cleaning ${pkgdir} ..."
    rm ${pkgdir}/*.$ext
}

eval_profile(){
    eval "case ${profile} in
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
	[[ -d $copy ]] || continue
	msg2 "Deleting chroot copy '$(basename "${copy}")'..."

	lock 9 "$copy.lock" "Locking chroot copy '$copy'"

	if [[ "$(stat -f -c %T "${copy}")" == btrfs ]]; then
	    { type -P btrfs && btrfs subvolume delete "${copy}"; } &>/dev/null
	fi
	rm -rf --one-file-system "${copy}"
    done
    exec 9>&-
    
    rm -rf --one-file-system "$1"
}