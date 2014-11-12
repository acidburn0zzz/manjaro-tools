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
    msg "chown -R [$USER:users] [$1]"
    chown -R "$USER:users" "$1"
}

sign_pkgs(){
    cd $pkgdir
    su $USER <<'EOF'
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

move_pkg(){
    msg2 "Moving [$1] to [${pkgdir}]"
    local ext='pkg.tar.xz'
    mv *.${ext} ${pkgdir}/
}

# get_branch(){
#     local branch=${mirrors_conf##*-}
#     echo ${branch%.*}
# }