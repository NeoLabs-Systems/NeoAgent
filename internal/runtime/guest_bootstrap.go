package runtime

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	_ "embed"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/vm"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

//go:embed assets/guest/bootstrap.sh.tmpl
var bootstrapTemplate string

const guestAppConfigDir = "/etc/neoagent"

// GuestBootstrap describes one computer's first boot.
type GuestBootstrap struct {
	GuestToken     string
	GuestAgentPort int
	// Agent is the static guest agent binary for the guest's architecture.
	Agent []byte
	// ServerPort is the port of this server, the only private address the
	// guest's firewall lets through (for the Git proxy).
	ServerPort int
}

func encodeGuestToken(token string) string {
	return base64.StdEncoding.EncodeToString([]byte(token))
}

// guestPayloadDigest identifies what a guest image contains of ours: the
// agent binary and the Tailscale installer. It names Docker image tags and
// stands in for the (large) agent in the cloud-init identity.
func guestPayloadDigest(agent []byte) string {
	h := sha256.New()
	h.Write([]byte(TailscaleInstallScript()))
	h.Write([]byte{0})
	h.Write(agent)
	return hex.EncodeToString(h.Sum(nil))
}

// CloudInitScript is the bootstrap script a template guest runs on first
// boot: it installs the desktop and tools, and configures the guest.
func CloudInitScript(guestToken string, guestAgentPort int) string {
	desktop := strings.Join(RenderDesktopFileCommands(append(GuestDesktopSystemFiles(), GuestDesktopSkelFiles()...)), "\n")
	replacer := strings.NewReplacer(
		"@@TOKEN_B64@@", encodeGuestToken(guestToken),
		"@@PORT@@", fmt.Sprint(guestAgentPort),
		"@@TAILSCALE_INSTALL@@", TailscaleInstallScript(),
		"@@DESKTOP_FILES@@", desktop,
	)
	return replacer.Replace(bootstrapTemplate)
}

func cloudInitPreamble() []string {
	return []string{
		"#cloud-config",
		"package_update: false",
		"users:",
		"  - default",
		"  - name: neo",
		"    gecos: NeoAgent",
		"    groups: [sudo, audio, video, netdev]",
		"    shell: /bin/bash",
		"    lock_passwd: true",
		"fs_setup:",
		"  - label: neoagent-data",
		"    filesystem: ext4",
		"    device: /dev/vdb",
		"    overwrite: false",
		"mounts:",
		fmt.Sprintf(`  - [LABEL=neoagent-data, %s, ext4, "defaults,nofail,discard", "0", "2"]`, guestproto.Home),
	}
}

func guestEnvWriteFile(tokenB64 string, port int) []string {
	return []string{
		"  - path: " + guestAppConfigDir + "/neoagent.env",
		"    permissions: '0600'",
		"    owner: root:root",
		"    content: |",
		"      NEOAGENT_VM_GUEST_TOKEN_B64=" + tokenB64,
		fmt.Sprintf("      NEOAGENT_GUEST_AGENT_PORT=%d", port),
		"      NEOAGENT_GUEST_PROFILE=browser_cli",
	}
}

var browserUnitEnvironment = []string{
	"      Environment=DISPLAY=:0",
	"      Environment=CHROMIUM_BIN=/usr/bin/chromium",
}

func guestAgentUnitWriteFile() []string {
	lines := []string{
		"  - path: /etc/systemd/system/neoagent-guest-agent.service",
		"    permissions: '0644'",
		"    owner: root:root",
		"    content: |",
		"      [Unit]",
		"      Description=NeoAgent guest agent",
		"      After=network-online.target",
		"      After=cloud-final.service",
		"      After=neoagent-guest-bootstrap.service",
		"      After=display-manager.service",
		"      ConditionPathExists=/etc/neoagent/neoagent.env",
		"      Wants=network-online.target",
		// The data disk mounts at the guest home; starting before it is mounted
		// leaves the agent writing into a directory the mount then hides.
		"      RequiresMountsFor=" + guestproto.Home,
		"",
		"      [Service]",
		"      Type=simple",
		"      User=neo",
		"      Group=neo",
		"      EnvironmentFile=/etc/neoagent/neoagent.env",
		"      Environment=HOME=" + guestproto.Home,
		"      Environment=NEOAGENT_HOME=" + guestproto.Home + "/.neoagent",
	}
	lines = append(lines, browserUnitEnvironment...)
	return append(lines,
		"      ExecStart="+guestproto.BinaryPath,
		"      Restart=always",
		"      RestartSec=5",
		"      TasksMax=768",
		"      MemoryHigh=85%",
		"      MemoryMax=95%",
		"      CPUQuota=180%",
		"      StandardOutput=journal+console",
		"      StandardError=journal+console",
		"",
		"      [Install]",
		"      WantedBy=cloud-init.target",
	)
}

// The agent binary ships in the seed as a gzip-compressed, base64 file; a
// static Go binary is several megabytes, and cloud-init unpacks it itself.
func guestAgentWriteFile(agent []byte) []string {
	return []string{
		"  - path: " + guestproto.BinaryPath,
		"    permissions: '0755'",
		"    owner: root:root",
		"    encoding: 'gz+b64'",
		"    content: |",
		"      " + base64.StdEncoding.EncodeToString(gzipBytes(agent)),
	}
}

func guestBootstrapWriteFiles(script string) []string {
	lines := []string{
		"  - path: /usr/local/bin/neoagent-guest-bootstrap.sh",
		"    permissions: '0755'",
		"    owner: root:root",
		"    content: |",
	}
	for _, line := range strings.Split(script, "\n") {
		lines = append(lines, "      "+line)
	}
	return lines
}

func guestBootstrapUnitWriteFile() []string {
	return []string{
		"  - path: /etc/systemd/system/neoagent-guest-bootstrap.service",
		"    permissions: '0644'",
		"    owner: root:root",
		"    content: |",
		"      [Unit]",
		"      Description=NeoAgent guest bootstrap",
		"      After=network-online.target",
		"      Wants=network-online.target",
		"",
		"      [Service]",
		"      Type=oneshot",
		"      ExecStart=/usr/local/bin/neoagent-guest-bootstrap.sh",
		"      RemainAfterExit=yes",
		"",
		"      [Install]",
		"      WantedBy=multi-user.target",
	}
}

// guestFirewallWriteFile keeps ordinary commands away from the host. QEMU's
// user network maps 10.0.2.2 to the host's loopback, and private ranges lead
// to the host's own network and a cloud's metadata service. The guest only
// needs this server, for the Git proxy, plus DNS and the internet. The guest's
// root user could remove this, so it is not a boundary against root.
func guestFirewallWriteFile(serverPort int) []string {
	return []string{
		"  - path: /etc/neoagent-firewall.nft",
		"    permissions: '0644'",
		"    owner: root:root",
		"    content: |",
		"      flush ruleset",
		"      table inet neoagent {",
		"        chain output {",
		"          type filter hook output priority 0; policy accept;",
		"          ct state established,related accept",
		fmt.Sprintf("          ip daddr 10.0.2.2 tcp dport %d accept", serverPort),
		"          ip daddr 10.0.2.3 accept",
		"          ip6 daddr fec0::3 accept",
		"          ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 } drop",
		"          ip6 daddr { fc00::/7, fec0::/10 } drop",
		"        }",
		"      }",
	}
}

// CloudInitUserData is the cloud-init user-data of a computer's first boot.
func CloudInitUserData(b GuestBootstrap) string {
	script := CloudInitScript(b.GuestToken, b.GuestAgentPort)
	var lines []string
	lines = append(lines, cloudInitPreamble()...)
	lines = append(lines, "write_files:")
	lines = append(lines, guestEnvWriteFile(encodeGuestToken(b.GuestToken), b.GuestAgentPort)...)
	lines = append(lines, guestAgentWriteFile(b.Agent)...)
	lines = append(lines, guestBootstrapWriteFiles(script)...)
	lines = append(lines, guestAgentUnitWriteFile()...)
	lines = append(lines, guestBootstrapUnitWriteFile()...)
	lines = append(lines, RenderDesktopCloudInitWriteFiles(append(GuestDesktopSystemFiles(), GuestDesktopSkelFiles()...), "  ")...)
	lines = append(lines, guestFirewallWriteFile(b.ServerPort)...)
	lines = append(lines,
		"runcmd:",
		`  - [bash, -lc, "systemctl daemon-reload"]`,
		`  - [bash, -lc, "/usr/local/bin/neoagent-guest-bootstrap.sh"]`,
		`  - [bash, -lc, "/usr/local/bin/neoagent-ensure-desktop"]`,
		`  - [bash, -lc, "systemctl enable --now zramswap.service || true"]`,
		`  - [bash, -lc, "systemctl reenable neoagent-guest-agent.service"]`,
		`  - [bash, -lc, "systemctl restart --no-block neoagent-guest-agent.service"]`,
		// After the steps above: the package they install must not find its config file taken.
		`  - [bash, -lc, "cp /etc/neoagent-firewall.nft /etc/nftables.conf && systemctl enable --now nftables"]`,
		"",
	)
	return strings.Join(lines, "\n")
}

// CloudInitMetaData is the cloud-init meta-data.
func CloudInitMetaData(instanceID, localHostName string) string {
	return fmt.Sprintf("instance-id: %s\nlocal-hostname: %s\n", instanceID, localHostName)
}

var (
	identityUnsafe = regexp.MustCompile(`(?i)[^a-z0-9_-]+`)
	identityTrim   = regexp.MustCompile(`^-+|-+$`)
)

// cloudInitIdentity names the instance after its directory relative to the
// runtime-vms root (as Node did), so a moved data directory is a new instance.
func cloudInitIdentity(vmRoot, userRoot string) string {
	rel, err := filepath.Rel(vmRoot, userRoot)
	if err != nil {
		rel = userRoot
	}
	var segments []string
	for _, segment := range strings.Split(rel, string(filepath.Separator)) {
		if segment == "" {
			continue
		}
		segment = identityTrim.ReplaceAllString(identityUnsafe.ReplaceAllString(segment, "-"), "")
		if len(segment) > 32 {
			segment = segment[:32]
		}
		if segment != "" {
			segments = append(segments, segment)
		}
	}
	scope := strings.Join(segments, "-")
	if scope == "" {
		scope = "default"
	}
	return "neoagent-" + scope
}

// startupNsh is the UEFI shell script on the seed that starts the guest's boot loader.
func startupNsh(architecture string) string {
	if architecture == "arm64" {
		return strings.Join([]string{
			"@echo -off",
			"map -r",
			"for %d in fs0 fs1 fs2 fs3 fs4 fs5",
			"  if exist %d:\\EFI\\ubuntu\\shimaa64.efi then",
			"    %d:\\EFI\\debian\\shimaa64.efi",
			"  endif",
			"endfor",
			"# Fallback",
			"\\EFI\\debian\\shimaa64.efi",
			"\\EFI\\debian\\grubaa64.efi",
		}, "\r\n")
	}
	return strings.Join([]string{
		"@echo -off",
		"map -r",
		"fs0:",
		"\\EFI\\debian\\shimx64.efi",
		"\\EFI\\debian\\grubx64.efi",
		"\\EFI\\BOOT\\BOOTX64.EFI",
	}, "\r\n")
}

// Seed is the cloud-init seed of a computer.
type Seed struct {
	Dir       string
	ImagePath string
}

// EnsureGuestBootstrapSeed writes the cloud-init files of a computer and builds
// the CIDATA seed image from them. The instance id changes whenever the
// user-data does, so cloud-init runs again for a new image or token.
func EnsureGuestBootstrapSeed(vmRoot, userRoot string, b GuestBootstrap, architecture string) (Seed, error) {
	seedRoot := filepath.Join(userRoot, "cloud-init")
	seedDir := filepath.Join(seedRoot, "seed")
	if err := os.MkdirAll(seedDir, 0o755); err != nil {
		return Seed{}, err
	}
	userData := CloudInitUserData(b)
	identity := cloudInitIdentity(vmRoot, userRoot)
	// The agent binary is far larger than the rest; its digest stands in for it.
	material := strings.Replace(userData, base64.StdEncoding.EncodeToString(gzipBytes(b.Agent)), "guest-payload-sha256:"+guestPayloadDigest(b.Agent), 1)
	sum := sha256.Sum256([]byte(material))
	instanceID := identity + "-" + hex.EncodeToString(sum[:])[:12]
	files := map[string][]byte{
		"user-data":   []byte(userData),
		"meta-data":   []byte(CloudInitMetaData(instanceID, identity)),
		"startup.nsh": []byte(startupNsh(architecture)),
	}
	for name, content := range files {
		if err := os.WriteFile(filepath.Join(seedDir, name), content, 0o644); err != nil {
			return Seed{}, err
		}
	}
	isoPath := filepath.Join(seedRoot, "cidata.iso")
	if err := vm.WriteSeedISO(isoPath, "CIDATA", []vm.SeedFile{
		{Name: "user-data", Content: files["user-data"]},
		{Name: "meta-data", Content: files["meta-data"]},
		{Name: "startup.nsh", Content: files["startup.nsh"]},
	}); err != nil {
		return Seed{}, fmt.Errorf("Unable to create cloud-init seed ISO: %w", err)
	}
	return Seed{Dir: seedDir, ImagePath: isoPath}, nil
}

func gzipBytes(data []byte) []byte {
	var packed bytes.Buffer
	zw, _ := gzip.NewWriterLevel(&packed, gzip.BestCompression)
	_, _ = zw.Write(data)
	_ = zw.Close()
	return packed.Bytes()
}
