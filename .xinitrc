#I don't need them to be active at all time, I can toggle them from dmenu
#blueman-applet&
#nm-applet&
setxkbmap -layout us -variant altgr-intl
/etc/X11/xinit/xinitrc.d/50-systemd-user.sh
gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg
/etc/X11/xinitrc.d/50-systemd-user.sh
/usr/bin/lxpolkit&
wmname LG3D
numlockx
xss-lock slock&
~/.fehbg &
while type dwm > /dev/null;do dwm && continue || break; done
