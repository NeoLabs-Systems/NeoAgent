package browser

import "strconv"

// stealthScript removes the automation tells a page can read (webdriver flag,
// empty plugin list, headless WebGL strings) and presents the profile's
// identity. It runs before any page script.
func stealthScript(id Identity) string {
	hardware := id.HardwareConcurrency
	if hardware == 0 {
		hardware = 8
	}
	memory := id.DeviceMemory
	if memory == 0 {
		memory = 8
	}
	return `
      (() => {
        // Remove webdriver flag
        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });

        // Realistic language/platform
        Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
        Object.defineProperty(navigator, 'platform', { get: () => ` + jsonString(id.Platform) + ` });
        Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => ` + strconv.Itoa(hardware) + ` });
        Object.defineProperty(navigator, 'deviceMemory', { get: () => ` + strconv.Itoa(memory) + ` });

        // Make it look like a real Chrome install
        window.chrome = {
          app: { isInstalled: false, InstallState: {}, RunningState: {} },
          runtime: {},
          loadTimes: function() {},
          csi: function() {},
        };

        // Permissions API — bots often show "denied" for notifications
        const origQuery = window.navigator.permissions?.query?.bind(navigator.permissions);
        if (origQuery) {
          navigator.permissions.query = (parameters) =>
            parameters.name === 'notifications'
              ? Promise.resolve({ state: Notification.permission })
              : origQuery(parameters);
        }

        // Hide automation plugins gap
        Object.defineProperty(navigator, 'plugins', {
          get: () => {
            const arr = [
              { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
              { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai', description: '' },
              { name: 'Native Client', filename: 'internal-nacl-plugin', description: '' },
            ];
            arr.item = i => arr[i];
            arr.namedItem = n => arr.find(p => p.name === n) || null;
            arr.refresh = () => {};
            return arr;
          }
        });

        // WebGL Spoofing
        const getParameterProxyHandler = {
          apply: function(target, ctx, args) {
            const param = args[0];
            // UNMASKED_VENDOR_WEBGL
            if (param === 37445) return ` + jsonString(id.WebGLVendor) + `;
            // UNMASKED_RENDERER_WEBGL
            if (param === 37446) return ` + jsonString(id.WebGLRenderer) + `;
            return Reflect.apply(target, ctx, args);
          }
        };
        const getParam = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = new Proxy(getParam, getParameterProxyHandler);
        if (typeof WebGL2RenderingContext !== 'undefined') {
          const getParam2 = WebGL2RenderingContext.prototype.getParameter;
          WebGL2RenderingContext.prototype.getParameter = new Proxy(getParam2, getParameterProxyHandler);
        }

        // Canvas Spoofing (slight noise)
        const originalFillText = CanvasRenderingContext2D.prototype.fillText;
        CanvasRenderingContext2D.prototype.fillText = function(...args) {
            if (!this._spoofing_applied) {
                this._spoofing_applied = true;
                const r = Math.random() * 0.0001;
                const g = Math.random() * 0.0001;
                const b = Math.random() * 0.0001;
                this.fillStyle = ` + "`rgba(${Math.floor(r * 255)}, ${Math.floor(g * 255)}, ${Math.floor(b * 255)}, 0.01)`" + `;
                originalFillText.call(this, "spoof", 0, 0);
            }
            return originalFillText.apply(this, args);
        };

      })();
    `
}
