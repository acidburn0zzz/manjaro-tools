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

gen_pw(){
    echo $(perl -e 'print crypt($ARGV[0], "password")' ${password})
}

# $1: source image
# $2: target image
copy_userconfig(){	
    msg2 "Copying $1/etc/skel/. $2/home/${username}"
    cp -r $1/etc/skel/. $2/home/${username}
    chroot-run $2 chown ${username}:users /home/${username}
    chroot-run $2 chmod -R 755 /home/${username}
}

copy_manjaro_tools_conf(){
	local livecd=$1
	
	[[ ! -d ${livecd} ]] && mkdir ${livecd}
	if [[ -f $USER_HOME/.config/manjaro-tools.conf ]]; then
	    msg2 "Copying $USER_HOME/.config/manjaro-tools.conf to ${livecd}/manjaro-tools.conf ..."
	    cp $USER_HOME/.config/manjaro-tools.conf ${livecd}/manjaro-tools.conf
	else
	    msg2 "Copying ${manjaro_tools_conf} to ${livecd}/manjaro-tools.conf ..."
	    cp ${manjaro_tools_conf} ${livecd}/manjaro-tools.conf
	fi
}

copy_livecd(){
    local livecd=$1
    
    msg2 "Copying $1/livecd to ${work_dir}/overlay/opt ..."
    [[ ! -d ${work_dir}/overlay/opt ]] && mkdir -p ${work_dir}/overlay/opt
    cp -r $1/livecd ${work_dir}/overlay/opt
    
    msg2 "Fixing livecd script permissions ..."
    chmod 755 ${work_dir}/overlay/opt/livecd/{livecd,mhwd,lg,km,ejectcd,disable-dpms,pulseaudio-ctl-normal,setup,setup-0.8,setup-0.9,update-setup}
    chmod +x ${work_dir}/overlay/opt/livecd/{livecd,mhwd,lg,km,ejectcd,disable-dpms,pulseaudio-ctl-normal,setup,setup-0.8,setup-0.9,update-setup}
}

copy_overlay(){
    msg2 "Copying overlay to $1"
    cp -a overlay/* $1
}

copy_overlay_desktop(){
    msg2 "Copying ${desktop}-overlay to ${work_dir}/${desktop}-image"
    cp -a ${desktop}-overlay/* ${work_dir}/${desktop}-image
}

copy_initcpio(){
        cp /usr/lib/initcpio/hooks/miso* ${work_dir}/boot-image/usr/lib/initcpio/hooks
        cp /usr/lib/initcpio/install/miso* ${work_dir}/boot-image/usr/lib/initcpio/install
        cp mkinitcpio.conf ${work_dir}/boot-image/etc/mkinitcpio-${manjaroiso}.conf
}

copy_livecd_init(){
	if [[ -d overlay-livecd-openrc ]]; then
	    msg2 "Copying overlay-livecd-openrc/ to $1 ..."
	    cp -a overlay-livecd-openrc/* $1
        fi
        
        if [[ -d overlay-livecd-systemd ]]; then
	    msg2 "Copying overlay-livecd-systemd/ to $1 ..."
	    cp -a overlay-livecd-systemd/* $1
	fi
}

copy_overlay_livecd(){
	msg2 "Copying overlay-livecd to $1 ..."
	cp -a overlay-livecd/* $1
}


# $1: chroot
configure_user(){
	# set up user and password
	local pass=$(gen_pw)
	msg2 "Creating user ${username} with password ${password} ..."
	chroot-run $1 useradd -m -g users -G ${addgroups} -p ${pass} ${username}
}

# $1: chroot
configue_hostname(){
	msg2 "Setting hostname ${hostname} ..."
	if [[ -f $1/usr/bin/openrc ]];then
	    local _hostname='hostname="'${hostname}'"'
	    sed -i -e "s|^.*hostname=.*|${_hostname}|" $1/etc/conf.d/hostname
	else
	    echo ${hostname} > $1/etc/hostname
	fi
}

configure_plymouth(){
    if [ -e $1/etc/plymouth/plymouthd.conf ] ; then
	    sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" $1/etc/plymouth/plymouthd.conf
    fi
}

configure_services(){
   if [[ -f ${work_dir}/root-image/usr/bin/openrc ]];then
      msg2 "Congiguring OpenRC ...."
      for svc in ${startservices_openrc[@]}; do
	  if [[ -f $1/etc/init.d/$svc ]]; then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/runlevels/default ]] && mkdir -p $1/etc/runlevels/default
	      ln -sf /etc/init.d/$svc $1/etc/runlevels/default/$svc
	  fi
      done
   else
      msg2 "Congiguring SystemD ...."
      for svc in ${startservices_systemd[@]}; do
	      msg2 "Setting $svc ..."
	      if [[ -f $1/usr/lib/systemd/system/$svc ]];then
		  msg2 "Setting $svc ..."
		  chroot-run $1 systemctl enable $svc
	      fi
      done
   fi
}

configure_services_livecd(){
   if [[ -f ${work_dir}/root-image/usr/bin/openrc ]];then
      msg2 "Congiguring OpenRC ...."
      for svc in ${startservices_livecd[@]}; do
	  if [[ -f $1/etc/init.d/$svc ]]; then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/runlevels/default ]] && mkdir -p $1/etc/runlevels/default
	      ln -sf /etc/init.d/$svc $1/etc/runlevels/default/$svc
	  fi
      done
   else
      msg2 "Congiguring SystemD ...."
      for svc in ${startservices_livecd[@]}; do
	  #if [[ -f $1/etc/systemd/system/$svc ]];then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/systemd/system/multi-user.target.wants ]] && mkdir -p $1/etc/systemd/system/multi-user.target.wants
	      ln -sf /etc/systemd/system/$svc $1/etc/systemd/system/multi-user.target.wants/$svc
	  #fi
      done
   fi
}


# $1: chroot
configue_displaymanager(){
    local _dm
    msg2 "Configuring Displaymanager ..."
    # do_setuplightdm
    if [ -e "$1/usr/bin/lightdm" ] ; then
	#mkdir -p /run/lightdm > /dev/null

	if [ -e "$1/usr/bin/startxfce4" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=xfce/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=cinnamon/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=mate/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=enlightenment/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=openbox/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=LXDE/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=lxqt/' $1/etc/lightdm/lightdm.conf
	fi
	if [ -e "$1/usr/bin/pekwm" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=pekwm/' $1/etc/lightdm/lightdm.conf
	fi
	sed -i -e "s/^.*autologin-user=.*/autologin-user=${username}/" $1/etc/lightdm/lightdm.conf
	sed -i -e 's/^.*autologin-user-timeout=.*/autologin-user-timeout=0/' $1/etc/lightdm/lightdm.conf
      #    sed -i -e 's/^.*autologin-in-background=.*/autologin-in-background=true/' /etc/lightdm/lightdm.conf
      
	chroot-run $1 groupadd autologin
	chroot-run $1 gpasswd -a ${username} autologin
	chroot-run $1 chmod +r /etc/lightdm/lightdm.conf
	# livecd fix
	mkdir -p $1/var/lib/lightdm-data
	
	if [[ -e /run/systemd ]]; then
	    chroot-run $1 systemd-tmpfiles --create /usr/lib/tmpfiles.d/lightdm.conf
	    chroot-run $1 systemd-tmpfiles --create --remove
	fi
	_dm='lightdm'
    fi

    # do_setupkdm
    if [ -e "$1/usr/share/config/kdm/kdmrc" ] ; then

	chroot-run $1 xdg-icon-resource forceupdate --theme hicolor &> /dev/null
	if [ -e "$1/usr/bin/update-desktop-database" ] ; then
	    chroot-run $1 update-desktop-database -q
	fi
	sed -i -e "s/^.*AutoLoginUser=.*/AutoLoginUser=${username}/" $1/usr/share/config/kdm/kdmrc
	sed -i -e "s/^.*AutoLoginPass=.*/AutoLoginPass=${username}/" $1/usr/share/config/kdm/kdmrc
	
	_dm='kdm'
    fi

    # do_setupgdm
    if [ -e "$1/usr/bin/gdm" ] ; then

	if [ -d "$1/var/lib/AccountsService/users" ] ; then
	    echo "[User]" > $1/var/lib/AccountsService/users/gdm
	    if [ -e "$1/usr/bin/startxfce4" ] ; then
		echo "XSession=xfce" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/cinnamon-session" ] ; then
		echo "XSession=cinnamon" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/mate-session" ] ; then
		echo "XSession=mate" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/enlightenment_start" ] ; then
		echo "XSession=enlightenment" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/openbox-session" ] ; then
		echo "XSession=openbox" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/startlxde" ] ; then
		echo "XSession=LXDE" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    if [ -e "$1/usr/bin/lxqt-session" ] ; then
		echo "XSession=LXQt" >> $1/var/lib/AccountsService/users/gdm
	    fi
	    echo "Icon=" >> $1/var/lib/AccountsService/users/gdm
	fi
      _dm='gdm'
    fi

    # do_setupmdm
    if [ -e "$1/usr/bin/mdm" ] ; then

	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    sed -i 's|default.desktop|xfce.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    sed -i 's|default.desktop|cinnamon.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    sed -i 's|default.desktop|openbox.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    sed -i 's|default.desktop|mate.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	    sed -i 's|default.desktop|LXDE.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    sed -i 's|default.desktop|lxqt.desktop|g' $1/etc/mdm/custom.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    sed -i 's|default.desktop|enlightenment.desktop|g' $1/etc/mdm/custom.conf
	fi
	_dm='mdm'
    fi

    # do_setupsddm
    if [ -e "$1/usr/bin/sddm" ] ; then

	sed -i -e "s|^User=.*|User=${username}|" $1/etc/sddm.conf
	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    sed -i -e 's|^Session=.*|Session=xfce.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=cinnamon.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=openbox.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=mate.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/lxsession" ] ; then
	    sed -i -e 's|^Session=.*|Session=LXDE.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    sed -i -e 's|^Session=.*|Session=lxqt.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    sed -i -e 's|^Session=.*|Session=enlightenment.desktop|' $1/etc/sddm.conf
	fi
	if [ -e "$1/usr/bin/startkde" ] ; then
	    sed -i -e 's|^Session=.*|Session=plasma.desktop|' $1/etc/sddm.conf
	fi
	_dm='sddm'
    fi

    # do_setuplxdm
    if [ -e "$1/usr/bin/lxdm" ] ; then

	sed -i -e "s/^.*autologin=.*/autologin=${username}/" $1/etc/lxdm/lxdm.conf
	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/startxfce4|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/cinnamon-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/mate-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/enlightenment_start|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/openbox-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/lxsession|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/lxqt-session|' $1/etc/lxdm/lxdm.conf
	fi
	if [ -e "$1/usr/bin/pekwm" ] ; then
	    sed -i -e 's|^.*session=.*|session=/usr/bin/pekwm|' $1/etc/lxdm/lxdm.conf
	fi

	_dm='lxdm'
    fi
    
    if [[ -e $1/usr/bin/openrc ]];then
	local _conf_xdm='DISPLAYMANAGER="'${_dm}'"'
	sed -i -e "s|^.*DISPLAYMANAGER=.*|${_conf_xdm}|" $1/etc/conf.d/xdm
    fi
}

# $1: chroot
configue_accountsservice(){
    msg2 "Configuring AcooutsService ..."
    if [ -d "$1/var/lib/AccountsService/users" ] ; then
	echo "[User]" > $1/var/lib/AccountsService/users/${username}
	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    echo "XSession=xfce" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    echo "XSession=cinnamon" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    echo "XSession=mate" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    echo "XSession=enlightenment" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    echo "XSession=openbox" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	    echo "XSession=LXDE" >> $1/var/lib/AccountsService/users/${username}
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    echo "XSession=LXQt" >> $1/var/lib/AccountsService/users/${username}
	fi
	echo "Icon=/var/lib/AccountsService/icons/${username}.png" >> $1/var/lib/AccountsService/users/${username}
    fi
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

gen_boot_img(){
	local _kernver=$(cat ${work_dir}/boot-image/usr/lib/modules/*-MANJARO/version)
        chroot-run ${work_dir}/boot-image \
		  /usr/bin/mkinitcpio -k ${_kernver} \
		  -c /etc/mkinitcpio-${manjaroiso}.conf \
		  -g /boot/${img_name}.img
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
        cp -Lr isolinux ${work_dir}/iso
        if [[ -e isolinux-overlay ]]; then
	    msg2 "isolinux overlay found. Overwriting files."
            cp -a isolinux-overlay/* ${work_dir}/iso/isolinux
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

prepare_targetdir(){
    mkdir -p "${target_dir}"
}

clean_up(){
    if [[ -d ${work_dir} ]];then
	msg "Removing work dir ${work_dir}"
	rm -r ${work_dir}
    fi
}

# $1: work dir
# $2: cahe dir
# $3: pkglist
download_to_cache(){
    pacman -v --config "${pacman_conf}" \
	      --arch "${arch}" --root "$1" \
	      --cache $2 \
	      -Syw $3 --noconfirm
}

make_repo(){
    repo-add ${work_dir}/pkgs-image/opt/livecd/pkgs/gfx-pkgs.db.tar.gz ${work_dir}/pkgs-image/opt/livecd/pkgs/*pkg*z
}

# Build ISO
make_iso() {
    msg "Build ISO"
    touch "${work_dir}/iso/.miso"
    
    mkiso ${iso_args[*]} iso "${work_dir}" "${iso_file}"
    chown -R "${iso_owner}:users" "${target_dir}"
    msg "Done build ISO"
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

	# set hostname
	configue_hostname "${work_dir}/root-image"
	
	# set up user and password
	configure_user "${work_dir}/root-image"
	
	configure_services "${work_dir}/root-image"
	
	configure_plymouth "${work_dir}/root-image"
	
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
	
	# copy user home files
	copy_userconfig "${work_dir}/${desktop}-image" "${work_dir}/root-image"
	
	# set up auto start services
	configure_services "${work_dir}/${desktop}-image"
		
	# configure DM & accountsservice
	configue_displaymanager "${work_dir}/${desktop}-image"
	configue_accountsservice "${work_dir}/${desktop}-image"
	
	configure_plymouth "${work_dir}/${desktop}-image"
	
	# Clean up GnuPG keys
	rm -rf "${work_dir}/${desktop}-image/etc/pacman.d/gnupg"
	
	umount -l ${work_dir}/${desktop}-image
	
	rm -R ${work_dir}/${desktop}-image/.wh*
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done ${desktop} installation (${desktop}-image)"
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

make_non_fee_overlay(){
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
		
	download_to_cache "${work_dir}/pkgs-image" "${work_dir}/pkgs-image/opt/livecd/pkgs" "${xorg_packages}"
	
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
	    make_non_fee_overlay
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
	    download_to_cache "${work_dir}/lng-image" "${work_dir}/lng-image/opt/livecd/lng" "${lng_packages} ${lng_packages_kde}"
	else
	    download_to_cache "${work_dir}/lng-image" "${work_dir}/lng-image/opt/livecd/lng" "${lng_packages}"
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
