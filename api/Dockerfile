# syntax=docker/dockerfile:1.6
# Image de base légère et durcie : node:20-alpine pèse ~50 Mo et embarque
# beaucoup moins de paquets que node:latest (Debian) → surface d'attaque réduite
# et beaucoup moins de CVE (cf. scan Trivy dans le README).
FROM node:20-alpine

ENV NODE_ENV=production \
    PORT=3000

# wget est nécessaire pour le HEALTHCHECK (présent dans node:20-alpine via busybox)
WORKDIR /usr/src/app

# Étape 1 : on copie d'abord uniquement les manifestes pour profiter du cache Docker
# tant que les dépendances ne changent pas, cette couche reste cachée.
COPY package*.json ./

RUN npm install --only=production && npm cache clean --force

# Étape 2 : on copie le reste de l'application (le .dockerignore exclut node_modules, .env, .git, etc.)
COPY . .

# Création d'un utilisateur non-root pour exécuter l'application
# (l'utilisateur "node" est déjà présent dans l'image officielle node:20-alpine)
RUN chown -R node:node /usr/src/app
USER node

EXPOSE 3000

# HEALTHCHECK sur /healthz : Docker marque le conteneur "healthy" tant que la route répond 200.
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --spider --quiet http://localhost:3000/healthz || exit 1

CMD ["node", "app.js"]
