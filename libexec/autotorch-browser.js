function run(argv) {
  const deviceCode = argv[0];
  const waitSeconds = Number(argv[1]);
  const probeOnly = argv[2] === "probe";
  const statusOnly = argv[2] === "status";
  delay(waitSeconds);

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

  const pagePath = (pageURL) => {
    const match = /^https:\/\/[^\/?#]+([^?#]*)/i.exec(String(pageURL));
    return match === null ? "" : match[1].toLowerCase();
  };

  const isDevicePage = (pageURL) => {
    const path = pagePath(pageURL);
    return path.endsWith("/oauth2/deviceauth");
  };

  const isConfirmationPage = (pageURL) => pagePath(pageURL).endsWith("/reprocess");
  const isSuccessPage = (pageURL) => pagePath(pageURL).endsWith("/appverify");
  const authState = (pageURL) => {
    if (isDevicePage(pageURL)) return "device";
    if (isConfirmationPage(pageURL)) return "confirmation";
    if (isSuccessPage(pageURL)) return "success";
    return "other";
  };

  let browser = null;
  // `open URL` returns before Microsoft finishes loading on slower VPN links.
  // Poll for up to 20 seconds so the safe fallback is based on the actual tab,
  // not a race with the default browser.
  const browserAttempts = statusOnly ? 1 : 40;
  for (let attempt = 0; attempt < browserAttempts && browser === null; attempt += 1) {
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
    if (statusOnly) {
      return "AUTOTORCH_AUTH_STATE=other";
    }
    throw new Error("No supported browser has an active Microsoft login page.");
  }

  // Status checks never focus a window or emit input. Expect uses this after a
  // safe clipboard fallback so it can submit to SSH the instant another UI
  // controller (or the user) reaches Microsoft's success page.
  if (statusOnly) {
    return "AUTOTORCH_AUTH_STATE=" + authState(browser.url(browser.app));
  }

  const systemEvents = Application("System Events");
  let previousFrontApp = null;
  try {
    const previousFrontProcesses = systemEvents.applicationProcesses.whose({ frontmost: true });
    if (previousFrontProcesses.length > 0) {
      previousFrontApp = previousFrontProcesses[0].name();
    }
  } catch (_) {
    // Restoring the previously focused app is best-effort only.
  }

  const restorePreviousApp = () => {
    if (previousFrontApp !== null && previousFrontApp !== browser.name) {
      try {
        Application(previousFrontApp).activate();
      } catch (_) {
        // Never turn a successful authentication into a failure over focus.
      }
    }
  };

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
    restorePreviousApp();
    return browser.name + ": verified Microsoft login page";
  }

  let pageURL = browser.url(browser.app);
  for (let attempt = 0; attempt < 40 && !isDevicePage(pageURL); attempt += 1) {
    if (!allowedHost(pageURL) || isConfirmationPage(pageURL) || isSuccessPage(pageURL)) {
      break;
    }
    delay(0.5);
    pageURL = browser.url(browser.app);
  }
  if (!isDevicePage(pageURL)) {
    throw new Error("Refusing to type because the active tab is not a fresh device-code page.");
  }

  // The device page autofocuses its code field. Submit only after the code has
  // had time to reach the field; this avoids the paste/click race seen with
  // back-to-back UI events.
  systemEvents.keystroke(deviceCode);
  delay(0.35);
  systemEvents.keyCode(36);

  // A cached Microsoft/NYU session presents the default signed-in account as
  // the focused button. Press Return only while the URL is still the device
  // flow, then stop as soon as navigation proves the account was selected.
  pageURL = browser.url(browser.app);
  for (let attempt = 0; attempt < 30 && isDevicePage(pageURL); attempt += 1) {
    delay(attempt === 0 ? 1.0 : 0.4);
    systemEvents.keyCode(36);
    delay(0.2);
    pageURL = browser.url(browser.app);
  }

  if (isSuccessPage(pageURL)) {
    restorePreviousApp();
    return "AUTOTORCH_AUTH_COMPLETE=1";
  }
  if (!isConfirmationPage(pageURL)) {
    throw new Error("The cached default NYU account could not be selected automatically.");
  }

  // Microsoft displays a final trust confirmation with Continue focused.
  delay(0.5);
  systemEvents.keyCode(36);
  for (let attempt = 0; attempt < 50; attempt += 1) {
    delay(0.2);
    pageURL = browser.url(browser.app);
    if (isSuccessPage(pageURL)) {
      restorePreviousApp();
      return "AUTOTORCH_AUTH_COMPLETE=1";
    }
    if (!allowedHost(pageURL)) {
      break;
    }
  }

  throw new Error("Microsoft did not reach the device-login success page.");
}
