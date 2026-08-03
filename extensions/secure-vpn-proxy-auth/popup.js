const api = typeof browser !== 'undefined' ? browser : chrome;

async function refreshStatus() {
  const statusEl = document.getElementById('status');
  const data = await api.storage.session.get([
    'proxyCreds',
    'proxyHost',
    'proxyPort',
  ]);
  if (data.proxyCreds && data.proxyHost && data.proxyPort) {
    statusEl.textContent = `Ready: ${data.proxyHost}:${data.proxyPort}`;
    statusEl.className = 'ok';
    return;
  }
  statusEl.textContent = 'Waiting for VPN app session…';
  statusEl.className = 'warn';
}

refreshStatus();
