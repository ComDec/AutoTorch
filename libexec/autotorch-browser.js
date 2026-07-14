function run(argv) {
  const deviceCode = argv[0];
  const waitSeconds = Number(argv[1]);
  const probeOnly = argv[2] === "probe";
  delay(waitSeconds);

  const systemEvents = Application("System Events");
  const allowedHost = (pageURL) => {
    // macOS JXA uses JavaScriptCore without the browser URL global. Parse only
    // the HTTPS authority we need instead of relying on new URL(...).
    const match = /^https:\/\/([^\/?#]+)(?:[\/?#]|$)/i.exec(String(pageURL));
    if (match === null) {
      return false;
    }
    const hostname = match[1].toLowerCase().replace(/\.$/, "");
    return hostname === "microsoft.com" ||
      hostname.endsWith(".microsoft.com") ||
      hostname === "microsoftonline.com" ||
      hostname.endsWith(".microsoftonline.com");
  };

  let browser = null;
  // `open URL` returns before Microsoft finishes loading on slower VPN links.
  // Poll for up to 20 seconds so the safe fallback is based on the actual tab,
  // not a race with the default browser.
  for (let attempt = 0; attempt < 40 && browser === null; attempt += 1) {
    for (const name of ["Safari", "Google Chrome", "Microsoft Edge"]) {
      try {
        const app = Application(name);
        if (!app.running()) {
          continue;
        }
        const pageURL = name === "Safari"
          ? (app.documents.length > 0 ? app.documents[0].url() : "")
          : (app.windows.length > 0 ? app.windows[0].activeTab.url() : "");
        if (allowedHost(pageURL)) {
          browser = {
            name: name,
            app: app,
            url: name === "Safari"
              ? (target) => target.documents.length > 0 ? target.documents[0].url() : ""
              : (target) => target.windows.length > 0 ? target.windows[0].activeTab.url() : ""
          };
          break;
        }
      } catch (_) {
        // The browser is absent, has no window, or Apple Events access is denied.
      }
    }
    if (browser === null) {
      delay(0.5);
    }
  }

  if (browser === null) {
    throw new Error("No supported browser has an active Microsoft login page.");
  }

  browser.app.activate();
  delay(0.4);

  const frontProcesses = systemEvents.applicationProcesses.whose({ frontmost: true });
  if (frontProcesses.length === 0 || frontProcesses[0].name() !== browser.name) {
    throw new Error("Could not bring the verified Microsoft login page to the foreground.");
  }
  if (!allowedHost(browser.url(browser.app))) {
    throw new Error("Refusing to type because the active tab left the Microsoft login domain.");
  }

  if (probeOnly) {
    return browser.name + ": verified Microsoft login page";
  }

  systemEvents.keystroke(deviceCode);
  systemEvents.keyCode(36);
}
