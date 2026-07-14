function run(argv) {
  const deviceCode = argv[0];
  const waitSeconds = Number(argv[1]);
  delay(waitSeconds);

  const systemEvents = Application("System Events");
  const frontProcesses = systemEvents.applicationProcesses.whose({ frontmost: true });
  if (frontProcesses.length === 0) {
    throw new Error("No foreground application found.");
  }

  const frontName = frontProcesses[0].name();
  let pageURL;
  if (frontName === "Safari") {
    pageURL = Application("Safari").documents[0].url();
  } else if (frontName === "Google Chrome") {
    pageURL = Application("Google Chrome").windows[0].activeTab.url();
  } else if (frontName === "Microsoft Edge") {
    pageURL = Application("Microsoft Edge").windows[0].activeTab.url();
  } else {
    throw new Error("The Microsoft login page is not in a supported foreground browser.");
  }

  if (!pageURL.includes("microsoft.com") && !pageURL.includes("microsoftonline.com")) {
    throw new Error("Refusing to type outside a Microsoft login page.");
  }

  systemEvents.keystroke(deviceCode);
  systemEvents.keyCode(36);
}
