#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

mv_profile_pkgs(){
    for pkg in $(cat ${profiledir}/$1.set); do
	mv_pkg $pkg
    done
}

mv_pkg(){
    msg2 "Copying $1 to ${pkgdir}"
    cd $1
    mv -v *.pkg.tar.xz ${pkgdir}
    cd ..
}

mv_pkgs(){
    msg "Copying packages ..."
    if ${is_profile};then
	mv_profile_pkgs ${profile}
    else
	mv_pkg ${profile}
    fi
    msg "Finished copying"
}

repo_create(){
    for p in ${pkgdir}/*.pkg.tar.xz; do
	ln -sv $p ${repodir}/$p
    done
    repo-add ${repodir##*/}.db.tar.xz *.pkg.tar.xz
}

if ! ${pretend};then

    mv_pkgs ${profile}

    if ${repo}; then
	cd ${pkgdir}
	repo_create
	cd ..
    fi

    if ${sign}; then
	cd ${pkgdir}
	signpkgs
	cd ..
    fi

fi
