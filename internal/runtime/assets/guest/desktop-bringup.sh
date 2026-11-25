#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
needs_pkgs=0
command -v Xorg >/dev/null 2>&1 || command -v X >/dev/null 2>&1 || needs_pkgs=1
command -v xdpyinfo >/dev/null 2>&1 || needs_pkgs=1
command -v openbox >/dev/null 2>&1 || needs_pkgs=1
if [ "$needs_pkgs" -eq 1 ]; then
  apt-get update -qq || true
  apt-get install -y --no-install-recommends dbus-x11 lightdm lightdm-gtk-greeter openbox x11-xserver-utils xdotool xserver-xorg-core xserver-xorg-input-libinput xserver-xorg-video-fbdev || true
fi
install -d -m 0755 /etc/lightdm/lightdm.conf.d /etc/X11/xorg.conf.d /usr/local/bin /etc/systemd/system /etc/systemd/system-generators
ln -sfn /dev/null /etc/systemd/system-generators/systemd-ssh-generator
install -d -m 0755 /etc/modules-load.d
printf '%s
' bochs virtio_gpu > /etc/modules-load.d/neoagent-gpu.conf
cat > /usr/local/bin/neoagent-display-setup <<'SETUP'
#!/bin/sh
chvt 1 >/dev/null 2>&1 || true
exit 0
SETUP
chmod 0755 /usr/local/bin/neoagent-display-setup
cat > /usr/local/bin/neoagent-framebuffer-desktop <<'FRAMEBUFFER'
#!/bin/sh
unbind_fbcon() {
  echo 0 > /proc/sys/kernel/printk 2>/dev/null || true
  for cons in /sys/class/vtconsole/vtcon*; do
    if grep -qi frame "$cons/name" 2>/dev/null; then
      echo 0 > "$cons/bind" 2>/dev/null || true
    fi
  done
}

modprobe virtio_gpu >/dev/null 2>&1 || true
modprobe bochs >/dev/null 2>&1 || true
i=0
while [ "$i" -lt 8 ] && [ ! -e /dev/dri/card0 ]; do
  i=$((i + 1))
  sleep 1
done
for cons in /sys/class/vtconsole/vtcon*; do
  if grep -qi frame "$cons/name" 2>/dev/null; then
    echo 1 > "$cons/bind" 2>/dev/null || true
  fi
done

systemctl stop getty@tty1.service >/dev/null 2>&1 || true
systemctl stop lightdm.service >/dev/null 2>&1 || true
install -d -m 0755 /etc/X11/xorg.conf.d
rm -f /etc/X11/xorg.conf /etc/X11/xorg.conf.d/10-neoagent-display.conf
if [ ! -e /dev/dri/card0 ]; then
  unbind_fbcon
  cat > /etc/X11/xorg.conf.d/10-neoagent-display.conf <<'FBDEV24'
Section "Device"
    Identifier "NeoAgentGPU"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
    Option "ShadowFB" "true"
EndSection
Section "Screen"
    Identifier "NeoAgentScreen"
    Device "NeoAgentGPU"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
    EndSubSection
EndSection
Section "ServerFlags"
    Option "DontZap" "true"
    Option "AutoAddGPU" "false"
EndSection
FBDEV24
  cp /etc/X11/xorg.conf.d/10-neoagent-display.conf /etc/X11/xorg.conf
fi
pkill -x Xorg >/dev/null 2>&1 || true
pkill -x X >/dev/null 2>&1 || true
sleep 1
xbin=$(command -v Xorg || command -v X || true)
if [ -z "$xbin" ]; then
  echo "Xorg is not installed" >&2
  exit 1
fi
"$xbin" :0 vt1 -nolisten tcp >/var/log/neoagent-xorg-direct.log 2>&1 &
xpid=$!
i=0
while [ "$i" -lt 20 ]; do
  if [ -S /tmp/.X11-unix/X0 ]; then
    break
  fi
  if ! kill -0 "$xpid" 2>/dev/null; then
    echo "Xorg exited during startup" >&2
    tail -n 40 /var/log/neoagent-xorg-direct.log >&2 || true
    tail -n 40 /var/log/Xorg.0.log >&2 || true
    exit 1
  fi
  i=$((i + 1))
  sleep 1
done
if [ ! -S /tmp/.X11-unix/X0 ]; then
  echo "Xorg did not create :0" >&2
  tail -n 40 /var/log/neoagent-xorg-direct.log >&2 || true
  exit 1
fi
chvt 1 >/dev/null 2>&1 || true
session=openbox
command -v openbox-session >/dev/null 2>&1 && session=openbox-session
if command -v dbus-launch >/dev/null 2>&1; then
  su - neo -c "DISPLAY=:0 dbus-launch --exit-with-session $session" >/tmp/neoagent-openbox.log 2>&1 &
else
  su - neo -c "DISPLAY=:0 $session" >/tmp/neoagent-openbox.log 2>&1 &
fi
wait "$xpid"
FRAMEBUFFER
chmod 0755 /usr/local/bin/neoagent-framebuffer-desktop
cat > /etc/systemd/system/neoagent-framebuffer-desktop.service <<'FBUNIT'
[Unit]
Description=NeoAgent framebuffer desktop
After=local-fs.target
Conflicts=getty@tty1.service
ConditionPathExists=|/dev/dri/card0
ConditionPathExists=|/dev/fb0

[Service]
Type=simple
ExecStart=/usr/local/bin/neoagent-framebuffer-desktop
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
FBUNIT
cat > /etc/systemd/system/neoagent-desktop-seat.service <<'UNIT'
[Unit]
Description=Show the NeoAgent desktop on the VNC console
After=lightdm.service neoagent-framebuffer-desktop.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'chvt 1 >/dev/null 2>&1 || true'
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
WantedBy=multi-user.target
UNIT
cat > /etc/lightdm/lightdm.conf.d/50-neoagent.conf <<'LIGHTDM'
[LightDM]
start-default-seat=true
logind-check-graphical=false

[Seat:*]
autologin-user=neo
autologin-user-timeout=0
autologin-session=openbox
user-session=openbox
xserver-command=X -nolisten tcp vt1
display-setup-script=/usr/local/bin/neoagent-display-setup
LIGHTDM
install -d -m 0755 /etc/xdg/tint2 /etc/xdg/openbox
cat > /etc/xdg/tint2/tint2rc <<'TINT2'
# NeoAgent shelf — Chromebook-style bottom launcher
rounded = 16
border_width = 0
background_color = #121916 92
border_color = #121916 0
background_color_hover = #24332c 100
background_color_pressed = #1b2621 100

rounded = 8
border_width = 0
background_color = #2f4a3e 100
border_color = #2f4a3e 0

rounded = 10
border_width = 0
background_color = #1b2621 0
border_color = #1b2621 0

panel_monitor = all
panel_position = bottom center horizontal
panel_size = 92% 52
panel_margin = 0 10
panel_padding = 10 6 10
panel_background_id = 1
wm_menu = 1
panel_dock = 0
panel_layer = top
panel_items = LTSC
autohide = 1
autohide_show_timeout = 0.15
autohide_hide_timeout = 0.4
autohide_height = 2
strut_policy = none

launcher_icon_size = 28
launcher_item_app = /usr/local/share/applications/neoagent-chromium.desktop
launcher_item_app = /usr/local/share/applications/neoagent-files.desktop
launcher_item_app = /usr/local/share/applications/neoagent-terminal.desktop
launcher_item_app = /usr/local/share/applications/neoagent-editor.desktop
launcher_icon_theme = Adwaita
launcher_padding = 6 0 8
launcher_background_id = 3

task_text = 1
task_font = sans 9
task_font_color = #e8efe6 100
task_active_font_color = #f4f7f2 100
task_icon_size = 20
task_centered = 1
task_maximum_size = 180 38
task_padding = 10 4 8
task_background_id = 3
task_active_background_id = 2
task_tooltip = 1
urgent_nb_of_blink = 8

systray_padding = 4 0 6
systray_icon_size = 18
systray_icon_asb = 100 0 0

clock_format = %a %H:%M
clock_font = sans 9
clock_font_color = #e8efe6 100
clock_padding = 10 0
clock_background_id = 3
TINT2
cat > /etc/xdg/openbox/rc.xml <<'OPENBOX'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>
  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Mouse</monitor>
  </placement>
  <theme>
    <name>NeoAgent</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>no</animateIconify>
    <font place="ActiveWindow"><name>sans</name><size>9</size><weight>Bold</weight></font>
    <font place="InactiveWindow"><name>sans</name><size>9</size><weight>Bold</weight></font>
    <font place="MenuHeader"><name>sans</name><size>9</size><weight>Bold</weight></font>
    <font place="MenuItem"><name>sans</name><size>9</size><weight>Normal</weight></font>
    <font place="ActiveOnScreenDisplay"><name>sans</name><size>9</size></font>
    <font place="InactiveOnScreenDisplay"><name>sans</name><size>9</size></font>
  </theme>
  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <popupTime>0</popupTime>
  </desktops>
  <resize>
    <drawContents>yes</drawContents>
    <popupShow>Nonpixel</popupShow>
    <popupPosition>Center</popupPosition>
  </resize>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
    <keybind key="A-F4"><action name="Close" /></keybind>
    <keybind key="A-F10"><action name="ToggleMaximize" /></keybind>
    <keybind key="A-Tab">
      <action name="NextWindow">
        <finalactions><action name="Focus" /><action name="Raise" /></finalactions>
      </action>
    </keybind>
    <keybind key="A-S-Tab">
      <action name="PreviousWindow">
        <finalactions><action name="Focus" /><action name="Raise" /></finalactions>
      </action>
    </keybind>
    <keybind key="W-space"><action name="ShowMenu"><menu>root-menu</menu></action></keybind>
    <keybind key="Super_L"><action name="ShowMenu"><menu>root-menu</menu></action></keybind>
    <keybind key="W-t"><action name="Execute"><command>lxterminal --working-directory=/home/neo/workspace</command></action></keybind>
    <keybind key="W-e"><action name="Execute"><command>pcmanfm /home/neo/workspace</command></action></keybind>
    <keybind key="W-b"><action name="Execute"><command>chromium --user-data-dir=/home/neo/.neoagent/data/browser-profiles/default --no-first-run --no-default-browser-check --restore-last-session --hide-crash-restore-bubble --disable-session-crashed-bubble --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --remote-allow-origins=*</command></action></keybind>
  </keyboard>
  <mouse>
    <dragThreshold>3</dragThreshold>
    <doubleClickTime>300</doubleClickTime>
    <screenEdgeWarpTime>0</screenEdgeWarpTime>
    <context name="Frame">
      <mousebind button="A-Left" action="Drag"><action name="Move" /></mousebind>
      <mousebind button="A-Right" action="Drag"><action name="Resize" /></mousebind>
    </context>
    <context name="Titlebar">
      <mousebind button="Left" action="Drag"><action name="Move" /></mousebind>
      <mousebind button="Left" action="DoubleClick"><action name="ToggleMaximize" /></mousebind>
      <mousebind button="Right" action="Press"><action name="ShowMenu"><menu>client-menu</menu></action></mousebind>
    </context>
    <context name="Titlebar Top Right Bottom Left TLCorner TRCorner BRCorner BLCorner">
      <mousebind button="Left" action="Press"><action name="Focus" /><action name="Raise" /></mousebind>
    </context>
    <context name="Client">
      <mousebind button="Left" action="Press"><action name="Focus" /><action name="Raise" /></mousebind>
      <mousebind button="Middle" action="Press"><action name="Focus" /><action name="Raise" /></mousebind>
      <mousebind button="Right" action="Press"><action name="Focus" /><action name="Raise" /></mousebind>
    </context>
    <context name="Icon">
      <mousebind button="Left" action="Press"><action name="Focus" /><action name="Raise" /><action name="ShowMenu"><menu>client-menu</menu></action></mousebind>
    </context>
    <context name="Maximize">
      <mousebind button="Left" action="Click"><action name="Focus" /><action name="Raise" /><action name="ToggleMaximize" /></mousebind>
    </context>
    <context name="Close">
      <mousebind button="Left" action="Click"><action name="Focus" /><action name="Raise" /><action name="Close" /></mousebind>
    </context>
    <context name="Desktop">
      <mousebind button="Right" action="Press"><action name="ShowMenu"><menu>root-menu</menu></action></mousebind>
      <mousebind button="Left" action="Press"><action name="Focus" /></mousebind>
    </context>
    <context name="Root">
      <mousebind button="Right" action="Press"><action name="ShowMenu"><menu>root-menu</menu></action></mousebind>
    </context>
  </mouse>
  <menu>
    <file>/etc/xdg/openbox/menu.xml</file>
    <hideDelay>150</hideDelay>
    <middle>no</middle>
    <submenuShowDelay>100</submenuShowDelay>
    <applicationIcons>yes</applicationIcons>
    <manageDesktops>no</manageDesktops>
  </menu>
  <applications>
    <application class="*">
      <decor>yes</decor>
      <maximized>false</maximized>
    </application>
    <application class="Chromium-browser">
      <maximized>yes</maximized>
    </application>
    <application class="chromium">
      <maximized>yes</maximized>
    </application>
  </applications>
</openbox_config>
OPENBOX
if [ -f /etc/default/grub ]; then
  sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"/' /etc/default/grub || true
  update-grub >/dev/null 2>&1 || true
fi
systemctl stop getty@tty1.service >/dev/null 2>&1 || true
systemctl mask getty@tty1.service >/dev/null 2>&1 || true
systemctl stop serial-getty@tty1.service >/dev/null 2>&1 || true
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl set-default graphical.target >/dev/null 2>&1 || true
systemctl enable neoagent-framebuffer-desktop.service neoagent-desktop-seat.service >/dev/null 2>&1 || true
wait_for_x() {
  tries=$1
  i=0
  while [ "$i" -lt "$tries" ]; do
    if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
      chvt 1 >/dev/null 2>&1 || true
      echo DESKTOP_READY
      exit 0
    fi
    i=$((i + 1))
    sleep 1
  done
}
if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
  echo DESKTOP_READY
  exit 0
fi
modprobe virtio_gpu >/dev/null 2>&1 || true
modprobe bochs >/dev/null 2>&1 || true
systemctl stop lightdm.service >/dev/null 2>&1 || true
systemctl restart neoagent-framebuffer-desktop.service >/dev/null 2>&1 || true
wait_for_x 25
systemctl reset-failed lightdm.service >/dev/null 2>&1 || true
systemctl enable lightdm.service >/dev/null 2>&1 || true
systemctl restart lightdm.service >/dev/null 2>&1 || true
systemctl start neoagent-desktop-seat.service >/dev/null 2>&1 || true
wait_for_x 20
echo DESKTOP_FAILED
echo "--- framebuffer ---"
systemctl --no-pager --full status neoagent-framebuffer-desktop 2>&1 | tail -n 20 || true
echo "--- lightdm ---"
systemctl --no-pager --full status lightdm 2>&1 | tail -n 20 || true
echo "--- journal ---"
journalctl -u neoagent-framebuffer-desktop -u lightdm -n 40 --no-pager 2>&1 || true
echo "--- xorg ---"
tail -n 40 /var/log/Xorg.0.log 2>/dev/null || true
tail -n 20 /var/log/neoagent-xorg-direct.log 2>/dev/null || true
echo "--- devices ---"
ls -l /dev/fb0 /dev/dri /tmp/.X11-unix /dev/tty1 2>&1 || true
cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null || true
fgconsole 2>/dev/null || true
exit 1
