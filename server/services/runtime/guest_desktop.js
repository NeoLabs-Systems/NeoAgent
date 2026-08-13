'use strict';

const path = require('path');
const { computerDisplayMode } = require('./computer_display');

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

function guestFbdevXorgConfig() {
  return `Section "Device"
    Identifier "NeoAgentGPU"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
EndSection
Section "Screen"
    Identifier "NeoAgentScreen"
    Device "NeoAgentGPU"
    DefaultDepth 16
    SubSection "Display"
        Depth 16
    EndSubSection
EndSection
`;
}

function guestDesktopRepairCommand() {
  const lightdm = Buffer.from(guestLightDmConfig()).toString('base64');
  const fbdev = Buffer.from(guestFbdevXorgConfig()).toString('base64');
  const script = [
    'install -d -m 0755 /etc/lightdm/lightdm.conf.d /etc/X11/xorg.conf.d',
    'rm -f /etc/X11/xorg.conf.d/10-neoagent-display.conf',
    `echo ${lightdm} | base64 -d > /etc/lightdm/lightdm.conf.d/50-neoagent.conf`,
    'if [ -e /dev/fb0 ] && [ ! -e /dev/dri/card0 ]; then'
      + ` echo ${fbdev} | base64 -d > /etc/X11/xorg.conf.d/10-neoagent-display.conf; fi`,
    'systemctl set-default graphical.target || true',
    'systemctl enable lightdm.service neoagent-desktop-seat.service || true',
    'systemctl restart lightdm.service || true',
    'for i in 1 2 3 4 5 6 7 8 9 10 11 12; do'
      + ' if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then chvt 7 || true; exit 0; fi; sleep 1; done',
    'if [ -e /dev/fb0 ]; then'
      + ` echo ${fbdev} | base64 -d > /etc/X11/xorg.conf.d/10-neoagent-display.conf;`
      + ' systemctl restart lightdm.service || true;'
      + ' for i in 1 2 3 4 5 6 7 8; do'
      + ' if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then chvt 7 || true; exit 0; fi; sleep 1; done; fi',
    'exit 1',
  ].join(' ; ');
  return `sudo -n /bin/sh -c ${JSON.stringify(script)}`;
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
xserver-command=X -nolisten tcp vt7
display-setup-script=/usr/local/bin/neoagent-display-setup
`;
}

function getGuestDesktopSystemFiles() {
  const mode = computerDisplayMode();
  return [
    fileEntry('/usr/local/bin/neoagent-apply-desktop-home', `#!/bin/sh
set -eu
install -d -m 0755 /home/neo /home/neo/.config /home/neo/Desktop /home/neo/Downloads /home/neo/workspace
cp -a /usr/share/neoagent/desktop-skel/. /home/neo/
chmod 0755 /home/neo/Desktop/*.desktop
chown -R neo:neo /home/neo/.config /home/neo/Desktop /home/neo/Downloads /home/neo/workspace
`, '0755'),
    fileEntry('/usr/local/bin/neoagent-display-setup', `#!/bin/sh
chvt 7 >/dev/null 2>&1 || true
output=$(xrandr 2>/dev/null | awk '/ connected/{print $1; exit}')
[ -n "$output" ] || exit 0
if ! xrandr --output "$output" --mode ${mode} >/dev/null 2>&1; then
  xrandr --newmode "1280x720_60.00" 74.50 1280 1344 1472 1664 720 723 728 748 -hsync +vsync >/dev/null 2>&1 || true
  xrandr --addmode "$output" "1280x720_60.00" >/dev/null 2>&1 || true
  xrandr --output "$output" --mode "1280x720_60.00" >/dev/null 2>&1 || xrandr -s ${mode} >/dev/null 2>&1 || true
fi
exit 0
`, '0755'),
    fileEntry('/etc/modules-load.d/neoagent-gpu.conf', `virtio_gpu
virtio-gpu
`),
    fileEntry('/usr/local/bin/neoagent-ensure-desktop', `#!/bin/sh
install -d -m 0755 /etc/lightdm/lightdm.conf.d /etc/X11/xorg.conf.d
rm -f /etc/X11/xorg.conf.d/10-neoagent-display.conf
cat > /etc/lightdm/lightdm.conf.d/50-neoagent.conf <<'LIGHTDM'
${guestLightDmConfig().replace(/\n$/, '')}
LIGHTDM
if [ -e /dev/fb0 ] && [ ! -e /dev/dri/card0 ]; then
cat > /etc/X11/xorg.conf.d/10-neoagent-display.conf <<'FBDEV'
${guestFbdevXorgConfig().replace(/\n$/, '')}
FBDEV
fi
systemctl set-default graphical.target >/dev/null 2>&1 || true
systemctl enable lightdm.service neoagent-desktop-seat.service >/dev/null 2>&1 || true
systemctl restart lightdm.service >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
    chvt 7 >/dev/null 2>&1 || true
    exit 0
  fi
  sleep 1
done
if [ -e /dev/fb0 ]; then
cat > /etc/X11/xorg.conf.d/10-neoagent-display.conf <<'FBDEV'
${guestFbdevXorgConfig().replace(/\n$/, '')}
FBDEV
  systemctl restart lightdm.service >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8; do
    if DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
      chvt 7 >/dev/null 2>&1 || true
      exit 0
    fi
    sleep 1
  done
fi
exit 1
`, '0755'),
    fileEntry('/etc/lightdm/lightdm.conf.d/50-neoagent.conf', guestLightDmConfig()),
    fileEntry('/etc/systemd/system/neoagent-desktop-seat.service', `[Unit]
Description=Show the NeoAgent desktop on the VNC console
After=lightdm.service
Wants=lightdm.service

[Service]
Type=oneshot
ExecStart=/bin/chvt 7
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
WantedBy=multi-user.target
`),
    fileEntry('/etc/xdg/openbox/rc.xml', OPENBOX_RC_XML),
    fileEntry('/etc/xdg/openbox/menu.xml', OPENBOX_MENU_XML),
    fileEntry('/etc/xdg/openbox/autostart', `xset -dpms
xset s off
xset s noblank
chvt 7 >/dev/null 2>&1 || true
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
  guestDesktopRepairCommand,
  guestFbdevXorgConfig,
  guestLightDmConfig,
  renderDesktopCloudInitWriteFiles,
  renderDesktopFileCommands,
};
