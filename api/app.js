const express = require('express');
const os = require('os');
const client = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;
const PET = process.env.PET || 'unknown';

// Registre Prometheus dédié à notre application
const register = new client.Registry();
register.setDefaultLabels({
  app: 'mon-api',
  pet: PET,
  hostname: os.hostname(),
});

// Métriques systèmes par défaut (CPU, mémoire, event loop, etc.)
client.collectDefaultMetrics({ register });

// Compteur du nombre de requêtes reçues depuis le démarrage du conteneur
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Nombre total de requêtes HTTP reçues depuis le démarrage du conteneur',
  labelNames: ['method', 'route', 'status'],
});
register.registerMetric(httpRequestsTotal);

// Compteur dédié à la route racine pour l'afficher facilement dans la réponse
const rootRequestsCounter = new client.Counter({
  name: 'root_requests_total',
  help: 'Nombre total de requêtes reçues sur GET /',
});
register.registerMetric(rootRequestsCounter);

// Middleware d'instrumentation : incrémente le compteur global pour chaque requête
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal.inc({
      method: req.method,
      route: req.path,
      status: res.statusCode,
    });
  });
  next();
});

// GET / : hostname du conteneur, valeur de PET et compteur de requêtes
app.get('/', async (req, res) => {
  rootRequestsCounter.inc();
  const metric = await register.getSingleMetric('root_requests_total').get();
  const counter = metric.values[0].value;

  res.json({
    hostname: os.hostname(),
    pet: PET,
    counter,
  });
});

// GET /healthz : sonde de vie utilisée par le HEALTHCHECK Docker
app.get('/healthz', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// GET /metrics : exposition des métriques Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(PORT, () => {
  // Log de démarrage minimal pour faciliter le debug en cas de problème.
  console.log(`[mon-api] listening on port ${PORT} (PET=${PET}, hostname=${os.hostname()})`);
});
