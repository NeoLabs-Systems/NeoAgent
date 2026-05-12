# NeoAgent Guest Agent Dependencies

This guest runtime uses both browser automation packages for distinct roles:

- puppeteer-core: used by server/services/browser/controller.js to drive the browser.
- playwright-chromium: supplies the bundled Chromium binary and installer used by resolveBrowserExecutablePath() and installPlaywrightChromiumBinary().

Keeping both avoids bundling a second browser downloader while still using Puppeteer's API surface.
