#!/bin/bash
set -e

# ─── Moctopus Gateway — Script de Actualización ─────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Moctopus Gateway — Actualización      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

if [ ! -f "docker-compose.yml" ]; then
  echo -e "${RED}✗ No se encontró docker-compose.yml${NC}"
  echo "  Ejecuta este script desde el directorio de instalación."
  exit 1
fi

CURRENT=$(docker inspect moctopus-gateway --format='{{.Config.Image}}' 2>/dev/null || echo "desconocida")
echo -e "  Versión actual: ${YELLOW}$CURRENT${NC}"

echo -e "${YELLOW}→ Descargando nueva versión...${NC}"
docker compose pull

echo -e "${YELLOW}→ Creando backup de la base de datos...${NC}"
BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).db"
docker compose cp gateway:/data/gateway.db "./$BACKUP_FILE" 2>/dev/null || \
  echo -e "${YELLOW}  (No se pudo crear backup automático — la BD está en el volumen)${NC}"

echo -e "${YELLOW}→ Aplicando actualización...${NC}"
docker compose up -d --force-recreate

echo -e "${YELLOW}→ Esperando que el gateway esté listo...${NC}"
sleep 10

GATEWAY_PORT=$(grep GATEWAY_PORT .env 2>/dev/null | cut -d= -f2 || echo "3000")
ATTEMPTS=0
until curl -sf "http://localhost:$GATEWAY_PORT/api/health" > /dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ $ATTEMPTS -ge 12 ]; then
    echo -e "${RED}✗ El gateway no respondió tras la actualización${NC}"
    echo "  Revisa los logs: docker compose logs -f"
    exit 1
  fi
  sleep 5
done

echo ""
echo -e "${GREEN}╔═════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✓ Gateway actualizado correctamente         ║${NC}"
echo -e "${GREEN}╚═════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Los datos y configuración se preservaron."
[ -f "$BACKUP_FILE" ] && echo -e "  Backup creado: ${BLUE}$BACKUP_FILE${NC}"
echo ""
