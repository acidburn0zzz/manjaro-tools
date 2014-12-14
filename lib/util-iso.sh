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

# Prepare ${install_dir}/boot/
make_boot() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare ${install_dir}/boot/"
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
        mount -t proc none ${work_dir}/boot-image/proc
        mount -t sysfs none ${work_dir}/boot-image/sys
        mount -o bind /dev ${work_dir}/boot-image/dev
        cp /usr/lib/initcpio/hooks/miso* ${work_dir}/boot-image/usr/lib/initcpio/hooks
        cp /usr/lib/initcpio/install/miso* ${work_dir}/boot-image/usr/lib/initcpio/install
        cp mkinitcpio.conf ${work_dir}/boot-image/etc/mkinitcpio-${manjaroiso}.conf
        _kernver=$(cat ${work_dir}/boot-image/usr/lib/modules/*-MANJARO/version)
        chroot ${work_dir}/boot-image /usr/bin/mkinitcpio -k ${_kernver} -c /etc/mkinitcpio-${manjaroiso}.conf -g /boot/${img_name}.img
        mv ${work_dir}/boot-image/boot/${img_name}.img ${work_dir}/iso/${install_dir}/boot/${arch}/${img_name}.img
        umount -l ${work_dir}/boot-image/{proc,sys,dev} 
        umount ${work_dir}/boot-image
        rm -R ${work_dir}/boot-image
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done"
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
	msg "Done"
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
	msg "Done"
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
	msg "Done"
    fi
}

# Process isomounts
make_isomounts() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Process isomounts"
        sed "s|@ARCH@|${arch}|g" isomounts > ${work_dir}/iso/${install_dir}/isomounts
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done"
    fi
}

prepare_targetdir(){
    mkdir -p "${target_dir}"
}

clean_up(){
    if [[ -d ${work_dir} ]];then
	msg "Removing work dir ${work_dir}"
	rm -r ${work_dir}
    fi
}

# Build ISO
make_iso() {
    msg "Build ISO"
    touch "${work_dir}/iso/.miso"
    
    mkiso ${iso_args[*]} iso "${work_dir}" "${iso_file}"
    chown -R "${iso_owner}:users" "${target_dir}"
    msg "Done"
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
	cp -a --no-preserve=ownership overlay/* ${work_dir}/root-image

	# Clean up GnuPG keys
	rm -rf "${work_dir}/root-image/etc/pacman.d/gnupg"
	
	# Change to given branch in options.conf
	sed -i -e "s/stable/$branch/" ${work_dir}/root-image/etc/pacman.d/mirrorlist
	sed -i -e "s/stable/$branch/" ${work_dir}/root-image/etc/pacman-mirrors.conf
		
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done"
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
	    cp -a --no-preserve=ownership ${desktop}-overlay/* ${work_dir}/${desktop}-image
	fi
	if [ -e ${work_dir}/${desktop}-image/usr/bin/cupsd ] ; then
	    mkdir -p "${work_dir}/${desktop}-image/etc/systemd/system/multi-user.target.wants"
	    ln -sf '/usr/lib/systemd/system/org.cups.cupsd.service' "${work_dir}/${desktop}-image/etc/systemd/system/multi-user.target.wants/org.cups.cupsd.service"
	fi
	if [ -e ${work_dir}/root-image/usr/bin/tlp ] ; then
	    mkdir -p "${work_dir}/${desktop}-image"/etc/systemd/system/{sleep.target.wants,multi-user.target.wants}
	    ln -sf '/usr/lib/systemd/system/tlp-sleep.service' "${work_dir}/${desktop}-image/etc/systemd/system/sleep.target.wants/tlp-sleep.service"
	    ln -sf '/usr/lib/systemd/system/tlp.service' "${work_dir}/${desktop}-image/etc/systemd/system/multi-user.target.wants/tlp.service"
	fi
	if [ -e ${work_dir}/${desktop}-image/etc/plymouth/plymouthd.conf ] ; then
	    sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" ${work_dir}/${desktop}-image/etc/plymouth/plymouthd.conf
	fi
	
	umount -l ${work_dir}/${desktop}-image
	rm -R ${work_dir}/${desktop}-image/.wh*
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done"
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
	    msg2 -"mount ${desktop}-image"
	    mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/pkgs-image
	fi
	pacman -v --config "${pacman_conf}" --arch "${arch}" --root "${work_dir}/pkgs-image" --cache ${work_dir}/pkgs-image/opt/livecd/pkgs -Syw ${xorg_packages} --noconfirm
	if [ ! -z "${xorg_packages_cleanup}" ]; then
	    for xorg_clean in ${xorg_packages_cleanup};
	      do  rm ${work_dir}/pkgs-image/opt/livecd/pkgs/${xorg_clean}
	      done
	fi
	cp pacman-gfx.conf ${work_dir}/pkgs-image/opt/livecd
	rm -r ${work_dir}/pkgs-image/var
	repo-add ${work_dir}/pkgs-image/opt/livecd/pkgs/gfx-pkgs.db.tar.gz ${work_dir}/pkgs-image/opt/livecd/pkgs/*pkg*z
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
	umount -l ${work_dir}/pkgs-image
	rm -R ${work_dir}/pkgs-image/.wh*
	if ${xorg_overlays}; then
	    msg2 "Prepare pkgs-free-overlay"
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
	    umount -l ${work_dir}/pkgs-free-overlay
	    if [ -e ${work_dir}/pkgs-free-overlay/etc/modules-load.d/*virtualbox*conf ] ; then
	      rm ${work_dir}/pkgs-free-overlay/etc/modules-load.d/*virtualbox*conf
	    fi
	    rm -R ${work_dir}/pkgs-free-overlay/.wh*
	  msg2 "Prepare pkgs-nonfree-overlay"
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
	    umount -l ${work_dir}/pkgs-nonfree-overlay
	    if [ -e ${work_dir}/pkgs-nonfree-overlay/etc/modules-load.d/*virtualbox*conf ] ; then
	      rm ${work_dir}/pkgs-nonfree-overlay/etc/modules-load.d/*virtualbox*conf
	    fi
	    rm -R ${work_dir}/pkgs-nonfree-overlay/.wh*
	fi
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done"
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
	    pacman -v --config "${pacman_conf}" --arch "${arch}" --root "${work_dir}/lng-image" --cache ${work_dir}/lng-image/opt/livecd/lng -Syw ${lng_packages} ${lng_packages_kde} --noconfirm
	else
	    pacman -v --config "${pacman_conf}" --arch "${arch}" --root "${work_dir}/lng-image" --cache ${work_dir}/lng-image/opt/livecd/lng -Syw ${lng_packages} --noconfirm
	fi
	if [ ! -z "${lng_packages_cleanup}" ]; then
	    for lng_clean in ${lng_packages_cleanup};
	      do  rm ${work_dir}/lng-image/opt/livecd/lng/${lng_clean}
	      done
	fi
	cp pacman-lng.conf ${work_dir}/lng-image/opt/livecd
	rm -r ${work_dir}/lng-image/var
	repo-add ${work_dir}/lng-image/opt/livecd/lng/lng-pkgs.db.tar.gz ${work_dir}/lng-image/opt/livecd/lng/*pkg*z
	umount -l ${work_dir}/lng-image
	rm -R ${work_dir}/lng-image/.wh*
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done"
    fi
}
