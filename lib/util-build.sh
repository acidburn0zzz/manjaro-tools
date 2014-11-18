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

# clean_up(){
#     msg "Cleaning up ..."
#     
#     local query=$(find ${pkg_dir} -maxdepth 1 -name "*.*")
#     
#     [[ -n $query ]] && rm -v $query
#     
#     if [[ -z $LOGDEST ]];then
# 	query=$(find $PWD -maxdepth 2 -name '*.log')
# 	[[ -n $query ]] && rm -v $query
#     fi
#     
#     if [[ -z $SRCDEST ]];then
# 	query=$(find $PWD -maxdepth 2 -name '*.?z?')
# 	[[ -n $query ]] && rm -v $query
#     fi
# }
# 
# blacklist_pkg(){
#     local blacklist=('libsystemd') \
#     cmd=$(pacman -Q ${blacklist[@]} -r $1/root 2> /dev/null)
#     
#     if [[ -n $cmd ]] ; then
# 	chroot-run $1/root pacman -Rdd "${blacklist[@]}" --noconfirm
#     fi
# }
# 
# chroot_clean(){
#     for copy in "$1"/*; do
# 	[[ -d ${copy} ]] || continue
# 	msg2 "Deleting chroot copy '$(basename "${copy}")'..."
# 
# 	lock 9 "${copy}.lock" "Locking chroot copy '${copy}'"
# 
# 	if [[ "$(stat -f -c %T "${copy}")" == btrfs ]]; then
# 	    { type -P btrfs && btrfs subvolume delete "${copy}"; } &>/dev/null
# 	fi
# 	rm -rf --one-file-system "${copy}"
#     done
#     exec 9>&-
#     
#     rm -rf --one-file-system "$1"
# }
