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

shopt -s nullglob

ch_owner(){
    msg "chown -R [$(get_user):users] [$1]"
    chown -R "$(get_user):users" "$1"
}

sign_pkgs(){
    cd $pkgdir
    su $(get_user) <<'EOF'
signpkgs
EOF
}

get_profiles(){
    local prof= temp=
    for item in $(ls ${profiledir}/*.set);do
	temp=${item##*/}
	prof=${prof:-}${prof:+|}${temp%.set}
    done
    echo $prof
}

get_user(){
    echo $(ls ${chrootdir} | cut -d' ' -f1 | grep -v root | grep -v lock)
}

prepare_dir(){
    if ! [[ -d $1 ]];then
	mkdir -p $1
    fi
}

clean_dir(){
    msg2 "Cleaning $1 ..."
    rm -r $1/*
}

git_clean(){
    msg2 "Cleaning $(pwd) ..."
    git clean -dfx$1
}

####chroot controller######

# chroot_clean(){
#     for copy in "${chrootdir}"/*; do
# 	[[ -d "${copy}" ]] || continue
# 	msg2 "Deleting chroot copy '$(basename "${copy}")'..."
# 
# 	exec 9>"${copy}.lock"
# 	if ! flock -n 9; then
# 	    stat_busy "Locking chroot copy '${copy}'"
# 	    flock 9
# 	    stat_done
# 	fi
# 
# 	if [[ "$(stat -f -c %T "${copy}")" == btrfs ]]; then
# 	    { type -P btrfs && btrfs subvolume delete "${copy}"; } &>/dev/null
# 	fi
# 	rm -rf --one-file-system "${copy}"
#     done
#     exec 9>&-
# 
#     rm -rf --one-file-system "${chrootdir}"
# }
# 
# chroot_create(){
#     mkdir -p "${chrootdir}"
#     setarch "${arch}" \
# 	mkchroot ${mkchroot_args[*]} ${chrootdir}/root ${base_packages[*]} || abort
# }
# 
# chroot_init(){
#       if [[ -e ${chrootdir} ]]; then
# 	  msg "Creating chroot for [${branch}] (${arch})..."
# 	  chroot_clean
# 	  chroot_create
#       else
# 	  msg "Creating chroot for [${branch}] (${arch})..."
# 	  chroot_create
#       fi
# }

chroot_build(){
    if ${is_profile};then
	msg "Start building profile: [${profile}]"
	for pkg in $(cat ${profiledir}/${profile}.set); do
	    cd $pkg
	    if [[ $pkg == 'eudev' ]] || [[ $pkg == 'lib32-eudev' ]]; then
		blacklist_pkg
	    fi
	    setarch "${arch}" \
		mkchrootpkg ${mkchrootpkg_args[*]} -- "${makepkg_args[*]}" || break
	    move_pkg "${pkg}"
	    cd ..
	done
	msg "Finished building profile: [${profile}]"
    else
	cd ${profile}
	if [[ ${profile} == 'eudev' ]] || [[ ${profile} == 'lib32-eudev' ]]; then
	    blacklist_pkg
	fi
	setarch "${arch}" \
	    mkchrootpkg ${mkchrootpkg_args[*]} -- "${makepkg_args[*]}" || abort
	move_pkg "${profile}"
	cd ..
    fi
}

####end chroot controller######

eval_profile(){
    eval "case ${profile} in
	    $(get_profiles)) is_profile=true ;;
	    *) is_profile=false ;;
	esac"
}

blacklist_pkg(){
    local blacklist=('libsystemd') cmd=$(pacman -Q ${blacklist[@]} -r ${chrootdir}/root 2> /dev/null)
    if [[ -n $cmd ]] ; then
	msg2 "Removing blacklisted [${blacklist[@]}] ..."
	setarch "${arch}" pacman -Rdd "${blacklist[@]}" -r ${chrootdir}/root --noconfirm
    else
	msg2 "Blacklisted [${blacklist[@]}] not present."
    fi
}

# install_pkg(){
#     msg2 "Installing built package ..."
#     setarch "${arch}" pacman -U *pkg*z -r ${chrootdir}/$(get_user) --noconfirm
# }

move_pkg(){
    msg2 "Moving [$1] to [${pkgdir}]"
    local ext='pkg.tar.xz'
    mv *.${ext} ${pkgdir}/
}
