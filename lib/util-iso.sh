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


# $1: source image
# $2: target image
copy_userconfig(){	
    msg2 "Copying $1/etc/skel/. $2/etc/skel"
    cp -a --no-preserve=ownership $1/etc/skel/. $2/etc/skel
}

copy_initcpio(){
        cp /usr/lib/initcpio/hooks/miso* ${work_dir}/boot-image/usr/lib/initcpio/hooks
        cp /usr/lib/initcpio/install/miso* ${work_dir}/boot-image/usr/lib/initcpio/install
        cp mkinitcpio.conf ${work_dir}/boot-image/etc/mkinitcpio-${manjaroiso}.conf
}

copy_overlay(){
    msg2 "Copying overlay to $1"
    cp -a --no-preserve=ownership overlay/* $1
}

copy_overlay_desktop(){
    msg2 "Copying ${desktop}-overlay to ${work_dir}/${desktop}-image"
    cp -a --no-preserve=ownership ${desktop}-overlay/* ${work_dir}/${desktop}-image
}

copy_overlay_livecd(){
	msg2 "Copying overlay-livecd to $1 ..."
	cp -a --no-preserve=ownership overlay-livecd/* $1
}

copy_livecd_helpers(){
    msg2 "Copying livecd helpers ..."
    cp ${LIBDIR}/util-livecd.sh $1
    cp ${LIBDIR}/util-msg.sh $1
    cp ${LIBDIR}/util-mount.sh $1
    cp ${LIBDIR}/util.sh $1
    cp ${BINDIR}/chroot-run $1
    cp ${PKGDATADIR}/scripts/livecd $1
    cp ${PKGDATADIR}/scripts/mhwd $1
    
    # fix script permissions
    chmod +x $1/livecd
    chmod +x $1/mhwd
    
    # fix paths
    sed -e "s|${LIBDIR}|/opt/livecd|g" -i $1/chroot-run
    
    if [[ -f ${USER_CONFIG}/manjaro-tools.conf ]]; then
	msg2 "Copying ${USER_CONFIG}/manjaro-tools.conf to $1 ..."
	cp ${USER_CONFIG}/manjaro-tools.conf $1
    else
	msg2 "Copying ${manjaro_tools_conf} to $1 ..."
	cp ${manjaro_tools_conf} $1
    fi 
}

copy_cache_lng(){
    msg2 "Copying lng cache ..."
    cp ${cache_lng}/* ${work_dir}/lng-image/opt/livecd/lng
}

copy_cache_pkgs(){
    msg2 "Copying pkgs cache ..."
    cp ${cache_pkgs}/* ${work_dir}/pkgs-image/opt/livecd/pkgs
}

prepare_buildiso(){
    mkdir -p "${target_dir}"
    mkdir -p "${cache_pkgs}"
    mkdir -p "${cache_lng}"
}

check_cache(){
    if [[ -n $(cat isomounts | grep -F $1) ]]; then 
	echo true
    else 
	echo false
    fi 
}

clean_cache_lng(){
    msg "Cleaning ${cache_lng} ..."
    #rm ${cache_lng}/*
    find "${cache_lng}" -name '*.pkg.tar.xz' -delete &>/dev/null
}

clean_cache_pkgs(){
    msg "Cleaning ${cache_pkgs} ..."
    #rm ${cache_pkgs}/*
    find "${cache_pkgs}" -name '*.pkg.tar.xz' -delete &>/dev/null
}

clean_up(){
    if [[ -d ${work_dir} ]];then
	msg "Removing work dir ${work_dir}"
	rm -r ${work_dir}
    fi
}

make_repo(){
    repo-add ${work_dir}/pkgs-image/opt/livecd/pkgs/gfx-pkgs.db.tar.gz ${work_dir}/pkgs-image/opt/livecd/pkgs/*pkg*z
}

# $1: work dir
# $2: cache dir
# $3: pkglist
download_to_cache(){
    pacman -v --config "${pacman_conf}" \
	      --arch "${arch}" --root "$1" \
	      --cache $2 \
	      -Syw $3 --noconfirm
}

# Build ISO
make_iso() {
    msg "Build ISO"
    touch "${work_dir}/iso/.miso"
    
    mkiso ${iso_args[*]} iso "${work_dir}" "${iso_file}"
    chown -R "${iso_owner}:users" "${target_dir}"
    msg "Done build ISO"
}

# Base installation (root-image)
make_root_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Base installation (root-image)"
	
	mkiso ${create_args[*]} -p "${packages}" -i "root-image" create "${work_dir}"
	
	pacman -Qr "${work_dir}/root-image" > "${work_dir}/root-image/root-image-pkgs.txt"
		
	cp ${work_dir}/root-image/etc/locale.gen.bak ${work_dir}/root-image/etc/locale.gen
	if [ -e ${work_dir}/root-image/boot/grub/grub.cfg ] ; then
	    rm ${work_dir}/root-image/boot/grub/grub.cfg
	fi
	if [ -e ${work_dir}/root-image/etc/plymouth/plymouthd.conf ] ; then
	    sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" ${work_dir}/root-image/etc/plymouth/plymouthd.conf
	fi
	if [ -e ${work_dir}/root-image/etc/lsb-release ] ; then
	    sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${iso_version}/" ${work_dir}/root-image/etc/lsb-release
	fi
	if [ -e ${work_dir}/root-image/usr/bin/cupsd ] ; then
	    mkdir -p "${work_dir}/root-image/etc/systemd/system/multi-user.target.wants"
	    ln -sf '/usr/lib/systemd/system/org.cups.cupsd.service' "${work_dir}/root-image/etc/systemd/system/multi-user.target.wants/org.cups.cupsd.service"
	fi
	if [ -e ${work_dir}/root-image/usr/bin/keyboardctl ] ; then
	    mkdir -p "${work_dir}/root-image/etc/systemd/system/sysinit.target.wants"
	    ln -sf '/usr/lib/systemd/system/keyboardctl.service' "${work_dir}/root-image/etc/systemd/system/sysinit.target.wants/keyboardctl.service"
	fi
	if [ -e ${work_dir}/root-image/usr/bin/tlp ] ; then
	    mkdir -p "${work_dir}"/root-image/etc/systemd/system/{sleep.target.wants,multi-user.target.wants}
	    ln -sf '/usr/lib/systemd/system/tlp-sleep.service' "${work_dir}/root-image/etc/systemd/system/sleep.target.wants/tlp-sleep.service"
	    ln -sf '/usr/lib/systemd/system/tlp.service' "${work_dir}/root-image/etc/systemd/system/multi-user.target.wants/tlp.service"
	fi
	
	copy_overlay "${work_dir}/root-image"
	
	configure_machine_id "${work_dir}/root-image"

	configure_hostname "${work_dir}/root-image"
	
	# Clean up GnuPG keys
	rm -rf "${work_dir}/root-image/etc/pacman.d/gnupg"
	
	# Change to given branch in options.conf
	#sed -i -e "s/stable/$branch/" ${work_dir}/root-image/etc/pacman.d/mirrorlist
	#sed -i -e "s/stable/$branch/" ${work_dir}/root-image/etc/pacman-mirrors.conf
		
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done base installation (root-image)"
    fi
}

make_de_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "${desktop} installation (${desktop}-image)"
	
	mkdir -p ${work_dir}/${desktop}-image
	
	if [ ! -z "$(mount -l | grep ${desktop}-image)" ]; then
	    umount -l ${work_dir}/${desktop}-image
	fi
	
	mount -t aufs -o br=${work_dir}/${desktop}-image:${work_dir}/root-image=ro none ${work_dir}/${desktop}-image

	mkiso ${create_args[*]} -i "${desktop}-image" -p "${de_packages}" create "${work_dir}"

	pacman -Qr "${work_dir}/${desktop}-image" > "${work_dir}/${desktop}-image/${desktop}-image-pkgs.txt"
	
	cp "${work_dir}/${desktop}-image/${desktop}-image-pkgs.txt" ${target_dir}/${img_name}-${desktop}-${iso_version}-${arch}-pkgs.txt
	
	if [ -e ${desktop}-overlay ] ; then
	    copy_overlay_desktop
	fi
	
	configure_plymouth "${work_dir}/overlay-image"
	
	# Clean up GnuPG keys
	rm -rf "${work_dir}/${desktop}-image/etc/pacman.d/gnupg"
	
	umount -l ${work_dir}/${desktop}-image
	
	rm -R ${work_dir}/${desktop}-image/.wh*
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done ${desktop} installation (${desktop}-image)"
    fi
}

make_overlay_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare overlay-image"
	
	mkdir -p ${work_dir}/overlay-image
	
	if [ ! -z "$(mount -l | grep overlay-image)" ]; then
	    umount -l ${work_dir}/overlay-image
	fi
	
	msg2 "mount root-image"
	mount -t aufs -o br=${work_dir}/overlay-image:${work_dir}/root-image=ro none ${work_dir}/overlay-image
	
	if [ ! -z "${desktop}" ] ; then
	    msg2 "mount ${desktop}-image"
	    mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/overlay-image
	fi
	
	mkiso ${create_args[*]} -i "overlay-image" -p "${overlay_packages}" create "${work_dir}"

	pacman -Qr "${work_dir}/overlay-image" > "${work_dir}/overlay-image/overlay-image-pkgs.txt"
	
	configure_user_root "${work_dir}/overlay-image"
	
	configure_user "${work_dir}/overlay-image"
		
	configure_displaymanager "${work_dir}/overlay-image"
	
	configure_accountsservice "${work_dir}/overlay-image"
	
	${auto_svc_conf} && configure_services "${work_dir}/overlay-image"
		        
      	copy_overlay_livecd "${work_dir}/overlay-image"
	    
	configure_calamares "${work_dir}/overlay-image"
	
        #wget -O ${work_dir}/overlay/etc/pacman.d/mirrorlist http://git.manjaro.org/packages-sources/basis/blobs/raw/master/pacman-mirrorlist/mirrorlist    
        
        # copy over setup helpers and config loader
        copy_livecd_helpers "${work_dir}/overlay-image/opt/livecd"
        
        cp ${work_dir}/root-image/etc/pacman.d/mirrorlist ${work_dir}/overlay-image/etc/pacman.d/mirrorlist
        sed -i "s/#Server/Server/g" ${work_dir}/overlay-image/etc/pacman.d/mirrorlist
       	
	# Clean up GnuPG keys?
	#rm -rf "${work_dir}/${desktop}-image/etc/pacman.d/gnupg"
	
	umount -l ${work_dir}/overlay-image
	
	rm -R ${work_dir}/overlay-image/.wh*
	
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done overlay-image"
    fi
}

make_free_overlay(){
	msg "Prepare pkgs-free-overlay"
	mkdir -p ${work_dir}/pkgs-free-overlay
	if [ ! -z "$(mount -l | grep pkgs-free-overlay)" ]; then
	  umount -l ${work_dir}/pkgs-free-overlay
	fi

	msg2 "mount root-image"
	mount -t aufs -o br=${work_dir}/pkgs-free-overlay:${work_dir}/root-image=ro none ${work_dir}/pkgs-free-overlay

	if [ ! -z "${desktop}" ] ; then
	  msg2 "mount ${desktop}-image"
	  mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/pkgs-free-overlay
	fi

	mkiso ${create_args[*]} -i "pkgs-free-overlay" -p "${xorg_free_overlay}" create "${work_dir}"

	# Clean up GnuPG keys
	rm -rf "${work_dir}/pkgs-free-overlay/etc/pacman.d/gnupg"
	
	umount -l ${work_dir}/pkgs-free-overlay

	if [ -e ${work_dir}/pkgs-free-overlay/etc/modules-load.d/*virtualbox*conf ] ; then
	  rm ${work_dir}/pkgs-free-overlay/etc/modules-load.d/*virtualbox*conf
	fi

	rm -R ${work_dir}/pkgs-free-overlay/.wh*
	msg "Done pkgs-free-overlay"
}

make_non_free_overlay(){
	msg "Prepare pkgs-nonfree-overlay"
	mkdir -p ${work_dir}/pkgs-nonfree-overlay
      
	if [ ! -z "$(mount -l | grep pkgs-nonfree-overlay)" ]; then
	  umount -l ${work_dir}/pkgs-nonfree-overlay
	fi
	
	msg2 "mount root-image"
	mount -t aufs -o br=${work_dir}/pkgs-nonfree-overlay:${work_dir}/root-image=ro none ${work_dir}/pkgs-nonfree-overlay
	
	if [ ! -z "${desktop}" ] ; then
	  msg2 "mount ${desktop}-image"
	  mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/pkgs-nonfree-overlay
	fi
	
	mkiso ${create_args[*]} -i "pkgs-nonfree-overlay" -p "${xorg_nonfree_overlay}" create "${work_dir}"
	
	rm -rf "${work_dir}/pkgs-nonfree-overlay/etc/pacman.d/gnupg"
	
	umount -l ${work_dir}/pkgs-nonfree-overlay
	
	if [ -e ${work_dir}/pkgs-nonfree-overlay/etc/modules-load.d/*virtualbox*conf ] ; then
	  rm ${work_dir}/pkgs-nonfree-overlay/etc/modules-load.d/*virtualbox*conf
	fi
	
	rm -R ${work_dir}/pkgs-nonfree-overlay/.wh*
	msg "Done pkgs-nonfree-overlay"
}

configure_xorg_drivers(){
	# Disable Catalyst if not present
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep catalyst-utils 2> /dev/null)" ]; then
	    msg "Disabling Catalyst driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/catalyst/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/catalyst/MHWDCONFIG
	fi
	
	# Disable Nvidia if not present
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-utils 2> /dev/null)" ]; then
	    msg "Disabling Nvidia driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia/MHWDCONFIG
	fi
	
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-utils 2> /dev/null)" ]; then
	    msg "Disabling Nvidia Bumblebee driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/hybrid-intel-nvidia-bumblebee/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/hybrid-intel-nvidia-bumblebee/MHWDCONFIG
	fi
	
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-304xx-utils 2> /dev/null)" ]; then
	    msg "Disabling Nvidia 304xx driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-304xx/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-304xx/MHWDCONFIG
	fi
	
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-340xx-utils 2> /dev/null)" ]; then
	    msg "Disabling Nvidia 340xx driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-340xx/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-340xx/MHWDCONFIG
	fi
}

make_pkgs_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare pkgs-image"
	mkdir -p ${work_dir}/pkgs-image/opt/livecd/pkgs
	
	if [ ! -z "$(mount -l | grep pkgs-image)" ]; then
	    umount -l ${work_dir}/pkgs-image
	fi
	
	msg2 "mount root-image"
	mount -t aufs -o br=${work_dir}/pkgs-image:${work_dir}/root-image=ro none ${work_dir}/pkgs-image
	
	if [ ! -z "${desktop}" ] ; then
	    msg2 "mount ${desktop}-image"
	    mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/pkgs-image
	fi
	
	if ! ${is_cache_pkgs};then
	    download_to_cache "${work_dir}/pkgs-image" "${cache_pkgs}" "${xorg_packages}"
	    copy_cache_pkgs	
	fi
	
	if [ ! -z "${xorg_packages_cleanup}" ]; then
	    for xorg_clean in ${xorg_packages_cleanup}; do  
		rm ${work_dir}/pkgs-image/opt/livecd/pkgs/${xorg_clean}
	    done
	fi
	
	cp pacman-gfx.conf ${work_dir}/pkgs-image/opt/livecd
	rm -r ${work_dir}/pkgs-image/var
	
	make_repo "${work_dir}/pkgs-image/opt/livecd/pkgs/gfx-pkgs" "${work_dir}/pkgs-image/opt/livecd/pkgs"
	
	configure_xorg_drivers
	
	umount -l ${work_dir}/pkgs-image
	rm -R ${work_dir}/pkgs-image/.wh*
	
	if ${xorg_overlays}; then
	    make_free_overlay
	    make_non_free_overlay
	fi
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done pkgs-image"
    fi
}

make_lng_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare lng-image"
	mkdir -p ${work_dir}/lng-image/opt/livecd/lng
	
	if [ ! -z "$(mount -l | grep lng-image)" ]; then
	    umount -l ${work_dir}/lng-image
	fi
	
	msg2 "mount root-image"
	mount -t aufs -o br=${work_dir}/lng-image:${work_dir}/root-image=ro none ${work_dir}/lng-image
	
	if [ ! -z "${desktop}" ] ; then
	    msg2 "mount ${desktop}-image"
	    mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/lng-image
	fi

	if ${kde_lng_packages}; then
	    if ! ${is_cache_lng};then
		download_to_cache "${work_dir}/lng-image" "${cache_lng}" "${lng_packages} ${lng_packages_kde}"
		copy_cache_lng
	    fi
	else
	    if ! ${is_cache_lng};then
		download_to_cache "${work_dir}/lng-image" "${cache_lng}" "${lng_packages}"
		copy_cache_lng
	    fi
	fi
	
	if [ ! -z "${lng_packages_cleanup}" ]; then
	    for lng_clean in ${lng_packages_cleanup}; do
		rm ${work_dir}/lng-image/opt/livecd/lng/${lng_clean}
	    done
	fi
	
	cp pacman-lng.conf ${work_dir}/lng-image/opt/livecd
	rm -r ${work_dir}/lng-image/var
	
	make_repo ${work_dir}/lng-image/opt/livecd/lng/lng-pkgs ${work_dir}/lng-image/opt/livecd/lng
	
	umount -l ${work_dir}/lng-image
	
	rm -R ${work_dir}/lng-image/.wh*
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done lng-image"
    fi
}

gen_boot_img(){
	local _kernver=$(cat ${work_dir}/boot-image/usr/lib/modules/*-MANJARO/version)
        chroot-run ${work_dir}/boot-image \
		  /usr/bin/mkinitcpio -k ${_kernver} \
		  -c /etc/mkinitcpio-${manjaroiso}.conf \
		  -g /boot/${img_name}.img
}

# Prepare ${install_dir}/boot/
make_boot() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Prepare ${install_dir}/boot"
	mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
        
        cp ${work_dir}/root-image/boot/memtest86+/memtest.bin ${work_dir}/iso/${install_dir}/boot/${arch}/memtest
	
	cp ${work_dir}/root-image/boot/vmlinuz* ${work_dir}/iso/${install_dir}/boot/${arch}/${manjaroiso}
        mkdir -p ${work_dir}/boot-image
        
        if [ ! -z "$(mount -l | grep boot-image)" ]; then
           umount -l ${work_dir}/boot-image/{proc,sys,dev}
           umount ${work_dir}/boot-image
        fi
        
        msg2 "mount root-image"
        mount -t aufs -o br=${work_dir}/boot-image:${work_dir}/root-image=ro none ${work_dir}/boot-image
        
        if [ ! -z "${desktop}" ] ; then
             msg2 "mount ${desktop}-image"
             mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/boot-image
        fi
        
        copy_initcpio
        
        gen_boot_img
        
        mv ${work_dir}/boot-image/boot/${img_name}.img ${work_dir}/iso/${install_dir}/boot/${arch}/${img_name}.img
                
        umount ${work_dir}/boot-image
        
        rm -R ${work_dir}/boot-image
        
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done ${install_dir}/boot"
    fi
}

# Prepare /EFI
make_efi() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare ${install_dir}/boot/EFI"
        mkdir -p ${work_dir}/iso/EFI/boot
        cp ${work_dir}/root-image/usr/lib/prebootloader/PreLoader.efi ${work_dir}/iso/EFI/boot/bootx64.efi
        cp ${work_dir}/root-image/usr/lib/prebootloader/HashTool.efi ${work_dir}/iso/EFI/boot/

        cp ${work_dir}/root-image/usr/lib/gummiboot/gummibootx64.efi ${work_dir}/iso/EFI/boot/loader.efi

        mkdir -p ${work_dir}/iso/loader/entries
        cp efiboot/loader/loader.conf ${work_dir}/iso/loader/
        cp efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${work_dir}/iso/loader/entries/
        cp efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${work_dir}/iso/loader/entries/

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-usb.conf > ${work_dir}/iso/loader/entries/${manjaroiso}-x86_64.conf

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-nonfree-usb.conf > ${work_dir}/iso/loader/entries/${manjaroiso}-x86_64-nonfree.conf

        # EFI Shell 2.0 for UEFI 2.3+ ( http://sourceforge.net/apps/mediawiki/tianocore/index.php?title=UEFI_Shell )
        curl -k -o ${work_dir}/iso/EFI/shellx64_v2.efi https://svn.code.sf.net/p/edk2/code/trunk/edk2/ShellBinPkg/UefiShell/X64/Shell.efi
        # EFI Shell 1.0 for non UEFI 2.3+ ( http://sourceforge.net/apps/mediawiki/tianocore/index.php?title=Efi-shell )
        curl -k -o ${work_dir}/iso/EFI/shellx64_v1.efi https://svn.code.sf.net/p/edk2/code/trunk/edk2/EdkShellBinPkg/FullShell/X64/Shell_Full.efi
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done ${install_dir}/boot/EFI"
    fi
}

# Prepare kernel.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare ${install_dir}/iso/EFI"
        mkdir -p ${work_dir}/iso/EFI/miso
        truncate -s 31M ${work_dir}/iso/EFI/miso/${img_name}.img
        mkfs.vfat -n MISO_EFI ${work_dir}/iso/EFI/miso/${img_name}.img

        mkdir -p ${work_dir}/efiboot
        mount ${work_dir}/iso/EFI/miso/${img_name}.img ${work_dir}/efiboot

        mkdir -p ${work_dir}/efiboot/EFI/miso
        cp ${work_dir}/iso/${install_dir}/boot/x86_64/${manjaroiso} ${work_dir}/efiboot/EFI/miso/${manjaroiso}.efi
        cp ${work_dir}/iso/${install_dir}/boot/x86_64/${img_name}.img ${work_dir}/efiboot/EFI/miso/${img_name}.img

        mkdir -p ${work_dir}/efiboot/EFI/boot
        cp ${work_dir}/root-image/usr/lib/prebootloader/PreLoader.efi ${work_dir}/efiboot/EFI/boot/bootx64.efi
        cp ${work_dir}/root-image/usr/lib/prebootloader/HashTool.efi ${work_dir}/efiboot/EFI/boot/

        cp ${work_dir}/root-image/usr/lib/gummiboot/gummibootx64.efi ${work_dir}/efiboot/EFI/boot/loader.efi

        mkdir -p ${work_dir}/efiboot/loader/entries
        cp efiboot/loader/loader.conf ${work_dir}/efiboot/loader/
        cp efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${work_dir}/efiboot/loader/entries/
        cp efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${work_dir}/efiboot/loader/entries/

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-dvd.conf > ${work_dir}/efiboot/loader/entries/${manjaroiso}-x86_64.conf

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-nonfree-dvd.conf > ${work_dir}/efiboot/loader/entries/${manjaroiso}-x86_64-nonfree.conf

        cp ${work_dir}/iso/EFI/shellx64_v2.efi ${work_dir}/efiboot/EFI/
        cp ${work_dir}/iso/EFI/shellx64_v1.efi ${work_dir}/efiboot/EFI/

        umount ${work_dir}/efiboot
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done ${install_dir}/iso/EFI"
    fi
}

# Prepare /isolinux
make_isolinux() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare ${install_dir}/iso/isolinux"
	mkdir -p ${work_dir}/iso/isolinux
        cp -a --no-preserve=ownership isolinux/* ${work_dir}/iso/isolinux
        if [[ -e isolinux-overlay ]]; then
	    msg2 "isolinux overlay found. Overwriting files."
            cp -a --no-preserve=ownership isolinux-overlay/* ${work_dir}/iso/isolinux
        fi
        if [[ -e ${work_dir}/root-image/usr/lib/syslinux/bios/ ]]; then
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/isolinux.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/isohdpfx.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/ldlinux.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/gfxboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/whichsys.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/mboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/hdt.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/chain.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libcom32.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libmenu.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libutil.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libgpl.c32 ${work_dir}/iso/isolinux/
        else
            cp ${work_dir}/root-image/usr/lib/syslinux/isolinux.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/isohdpfx.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/gfxboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/whichsys.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/mboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/hdt.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/chain.c32 ${work_dir}/iso/isolinux/
        fi
        sed -i "s|%MISO_LABEL%|${iso_label}|g;
                s|%INSTALL_DIR%|${install_dir}|g;
                s|%ARCH%|${arch}|g" ${work_dir}/iso/isolinux/isolinux.cfg
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done ${install_dir}/iso/isolinux"
    fi
}

# Process isomounts
make_isomounts() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Process isomounts"
        sed "s|@ARCH@|${arch}|g" isomounts > ${work_dir}/iso/${install_dir}/isomounts
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done processing isomounts"
    fi
}

load_desktop_definition(){
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

get_pkglist_xorg(){
    if [ "${arch}" == "i686" ]; then
	xorg_packages=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	xorg_free_overlay=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	xorg_nonfree_overlay=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni.*||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni||g" | sed "s|^.*catalyst-legacy.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	xorg_packages=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64||g" | sed "s|>free_uni||g" | sed "s|>nonfree_uni||g" | sed "s|>nonfree_x64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	xorg_free_overlay=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64||g" | sed "s|>free_uni||g" | sed "s|>nonfree_uni.*||g" | sed "s|>nonfree_x64.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	xorg_nonfree_overlay=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni.*||g" | sed "s|>nonfree_uni||g" | sed "s|>nonfree_x64||g" | sed "s|^.*catalyst-legacy.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
    xorg_packages_cleanup=$(sed "s|#.*||g" Packages-Xorg | grep cleanup | sed "s|>cleanup||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
}

get_pkglist_lng(){
    if [ "${arch}" == "i686" ]; then
	lng_packages=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	lng_packages=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
    lng_packages_cleanup=$(sed "s|#.*||g" Packages-Lng | grep cleanup | sed "s|>cleanup||g")
    lng_packages_kde=$(sed "s|#.*||g" Packages-Lng | grep kde | sed "s|>kde||g" | sed ':a;N;$!ba;s/\n/ /g')
}

get_pkglist_de(){
    if [ "${arch}" == "i686" ]; then
	de_packages=$(sed "s|#.*||g" "${pkgsfile}" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	de_packages=$(sed "s|#.*||g" "${pkgsfile}" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
}

get_pkglist(){
    if [ "${arch}" == "i686" ]; then
	packages=$(sed "s|#.*||g" Packages | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages=$(sed "s|#.*||g" Packages | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
}

get_pkglist_overlay(){
    if [ "${arch}" == "i686" ]; then
	overlay_packages=$(sed "s|#.*||g" "Packages-Livecd" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	overlay_packages=$(sed "s|#.*||g" "Packages-Livecd" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
}
