// A tiny test app for the capstone. It uses no packages, so there's nothing to build.
// It never prints secret values, only whether they arrived.
const http = require('http');

const port = process.env.PORT || 8080;

function secretLoaded() {
  const value = process.env.DB_CONNECTION || '';
  return value !== '' && !value.startsWith('@Microsoft.KeyVault');
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    region: process.env.REGION_NAME || 'not set',
    environment: process.env.ENV_NAME || 'not set',
    instance: process.env.WEBSITE_INSTANCE_ID || 'local',
    keyVaultSecretLoaded: secretLoaded(),
    appInsightsConfigured: Boolean(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING),
  }, null, 2));
});

server.listen(port, () => console.log(`Listening on ${port}`));
