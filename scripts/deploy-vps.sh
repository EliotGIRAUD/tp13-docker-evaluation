#!/usr/bin/env bash
# =========================================================================
# Script de déploiement de la stack TP13 sur le VPS
#   Usage (depuis le poste local) :
#       scp -r ./* root@185.98.137.102:/opt/tp13/
#       ssh root@185.98.137.102 'bash /opt/tp13/scripts/deploy-vps.sh'
# =========================================================================

set -euo pipefail

VPS_IP="185.98.137.102"
REGISTRY_PORT="5000"
REGISTRY_HOST="${VPS_IP}:${REGISTRY_PORT}"
API_IMAGE="mon-api:1.0.0"
PROJECT_DIR="/opt/tp13"

echo "==> 1/8 : Installation Docker & Docker Compose (si nécessaire)"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
docker --version
docker compose version

echo "==> 2/8 : Configuration du daemon Docker pour autoriser le registry HTTP (insecure-registries)"
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOF
{
  "insecure-registries": ["${REGISTRY_HOST}"]
}
EOF
systemctl restart docker

echo "==> 3/8 : Aller dans le dossier projet"
cd "${PROJECT_DIR}"

echo "==> 4/8 : Démarrage du registry privé + UI"
docker compose -f docker-compose.registry.yml --env-file .env up -d
sleep 3

echo "==> 5/8 : Build et push de l'image API vers le registry privé"
docker build -t "${API_IMAGE}" ./api
docker tag  "${API_IMAGE}" "${REGISTRY_HOST}/${API_IMAGE}"
docker push "${REGISTRY_HOST}/${API_IMAGE}"

echo "==> 6/8 : Démarrage de la stack principale (avec override prod : limites CPU/RAM)"
docker compose -f docker-compose.yml -f docker-compose.prod.yml --env-file .env up -d

echo "==> 7/8 : Attente du healthcheck (jusqu'à 60s)"
sleep 30

echo "==> 8/8 : État final de la stack"
docker compose ps

echo ""
echo "============================================================"
echo "✅ Déploiement terminé. Points d'entrée :"
echo "   API (load-balancée)     : http://${VPS_IP}/"
echo "   API cat                 : http://${VPS_IP}/cat"
echo "   API dog                 : http://${VPS_IP}/dog"
echo "   Registry UI             : http://${VPS_IP}:8080/"
echo "   Grafana (admin/admin)   : http://${VPS_IP}:8081/"
echo "   Portainer               : http://${VPS_IP}:8083/"
echo "   Prometheus              : (interne uniquement, via Grafana)"
echo "============================================================"
