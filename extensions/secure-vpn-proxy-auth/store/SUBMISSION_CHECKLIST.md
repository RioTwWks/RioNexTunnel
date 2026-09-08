# Extension store submission checklist

Manual submission only.

## Before submit

- [ ] Extension loads unpacked on **Linux** with native host from RioNexTunnel `setup()`
- [ ] Extension loads unpacked on **Windows** with registry manifests
- [ ] Extension loads unpacked on **macOS** with manifests under `~/Library/Application Support/.../NativeMessagingHosts/`
- [ ] macOS native host path in manifest points to `~/Library/Application Support/V2rayBox/working/native_host/secure_vpn_native_host` (installed by app, not bundle path)
- [ ] No credentials stored in extension `localStorage` or `chrome.storage`
- [ ] Screenshots and listing text in `store/` folder reviewed

## macOS note

Chrome/Firefox on macOS read the native messaging manifest **path** field at install time. RioNexTunnel writes manifests on first app `setup()` with the user-writable host binary path above. Users must launch the app once before the extension can connect to the host.

## Store links (fill after publish)

| Store | URL |
|-------|-----|
| Chrome Web Store | _pending_ |
| Firefox AMO | _pending_ |
