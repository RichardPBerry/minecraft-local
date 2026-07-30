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
    title.innerHTML = `<strong>${server.name}</strong><span>${server.description || ''}</span>`;

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
    const response = await fetch('/api/servers');
    const servers = await response.json();
    renderServers(servers);
  } catch (error) {
    setResult(`Unable to load servers: ${error.message}`, 'error');
  }
}

async function toggleServer(serverId, action) {
  const response = await fetch(`/api/${action}/${serverId}`, { method: 'POST' });
  const payload = await response.json();

  if (payload.success) {
    setResult(payload.message, 'success');
  } else {
    setResult(payload.message, 'error');
  }

  await loadServers();
}

refreshButton.addEventListener('click', () => {
  setResult('Refreshing server states…', 'info');
  loadServers();
});

loadServers();
setInterval(loadServers, 15000);
