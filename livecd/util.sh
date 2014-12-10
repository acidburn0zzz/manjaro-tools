#!/bin/bash

# check if we have a internet connection
ping_check=$(LC_ALL=C ping -c 1 www.manjaro.org | grep "1 received")

set_alsa ()
{
#set_alsa
    # amixer binary
    local alsa_amixer="chroot ${DESTDIR} /usr/bin/amixer"

    # enable all known (tm) outputs
    $alsa_amixer -c 0 sset "Master" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Front" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Side" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Surround" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Center" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "LFE" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Headphone" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Speaker" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "PCM" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Line" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "External" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "FM" 50% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Master Mono" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Master Digital" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Analog Mix" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Aux" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Aux2" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Center" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Front" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM LFE" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Side" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Surround" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Playback" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM,1" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC,0" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC,0" -12dB &> /dev/null
    $alsa_amixer -c 0 sset "DAC,1" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC,1" -12dB &> /dev/null
    $alsa_amixer -c 0 sset "Synth" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "CD" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Wave" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Music" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "AC97" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Analog Front" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,0" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,1" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,2" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,3" 70% unmute &> /dev/null

    # set input levels
    $alsa_amixer -c 0 sset "Mic" 70% mute &>/dev/null
    $alsa_amixer -c 0 sset "IEC958" 70% mute &>/dev/null

    # special stuff
    $alsa_amixer -c 0 sset "Master Playback Switch" on &>/dev/null
    $alsa_amixer -c 0 sset "Master Surround" on &>/dev/null
    $alsa_amixer -c 0 sset "SB Live Analog/Digital Output Jack" off &>/dev/null
    $alsa_amixer -c 0 sset "Audigy Analog/Digital Output Jack" off &>/dev/null
}

# set_dm(){
#     local _dm
# 
#     # do_setuplightdm
#     if [ -e "/usr/bin/lightdm" ] ; then
# 	mkdir -p /run/lightdm > /dev/null
# 	getent group lightdm > /dev/null 2>&1 || groupadd -g 620 lightdm
# 	getent passwd lightdm > /dev/null 2>&1 || useradd -c 'LightDM Display Manager' -u 620 -g lightdm -d /var/run/lightdm -s /usr/bin/nologin lightdm
# 	passwd -l lightdm > /dev/null
# 	chown -R lightdm:lightdm /var/run/lightdm > /dev/null
# 	if [ -e "/usr/bin/startxfce4" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=xfce/' /etc/lightdm/lightdm.conf
# 	fi
# 	if [ -e "/usr/bin/cinnamon-session" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=cinnamon/' /etc/lightdm/lightdm.conf
# 	fi
# 	if [ -e "/usr/bin/mate-session" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=mate/' /etc/lightdm/lightdm.conf
# 	fi
# 	if [ -e "/usr/bin/enlightenment_start" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=enlightenment/' /etc/lightdm/lightdm.conf
# 	fi
# 	if [ -e "/usr/bin/openbox-session" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=openbox/' /etc/lightdm/lightdm.conf
# 	fi
# 	if [ -e "/usr/bin/startlxde" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=LXDE/' /etc/lightdm/lightdm.conf
# 	fi
# 	if [ -e "/usr/bin/lxqt-session" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=lxqt/' /etc/lightdm/lightdm.conf
# 	fi
# 	if [ -e "/usr/bin/pekwm" ] ; then
# 	      sed -i -e 's/^.*user-session=.*/user-session=pekwm/' /etc/lightdm/lightdm.conf
# 	fi
# 	sed -i -e "s/^.*autologin-user=.*/autologin-user=${username}/" /etc/lightdm/lightdm.conf
# 	sed -i -e 's/^.*autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
#       #    sed -i -e 's/^.*autologin-in-background=.*/autologin-in-background=true/' /etc/lightdm/lightdm.conf
# 	groupadd autologin
# 	gpasswd -a ${username} autologin
# 	chmod +r /etc/lightdm/lightdm.conf
# 	# livecd fix
# 	mkdir -p /var/lib/lightdm-data
# 	
# 	if [[ -e /run/systemd ]]; then
# 	    systemd-tmpfiles --create /usr/lib/tmpfiles.d/lightdm.conf
# 	    systemd-tmpfiles --create --remove
# 	fi
# 	_dm='lightdm'
#     fi
# 
#     # do_setupkdm
#     if [ -e "/usr/share/config/kdm/kdmrc" ] ; then
# 	getent group kdm >/dev/null 2>&1 || groupadd -g 135 kdm &>/dev/null
# 	getent passwd kdm >/dev/null 2>&1 || useradd -u 135 -g kdm -d /var/lib/kdm -s /bin/false -r -M kdm &>/dev/null
# 	chown -R 135:135 var/lib/kdm &>/dev/null
# 	xdg-icon-resource forceupdate --theme hicolor &> /dev/null
# 	if [ -e "/usr/bin/update-desktop-database" ] ; then
# 	    update-desktop-database -q
# 	fi
# 	sed -i -e "s/^.*AutoLoginUser=.*/AutoLoginUser=${username}/" /usr/share/config/kdm/kdmrc
# 	sed -i -e "s/^.*AutoLoginPass=.*/AutoLoginPass=${username}/" /usr/share/config/kdm/kdmrc
# 	
# 	_dm='kdm'
#     fi
# 
#     # do_setupgdm
#     if [ -e "/usr/bin/gdm" ] ; then
# 	getent group gdm >/dev/null 2>&1 || groupadd -g 120 gdm
# 	getent passwd gdm > /dev/null 2>&1 || usr/bin/useradd -c 'Gnome Display Manager' -u 120 -g gdm -d /var/lib/gdm -s /usr/bin/nologin gdm
# 	passwd -l gdm > /dev/null
# 	chown -R gdm:gdm /var/lib/gdm &> /dev/null
# 	if [ -d "/var/lib/AccountsService/users" ] ; then
# 	    echo "[User]" > /var/lib/AccountsService/users/gdm
# 	    if [ -e "/usr/bin/startxfce4" ] ; then
# 		echo "XSession=xfce" >> /var/lib/AccountsService/users/gdm
# 	    fi
# 	    if [ -e "/usr/bin/cinnamon-session" ] ; then
# 		echo "XSession=cinnamon" >> /var/lib/AccountsService/users/gdm
# 	    fi
# 	    if [ -e "/usr/bin/mate-session" ] ; then
# 		echo "XSession=mate" >> /var/lib/AccountsService/users/gdm
# 	    fi
# 	    if [ -e "/usr/bin/enlightenment_start" ] ; then
# 		echo "XSession=enlightenment" >> /var/lib/AccountsService/users/gdm
# 	    fi
# 	    if [ -e "/usr/bin/openbox-session" ] ; then
# 		echo "XSession=openbox" >> /var/lib/AccountsService/users/gdm
# 	    fi
# 	    if [ -e "/usr/bin/startlxde" ] ; then
# 		echo "XSession=LXDE" >> /var/lib/AccountsService/users/gdm
# 	    fi
# 	    if [ -e "/usr/bin/lxqt-session" ] ; then
# 		echo "XSession=LXQt" >> /var/lib/AccountsService/users/gdm
# 	    fi
# 	    echo "Icon=" >> /var/lib/AccountsService/users/gdm
# 	fi
#       _dm='gdm'
#     fi
# 
#     # do_setupmdm
#     if [ -e "/usr/bin/mdm" ] ; then
# 	getent group mdm >/dev/null 2>&1 || groupadd -g 128 mdm
# 	getent passwd mdm >/dev/null 2>&1 || usr/bin/useradd -c 'Linux Mint Display Manager' -u 128 -g mdm -d /var/lib/mdm -s /usr/bin/nologin mdm
# 	passwd -l mdm > /dev/null
# 	chown root:mdm /var/lib/mdm > /dev/null
# 	chmod 1770 /var/lib/mdm > /dev/null
# 	if [ -e "/usr/bin/startxfce4" ] ; then
# 	    sed -i 's|default.desktop|xfce.desktop|g' /etc/mdm/custom.conf
# 	fi
# 	if [ -e "/usr/bin/cinnamon-session" ] ; then
# 	    sed -i 's|default.desktop|cinnamon.desktop|g' /etc/mdm/custom.conf
# 	fi
# 	if [ -e "/usr/bin/openbox-session" ] ; then
# 	    sed -i 's|default.desktop|openbox.desktop|g' /etc/mdm/custom.conf
# 	fi
# 	if [ -e "/usr/bin/mate-session" ] ; then
# 	    sed -i 's|default.desktop|mate.desktop|g' /etc/mdm/custom.conf
# 	fi
# 	if [ -e "/usr/bin/startlxde" ] ; then
# 	    sed -i 's|default.desktop|LXDE.desktop|g' /etc/mdm/custom.conf
# 	fi
# 	if [ -e "/usr/bin/lxqt-session" ] ; then
# 	    sed -i 's|default.desktop|lxqt.desktop|g' /etc/mdm/custom.conf
# 	fi
# 	if [ -e "/usr/bin/enlightenment_start" ] ; then
# 	    sed -i 's|default.desktop|enlightenment.desktop|g' /etc/mdm/custom.conf
# 	fi
# 	_dm='mdm'
#     fi
# 
#     # do_setupsddm
#     if [ -e "/usr/bin/sddm" ] ; then
# 	getent group sddm > /dev/null 2>&1 || groupadd --system sddm
# 	getent passwd sddm > /dev/null 2>&1 || usr/bin/useradd -c "Simple Desktop Display Manager" --system -d /var/lib/sddm -s /usr/bin/nologin -g sddm sddm
# 	passwd -l sddm > /dev/null
# 	mkdir -p /var/lib/sddm
# 	chown -R sddm:sddm /var/lib/sddm > /dev/null
# 	sed -i -e "s|^User=.*|User=${username}|" /etc/sddm.conf
# 	if [ -e "/usr/bin/startxfce4" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=xfce.desktop|' /etc/sddm.conf
# 	fi
# 	if [ -e "/usr/bin/cinnamon-session" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=cinnamon.desktop|' /etc/sddm.conf
# 	fi
# 	if [ -e "/usr/bin/openbox-session" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=openbox.desktop|' /etc/sddm.conf
# 	fi
# 	if [ -e "/usr/bin/mate-session" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=mate.desktop|' /etc/sddm.conf
# 	fi
# 	if [ -e "/usr/bin/lxsession" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=LXDE.desktop|' /etc/sddm.conf
# 	fi
# 	if [ -e "/usr/bin/lxqt-session" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=lxqt.desktop|' /etc/sddm.conf
# 	fi
# 	if [ -e "/usr/bin/enlightenment_start" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=enlightenment.desktop|' /etc/sddm.conf
# 	fi
# 	if [ -e "/usr/bin/startkde" ] ; then
# 	    sed -i -e 's|^Session=.*|Session=plasma.desktop|' /etc/sddm.conf
# 	fi
# 	_dm='sddm'
#     fi
# 
#     # do_setuplxdm
#     if [ -e "/usr/bin/lxdm" ] ; then
# 	if [ -z "`getent group "lxdm" 2> /dev/null`" ]; then
# 	      groupadd --system lxdm > /dev/null
# 	fi
# 	sed -i -e "s/^.*autologin=.*/autologin=${username}/" /etc/lxdm/lxdm.conf
# 	if [ -e "/usr/bin/startxfce4" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/startxfce4|' /etc/lxdm/lxdm.conf
# 	fi
# 	if [ -e "/usr/bin/cinnamon-session" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/cinnamon-session|' /etc/lxdm/lxdm.conf
# 	fi
# 	if [ -e "/usr/bin/mate-session" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/mate-session|' /etc/lxdm/lxdm.conf
# 	fi
# 	if [ -e "/usr/bin/enlightenment_start" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/enlightenment_start|' /etc/lxdm/lxdm.conf
# 	fi
# 	if [ -e "/usr/bin/openbox-session" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/openbox-session|' /etc/lxdm/lxdm.conf
# 	fi
# 	if [ -e "/usr/bin/startlxde" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/lxsession|' /etc/lxdm/lxdm.conf
# 	fi
# 	if [ -e "/usr/bin/lxqt-session" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/lxqt-session|' /etc/lxdm/lxdm.conf
# 	fi
# 	if [ -e "/usr/bin/pekwm" ] ; then
# 	    sed -i -e 's|^.*session=.*|session=/usr/bin/pekwm|' /etc/lxdm/lxdm.conf
# 	fi
# 	chgrp -R lxdm /var/lib/lxdm > /dev/null
# 	chgrp lxdm /etc/lxdm/lxdm.conf > /dev/null
# 	chmod +r /etc/lxdm/lxdm.conf > /dev/null
# 	_dm='lxdm'
#     fi
#     
#     if [[ -e /run/openrc ]];then
# 	local _conf_xdm='DISPLAYMANAGER="'${_dm}'"'
# 	echo "set ${_conf_xdm}" >> /tmp/livecd.log
# 	sed -i -e "s|^.*DISPLAYMANAGER=.*|${_conf_xdm}|" /etc/conf.d/xdm
#     fi
# }

_configure_translation_pkgs()
{
    # Determind which language we are using
    local LNG_INST=$(cat ${DESTDIR}/etc/locale.conf | grep LANG= | cut -d= -f2 | cut -d. -f1)

    [ -n "$LNG_INST" ] || LNG_INST="en"
    case "$LNG_INST" in
                     be_BY)
                           #Belarusian
                           FIREFOX_LNG_INST="firefox-i18n-be"
                           THUNDER_LNG_INST="thunderbird-i18n-be"
                           LIBRE_LNG_INST="libreoffice-be"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST=""
                           ;;
                     bg_BG)
                           #Bulgarian
                           FIREFOX_LNG_INST="firefox-i18n-bg"
                           THUNDER_LNG_INST="thunderbird-i18n-bg"
                           LIBRE_LNG_INST="libreoffice-bg"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST="kde-l10n-bg"
                           ;;
                     de*)
                           #German
                           FIREFOX_LNG_INST="firefox-i18n-de"
                           THUNDER_LNG_INST="thunderbird-i18n-de"
                           LIBRE_LNG_INST="libreoffice-de"
                           HUNSPELL_LNG_INST="hunspell-de"
                           KDE_LNG_INST="kde-l10n-de"
                           ;;
                     en*)
                           #English (disabled libreoffice-en-US)
                           FIREFOX_LNG_INST=""
                           THUNDER_LNG_INST=""
                           LIBRE_LNG_INST=""
                           HUNSPELL_LNG_INST="hunspell-en"
                           KDE_LNG_INST=""
                           ;;
                     en_GB)
                           #British English
                           FIREFOX_LNG_INST="firefox-i18n-en-gb"
                           THUNDER_LNG_INST="thunderbird-i18n-en-gb"
                           LIBRE_LNG_INST="libreoffice-en-GB"
                           HUNSPELL_LNG_INST="hunspell-en"
                           KDE_LNG_INST=""
                           ;;
                     es*)
                           #Espanol
                           FIREFOX_LNG_INST="firefox-i18n-es-es"
                           THUNDER_LNG_INST="thunderbird-i18n-es-es"
                           LIBRE_LNG_INST="libreoffice-es"
                           HUNSPELL_LNG_INST="hunspell-es"
                           KDE_LNG_INST="kde-l10n-es"
                           ;;
                     es_AR)
                           #Espanol (Argentina)
                           FIREFOX_LNG_INST="firefox-i18n-es-ar"
                           THUNDER_LNG_INST="thunderbird-i18n-es-ar"
                           LIBRE_LNG_INST="libreoffice-es"
                           HUNSPELL_LNG_INST="hunspell-es"
                           KDE_LNG_INST="kde-l10n-es"
                           ;;
                     fr*)
                           #Francais
                           FIREFOX_LNG_INST="firefox-i18n-fr"
                           THUNDER_LNG_INST="thunderbird-i18n-fr"
                           LIBRE_LNG_INST="libreoffice-fr"
                           HUNSPELL_LNG_INST="hunspell-fr"
                           KDE_LNG_INST="kde-l10n-fr"
                           ;;
                     it*)
                           #Italian
                           FIREFOX_LNG_INST="firefox-i18n-it"
                           THUNDER_LNG_INST="thunderbird-i18n-it"
                           LIBRE_LNG_INST="libreoffice-it"
                           HUNSPELL_LNG_INST="hunspell-it"
                           KDE_LNG_INST="kde-l10n-it"
                           ;;
                     pl_PL)
                           #Polish
                           FIREFOX_LNG_INST="firefox-i18n-pl"
                           THUNDER_LNG_INST="thunderbird-i18n-pl"
                           LIBRE_LNG_INST="libreoffice-pl"
                           HUNSPELL_LNG_INST="hunspell-pl"
                           KDE_LNG_INST="kde-l10n-pl"
                           ;;
                     pt_BR)
                           #Brazilian Portuguese
                           FIREFOX_LNG_INST="firefox-i18n-pt-br"
                           THUNDER_LNG_INST="thunderbird-i18n-pt-br"
                           LIBRE_LNG_INST="libreoffice-pt-BR"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST="kde-l10n-pt_br"
                           ;;
                     pt_PT)
                           #Portuguese
                           FIREFOX_LNG_INST="firefox-i18n-pt-pt"
                           THUNDER_LNG_INST="thunderbird-i18n-pt-pt"
                           LIBRE_LNG_INST="libreoffice-pt"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST="kde-l10n-pt"
                           ;;
                     ro_RO)
                           #Romanian
                           FIREFOX_LNG_INST="firefox-i18n-ro"
                           THUNDER_LNG_INST="thunderbird-i18n-ro"
                           LIBRE_LNG_INST="libreoffice-ro"
                           HUNSPELL_LNG_INST="hunspell-ro"
                           KDE_LNG_INST="kde-l10n-ro"
                           ;;
                     ru*)
                           #Russian
                           FIREFOX_LNG_INST="firefox-i18n-ru"
                           THUNDER_LNG_INST="thunderbird-i18n-ru"
                           LIBRE_LNG_INST="libreoffice-ru"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST="kde-l10n-ru"
                           ;;
                     sv*)
                           #Swedish
                           FIREFOX_LNG_INST="firefox-i18n-sv-se"
                           THUNDER_LNG_INST="thunderbird-i18n-sv-se"
                           LIBRE_LNG_INST="libreoffice-sv"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST="kde-l10n-sv"
                           ;;
                     tr*)
                           #Turkish
                           FIREFOX_LNG_INST="firefox-i18n-tr"
                           THUNDER_LNG_INST="thunderbird-i18n-tr"
                           LIBRE_LNG_INST="libreoffice-tr"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST="kde-l10n-tr"
                           ;;
                     uk_UA)
                           #Ukrainian
                           FIREFOX_LNG_INST="firefox-i18n-uk"
                           THUNDER_LNG_INST="thunderbird-i18n-uk"
                           LIBRE_LNG_INST="libreoffice-uk"
                           HUNSPELL_LNG_INST=""
                           KDE_LNG_INST="kde-l10n-uk"
                           ;;
    esac
}
