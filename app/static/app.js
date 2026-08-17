const list = document.getElementById('server-list');
const resultBox = document.getElementById('result');
const refreshButton = document.getElementById('refresh-button');

function setResult(message, tone = 'info') {
  resultBox.textContent = message;
  resultBox.className = `result ${tone}`;
}

function createStatusBadge(status) {
  const badge = document.createElement('span');
  badge.className = `status-badge ${status}`;
  badge.textContent = status;
  return badge;
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();

  let payload = null;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch (error) {
    throw new Error(`Server returned an unexpected response (${response.status} ${response.statusText}).`);
  }

  if (!response.ok) {
    throw new Error(payload?.message || `Request failed (${response.status} ${response.statusText}).`);
  }

  return payload;
}

function renderServers(servers) {
  list.innerHTML = '';

  if (!servers.length) {
    const emptyItem = document.createElement('li');
    emptyItem.className = 'empty-state';
    emptyItem.textContent = 'No servers configured yet.';
    list.appendChild(emptyItem);
    return;
  }

  servers.forEach((server) => {
    const item = document.createElement('li');
    item.className = 'server-card';

    const title = document.createElement('div');
    title.className = 'server-title';

    const name = document.createElement('strong');
    name.textContent = server.name;
    title.appendChild(name);

    const description = document.createElement('span');
    description.textContent = server.description || '';
    title.appendChild(description);

    const meta = document.createElement('div');
    meta.className = 'server-meta';
    meta.appendChild(createStatusBadge(server.status));
    if (server.port) {
      const port = document.createElement('span');
      port.textContent = `Port ${server.port}`;
      meta.appendChild(port);
    }

    const actions = document.createElement('div');
    actions.className = 'actions';

    const actionButton = document.createElement('button');
    actionButton.type = 'button';
    actionButton.className = server.status === 'running' ? 'secondary' : 'primary';
    actionButton.textContent = server.status === 'running' ? 'Stop' : 'Start';
    actionButton.addEventListener('click', () => toggleServer(server.id, server.status === 'running' ? 'stop' : 'start'));

    actions.appendChild(actionButton);

    item.appendChild(title);
    item.appendChild(meta);
    item.appendChild(actions);
    list.appendChild(item);
  });
}

async function loadServers() {
  try {
    const servers = await requestJson('/api/servers');
    renderServers(servers);
  } catch (error) {
    setResult(`Unable to load servers: ${error.message}`, 'error');
  }
}

async function toggleServer(serverId, action) {
  try {
    const payload = await requestJson(`/api/${action}/${serverId}`, { method: 'POST' });

    if (payload.success) {
      setResult(payload.message, 'success');
    } else {
      setResult(payload.message, 'error');
    }

    await loadServers();
  } catch (error) {
    setResult(`Action failed: ${error.message}`, 'error');
  }
}

refreshButton.addEventListener('click', () => {
  setResult('Refreshing server states…', 'info');
  loadServers();
});

loadServers();
setInterval(loadServers, 15000);
