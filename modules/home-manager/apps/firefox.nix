{ ... }:

{
  programs.firefox = {
    enable = true;

    profiles.default = {
      settings = {
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.tabs.inTitlebar" = 0;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.startup.page" = 0;
        "browser.startup.homepage" = "about:blank";
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.default.sites" = "";
        "browser.urlbar.suggest.calculator" = true;
      };

    };

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxAccounts = true;
      DisableFirefoxScreenshots = true;
      OverrideFirstRunPage = true;
      OverridePostUpdatePage = true;
      DontCheckDefaultBrowser = true;
      SearchBar = "unified";

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };

  };
}
