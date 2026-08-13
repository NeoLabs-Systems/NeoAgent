'use strict';

const path = require('path');

function fileEntry(filePath, content, mode = '0644') {
  return {
    path: filePath,
    content: String(content).replace(/^\n+/, '').replace(/\n+$/, '') + '\n',
    mode,
  };
}

function getGuestDesktopSkelFiles() {
  return getGuestDesktopHomeFiles().map((file) => ({
    ...file,
    path: `/usr/share/neoagent/desktop-skel${file.path.replace(/^\/home\/neo/, '')}`,
  }));
}

function guestFbdevXorgConfig(depth = 24) {
  const screenDepth = Number(depth) === 16 ? 16 : 24;
  return `Section "Device"
    Identifier "NeoAgentGPU"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
    Option "ShadowFB" "true"
EndSection
Section "Screen"
    Identifier "NeoAgentScreen"
    Device "NeoAgentGPU"
    DefaultDepth ${screenDepth}
    SubSection "Display"
        Depth ${screenDepth}
    EndSubSection
EndSection
Section "ServerFlags"
    Option "DontZap" "true"
    Option "AutoAddGPU" "false"
EndSection
`;
}

function guestDesktopPackages() {
  return [
    'dbus-x11',
    'lightdm',
    'lightdm-gtk-greeter',
    'openbox',
    'x11-xserver-utils',
    'xdotool',
    'xserver-xorg-core',
    'xserver-xorg-input-libinput',
    'xserver-xorg-video-fbdev',
  ].join(' ');
}

function guestDisplaySetupScript() {
  return `#!/bin/sh
chvt 1 >/dev/null 2>&1 || true
exit 0
`;
}

function guestDesktopSeatUnit() {
  return `[Unit]
Description=Show the NeoAgent desktop on the VNC console
After=lightdm.service neoagent-framebuffer-desktop.service

[Service]
Type=oneshot
ExecStart=/bin/chvt 1
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
WantedBy=multi-user.target
`;
}

function guestFramebufferDesktopUnit() {
  return `[Unit]
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
`;
}

function guestFramebufferDesktopScript() {
  const fbdev24 = guestFbdevXorgConfig(24).replace(/\n$/, '');
  return `#!/bin/sh
unbind_fbcon() {
  echo 0 > /proc/sys/kernel/printk 2>/dev/null || true
  for cons in /sys/class/vtconsole/vtcon*; do
    if grep -qi frame "$cons/name" 2>/dev/null; then
      echo 0 > "$cons/bind" 2>/dev/null || true
    fi
  done
}

modprobe virtio_gpu >/dev/null 2>&1 || true
modprobe virtio-gpu >/dev/null 2>&1 || true
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
${fbdev24}
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
`;
}

function guestDesktopBringUpScript() {
  const setup = guestDisplaySetupScript().replace(/\n$/, '');
  const seat = guestDesktopSeatUnit().replace(/\n$/, '');
  const framebufferUnit = guestFramebufferDesktopUnit().replace(/\n$/, '');
  const framebuffer = guestFramebufferDesktopScript().replace(/\n$/, '');
  const lightdm = guestLightDmConfig().replace(/\n$/, '');
  const packages = guestDesktopPackages();
  return `#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
needs_pkgs=0
command -v Xorg >/dev/null 2>&1 || command -v X >/dev/null 2>&1 || needs_pkgs=1
command -v xdpyinfo >/dev/null 2>&1 || needs_pkgs=1
command -v openbox >/dev/null 2>&1 || needs_pkgs=1
if [ "$needs_pkgs" -eq 1 ]; then
  apt-get update -qq || true
  apt-get install -y --no-install-recommends ${packages} || true
fi
install -d -m 0755 /etc/lightdm/lightdm.conf.d /etc/X11/xorg.conf.d /usr/local/bin /etc/systemd/system /etc/systemd/system-generators
ln -sfn /dev/null /etc/systemd/system-generators/systemd-ssh-generator
install -d -m 0755 /etc/modules-load.d /etc/initramfs-tools
printf '%s\n' virtio_gpu virtio-gpu > /etc/modules-load.d/neoagent-gpu.conf
if [ -f /etc/initramfs-tools/modules ]; then
  grep -qxF virtio_gpu /etc/initramfs-tools/modules || echo virtio_gpu >> /etc/initramfs-tools/modules
fi
cat > /usr/local/bin/neoagent-display-setup <<'SETUP'
${setup}
SETUP
chmod 0755 /usr/local/bin/neoagent-display-setup
cat > /usr/local/bin/neoagent-framebuffer-desktop <<'FRAMEBUFFER'
${framebuffer}
FRAMEBUFFER
chmod 0755 /usr/local/bin/neoagent-framebuffer-desktop
cat > /etc/systemd/system/neoagent-framebuffer-desktop.service <<'FBUNIT'
${framebufferUnit}
FBUNIT
cat > /etc/systemd/system/neoagent-desktop-seat.service <<'UNIT'
${seat}
UNIT
cat > /etc/lightdm/lightdm.conf.d/50-neoagent.conf <<'LIGHTDM'
${lightdm}
LIGHTDM
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
modprobe virtio_gpu >/dev/null 2>&1 || true
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
`;
}

function guestDesktopRepairCommand() {
  return `sudo -n /bin/sh -c ${JSON.stringify(guestDesktopBringUpScript())}`;
}

const DESKTOP_REPAIR_NOISE = /systemd-sysv-install|Synchronizing state of \S+ with SysV|Executing:\s*\/usr\/lib\/systemd\/systemd-sysv-install/i;

function summarizeDesktopRepairOutput(result = {}, fallback = 'The Linux graphical session is not running.') {
  const stdout = String(result?.stdout || '');
  const stderr = String(result?.stderr || '');
  if (stdout.includes('DESKTOP_READY')) {
    return { available: true, error: null };
  }
  const combined = [stdout, stderr].filter(Boolean).join('\n');
  const marker = 'DESKTOP_FAILED';
  const diagnostic = combined.includes(marker)
    ? combined.slice(combined.indexOf(marker) + marker.length)
    : combined;
  const lines = diagnostic
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .filter((line) => !DESKTOP_REPAIR_NOISE.test(line))
    .filter((line) => !/^--- /.test(line));
  const preferred = lines.filter((line) => (
    /\(EE\)|Failed|failed|error|fatal|not found|No screens/i.test(line)
  ));
  const picked = (preferred.length ? preferred : lines).slice(-8).join(' ').replace(/\s+/g, ' ').trim();
  const fallbackText = String(fallback || '').trim() || 'The Linux graphical session is not running.';
  return {
    available: false,
    error: (picked || fallbackText).slice(0, 500),
  };
}

function guestLightDmConfig() {
  return `[LightDM]
start-default-seat=true
logind-check-graphical=false

[Seat:*]
autologin-user=neo
autologin-user-timeout=0
autologin-session=openbox
user-session=openbox
xserver-command=X -nolisten tcp vt1
display-setup-script=/usr/local/bin/neoagent-display-setup
`;
}

function getGuestDesktopSystemFiles() {
  return [
    fileEntry('/usr/local/bin/neoagent-apply-desktop-home', `#!/bin/sh
set -eu
install -d -m 0755 /home/neo /home/neo/.config /home/neo/Desktop /home/neo/Downloads /home/neo/workspace
cp -a /usr/share/neoagent/desktop-skel/. /home/neo/
chmod 0755 /home/neo/Desktop/*.desktop
chown -R neo:neo /home/neo/.config /home/neo/Desktop /home/neo/Downloads /home/neo/workspace
`, '0755'),
    fileEntry('/etc/modules-load.d/neoagent-gpu.conf', `virtio_gpu
virtio-gpu
`),
    fileEntry('/usr/local/bin/neoagent-display-setup', guestDisplaySetupScript(), '0755'),
    fileEntry('/usr/local/bin/neoagent-framebuffer-desktop', guestFramebufferDesktopScript(), '0755'),
    fileEntry('/usr/local/bin/neoagent-ensure-desktop', guestDesktopBringUpScript(), '0755'),
    fileEntry('/etc/lightdm/lightdm.conf.d/50-neoagent.conf', guestLightDmConfig()),
    fileEntry('/etc/systemd/system/neoagent-framebuffer-desktop.service', guestFramebufferDesktopUnit()),
    fileEntry('/etc/systemd/system/neoagent-desktop-seat.service', guestDesktopSeatUnit()),
    fileEntry('/etc/xdg/openbox/rc.xml', OPENBOX_RC_XML),
    fileEntry('/etc/xdg/openbox/menu.xml', OPENBOX_MENU_XML),
    fileEntry('/etc/xdg/openbox/autostart', `xset -dpms
xset s off
xset s noblank
chvt 1 >/dev/null 2>&1 || true
/usr/local/bin/neoagent-display-setup || true
pcmanfm --desktop --profile neoagent &
tint2 -c /etc/xdg/tint2/tint2rc &
`),
    fileEntry('/etc/xdg/tint2/tint2rc', TINT2_RC),
    fileEntry('/etc/xdg/pcmanfm/neoagent/pcmanfm.conf', `[config]
bm_open_method=0
su_cmd=sudo -A %s
autorun=1
media_in_new_tab=0
close_on_unmount=1

[volume]
mount_on_startup=1
mount_removable=1
autorun=1

[ui]
always_show_tabs=0
hide_close_btn=0
win_width=960
win_height=600
splitter_pos=180
max_tab_chars=32
view_mode=icon
show_hidden=0
show_thumbs=1
sort=name;ascending;
toolbar=newtab;navigation;home;
show_statusbar=1
pathbar_mode_buttons=0
`),
    fileEntry('/etc/xdg/pcmanfm/neoagent/desktop-items-0.conf', `[*]
wallpaper_mode=color
wallpaper_common=1
desktop_bg=#15201b
desktop_fg=#e8efe6
desktop_shadow=#0b100e
desktop_font=Sans 10
show_wm_menu=1
sort=name;ascending;
show_documents=0
show_trash=1
show_mounts=0
`),
    fileEntry('/etc/gtk-3.0/settings.ini', `[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-application-prefer-dark-theme=true
gtk-cursor-theme-size=24
gtk-decoration-layout=close,minimize,maximize:
`),
    fileEntry('/etc/xdg/lxterminal/lxterminal.conf', `[general]
fontname=Monospace 10
selchars=-A-Za-z0-9,./?%&#:_
scrollback=4000
bgcolor=rgb(15,20,18)
fgcolor=rgb(232,239,230)
palette_color_0=rgb(21,32,27)
palette_color_7=rgb(232,239,230)
palette_color_15=rgb(248,250,246)
disallowbold=false
cursorblinks=true
cursorunderline=false
audiblebell=false
tabpos=top
hidescrollbar=false
hidemenubar=false
hideclosebutton=false
hidepointer=false
disablef10=true
disablealt=false
`),
    fileEntry('/usr/share/themes/NeoAgent/openbox-3/themerc', OPENBOX_THEME),
    fileEntry('/usr/local/share/applications/neoagent-chromium.desktop', `[Desktop Entry]
Type=Application
Name=Chromium
Comment=Web browser
Exec=chromium --user-data-dir=/home/neo/.neoagent/data/browser-profiles/default --no-first-run --no-default-browser-check
Icon=chromium
Terminal=false
Categories=Network;WebBrowser;
`),
    fileEntry('/usr/local/share/applications/neoagent-files.desktop', `[Desktop Entry]
Type=Application
Name=Files
Comment=Browse files
Exec=pcmanfm /home/neo/workspace
Icon=system-file-manager
Terminal=false
Categories=Utility;FileManager;
`),
    fileEntry('/usr/local/share/applications/neoagent-terminal.desktop', `[Desktop Entry]
Type=Application
Name=Terminal
Comment=Command line
Exec=lxterminal --working-directory=/home/neo/workspace
Icon=utilities-terminal
Terminal=false
Categories=Utility;TerminalEmulator;
`),
    fileEntry('/usr/local/share/applications/neoagent-editor.desktop', `[Desktop Entry]
Type=Application
Name=Text Editor
Comment=Edit text files
Exec=mousepad
Icon=accessories-text-editor
Terminal=false
Categories=Utility;TextEditor;
`),
  ];
}

function getGuestDesktopHomeFiles() {
  return [
    fileEntry('/home/neo/.config/openbox/autostart', `# Session startup is owned by /etc/xdg/openbox/autostart
`),
    fileEntry('/home/neo/Desktop/Chromium.desktop', desktopShortcut(
      'Chromium',
      'chromium --user-data-dir=/home/neo/.neoagent/data/browser-profiles/default --no-first-run --no-default-browser-check',
      'chromium',
    ), '0755'),
    fileEntry('/home/neo/Desktop/Files.desktop', desktopShortcut(
      'Files',
      'pcmanfm /home/neo/workspace',
      'system-file-manager',
    ), '0755'),
    fileEntry('/home/neo/Desktop/Terminal.desktop', desktopShortcut(
      'Terminal',
      'lxterminal --working-directory=/home/neo/workspace',
      'utilities-terminal',
    ), '0755'),
    fileEntry('/home/neo/Desktop/Text-Editor.desktop', desktopShortcut(
      'Text Editor',
      'mousepad',
      'accessories-text-editor',
    ), '0755'),
  ];
}

function desktopShortcut(name, exec, icon) {
  return `[Desktop Entry]
Type=Application
Name=${name}
Exec=${exec}
Icon=${icon}
Terminal=false
`;
}

function renderDesktopFileCommands(files) {
  const commands = [];
  for (const file of files) {
    let delimiter = `NEOAGENT_FILE_${commands.length}`;
    const contentLines = new Set(file.content.split('\n'));
    while (contentLines.has(delimiter)) delimiter += '_';
    commands.push(`install -d -m 0755 ${shellQuote(path.posix.dirname(file.path))}`);
    commands.push(`cat > ${shellQuote(file.path)} <<'${delimiter}'`);
    commands.push(file.content.replace(/\n$/, ''));
    commands.push(delimiter);
    commands.push(`chmod ${file.mode} ${shellQuote(file.path)}`);
  }
  return commands;
}

function renderDesktopCloudInitWriteFiles(files, indent = '  ') {
  return files.flatMap((file) => [
    `${indent}- path: ${file.path}`,
    `${indent}  permissions: '${file.mode}'`,
    `${indent}  owner: root:root`,
    `${indent}  content: |`,
    ...file.content.replace(/\n$/, '').split('\n').map((line) => `${indent}    ${line}`),
  ]);
}

function shellQuote(value) {
  return JSON.stringify(String(value));
}

const OPENBOX_THEME = `# NeoAgent — compact dark window theme
border.width: 1
padding.width: 8
padding.height: 5
window.client.padding.width: 0
window.handle.width: 0
menu.border.width: 1
menu.overlap: 0
window.active.border.color: #3d5248
window.inactive.border.color: #1c2621
window.active.title.bg: Solid Flat
window.active.title.bg.color: #1b2621
window.inactive.title.bg: Solid Flat
window.inactive.title.bg.color: #121916
window.active.label.text.color: #e8efe6
window.inactive.label.text.color: #8b968d
window.active.label.text.font: sans:bold:size=9
window.inactive.label.text.font: sans:bold:size=9
window.active.button.unpressed.image.color: #d7e0d4
window.inactive.button.unpressed.image.color: #6f7a71
menu.items.bg: Solid Flat
menu.items.bg.color: #17201c
menu.items.text.color: #e8efe6
menu.items.active.bg: Solid Flat
menu.items.active.bg.color: #2b4036
menu.items.active.text.color: #f4f7f2
menu.title.bg: Solid Flat
menu.title.bg.color: #1b2621
menu.title.text.color: #e8efe6
`;

const OPENBOX_MENU_XML = `<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Applications">
    <item label="Chromium"><action name="Execute"><command>chromium --user-data-dir=/home/neo/.neoagent/data/browser-profiles/default --no-first-run --no-default-browser-check</command></action></item>
    <item label="Files"><action name="Execute"><command>pcmanfm /home/neo/workspace</command></action></item>
    <item label="Terminal"><action name="Execute"><command>lxterminal --working-directory=/home/neo/workspace</command></action></item>
    <item label="Text Editor"><action name="Execute"><command>mousepad</command></action></item>
    <separator />
    <item label="Reload desktop"><action name="Reconfigure" /></item>
  </menu>
</openbox_menu>
`;

const OPENBOX_RC_XML = `<?xml version="1.0" encoding="UTF-8"?>
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
    <keybind key="W-b"><action name="Execute"><command>chromium --user-data-dir=/home/neo/.neoagent/data/browser-profiles/default --no-first-run --no-default-browser-check</command></action></keybind>
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
  </applications>
</openbox_config>
`;

const TINT2_RC = `# NeoAgent shelf — Chromebook-style bottom launcher
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
autohide = 0
strut_policy = follow_size

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
`;

module.exports = {
  getGuestDesktopHomeFiles,
  getGuestDesktopSkelFiles,
  getGuestDesktopSystemFiles,
  guestDesktopBringUpScript,
  guestDesktopRepairCommand,
  guestFbdevXorgConfig,
  guestLightDmConfig,
  renderDesktopCloudInitWriteFiles,
  renderDesktopFileCommands,
  summarizeDesktopRepairOutput,
};
