const HOST_NAME = 'com.secure.vpn.proxy_auth';
const RECONNECT_MS = 5000;

let nativePort = null;
let proxyCreds = null;
let proxyHost = '127.0.0.1';
let proxyPort = 1081;

const api = typeof browser !== 'undefined' ? browser : chrome;

function sessionStoreSet(data) {
  return new Promise((resolve) => {
    api.storage.session.set(data, resolve);
  });
}

function sessionStoreRemove(keys) {
  return new Promise((resolve) => {
    api.storage.session.remove(keys, resolve);
  });
}

async function applyCredentials(message) {
  if (!message || message.type === 'clear') {
    proxyCreds = null;
    await sessionStoreRemove(['proxyCreds', 'proxyHost', 'proxyPort']);
    return;
  }
  if (message.type !== 'credentials') {
    return;
  }
  proxyHost = message.host || '127.0.0.1';
  proxyPort = message.port || 1081;
  proxyCreds = {
    username: message.username,
    password: message.password,
  };
  await sessionStoreSet({
    proxyCreds,
    proxyHost,
    proxyPort,
  });
}

function connectNative() {
  if (nativePort) {
    try {
      nativePort.disconnect();
    } catch (_) {
      // ignore
    }
    nativePort = null;
  }

  try {
    nativePort = api.runtime.connectNative(HOST_NAME);
  } catch (_) {
    scheduleReconnect();
    return;
  }

  nativePort.onMessage.addListener((message) => {
    applyCredentials(message);
  });

  nativePort.onDisconnect.addListener(() => {
    nativePort = null;
    scheduleReconnect();
  });

  nativePort.postMessage({ type: 'hello' });
}

function scheduleReconnect() {
  setTimeout(connectNative, RECONNECT_MS);
}

function isLocalProxyAuth(details) {
  if (!proxyCreds || !details.challenger) {
    return false;
  }
  const host = details.challenger.host;
  const port = details.challenger.port;
  return host === proxyHost && port === proxyPort;
}

function registerAuthListener() {
  const isChromiumMv3 =
    typeof chrome !== 'undefined' &&
    api.runtime.getManifest().manifest_version === 3;

  if (isChromiumMv3) {
    api.webRequest.onAuthRequired.addListener(
      (details) =>
        new Promise((resolve) => {
          resolve(
            isLocalProxyAuth(details)
              ? { authCredentials: proxyCreds }
              : {},
          );
        }),
      { urls: ['<all_urls>'] },
      ['asyncBlocking'],
    );
    return;
  }

  api.webRequest.onAuthRequired.addListener(
    (details) =>
      isLocalProxyAuth(details) ? { authCredentials: proxyCreds } : {},
    { urls: ['<all_urls>'] },
    ['blocking'],
  );
}

registerAuthListener();

connectNative();
setInterval(() => {
  if (nativePort) {
    nativePort.postMessage({ type: 'ping' });
  } else {
    connectNative();
  }
}, 30000);
