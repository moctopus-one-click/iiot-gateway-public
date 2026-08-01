#!/bin/bash
set -e

# ─── Moctopus Gateway — Script de Actualización ─────────────────────────────

BASE_URL="https://raw.githubusercontent.com/moctopus-one-click/iiot-gateway-public/main"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Agrega al .env local las variables de $BASE_URL/.env.defaults que el
# cliente todavía no tenga — nunca toca una que ya exista (aunque su valor
# sea distinto al default o esté vacía). Se descarga fresco en cada corrida
# para que instalaciones viejas reciban variables de features agregadas
# después, sin necesidad de re-descargar update.sh. Silencioso si no hay
# nada nuevo que agregar.
reconcile_env() {
  local defaults_file="$1"
  [ -f ".env" ] || return 0
  [ -f "$defaults_file" ] || return 0

  local new_entries=()
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    grep -q "^${key}=" .env 2>/dev/null || new_entries+=("$key=$value")
  done < "$defaults_file"

  [ ${#new_entries[@]} -eq 0 ] && return 0

  local backup=".env.backup_$(date +%Y%m%d_%H%M%S)"
  cp .env "$backup"
  {
    echo ""
    echo "# Agregado por update.sh — $(date +%Y-%m-%d)"
  } >> .env
  for entry in "${new_entries[@]}"; do
    echo "$entry" >> .env
  done

  echo -e "${YELLOW}→ Se agregaron ${#new_entries[@]} variable(s) nueva(s) al .env:${NC}"
  for entry in "${new_entries[@]}"; do
    echo -e "    ${GREEN}+ ${entry%%=*}${NC}"
  done
  echo -e "  Backup del .env anterior: ${BLUE}$backup${NC}"
}

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

# Re-descarga un archivo de configuración estático (sin valores de cliente
# que preservar, a diferencia de .env) en cada corrida, para que fixes de
# infraestructura (ej. el init container de mosquitto) lleguen también a
# instalaciones ya existentes, no solo a instalaciones nuevas vía
# install.sh. Silencioso si el contenido no cambió; backup + aviso si sí.
update_static_file() {
  local remote_path="$1"
  local local_path="$2"
  local tmp
  tmp=$(mktemp)
  if ! curl -fsSL "$BASE_URL/$remote_path" -o "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 0
  fi
  if [ -f "$local_path" ] && cmp -s "$tmp" "$local_path"; then
    rm -f "$tmp"
    return 0
  fi
  if [ -f "$local_path" ]; then
    local backup="${local_path}.backup_$(date +%Y%m%d_%H%M%S)"
    cp "$local_path" "$backup"
    echo -e "${YELLOW}→ ${local_path} actualizado (backup: ${BLUE}${backup}${NC}${YELLOW})${NC}"
  else
    mkdir -p "$(dirname "$local_path")"
    echo -e "${YELLOW}→ ${local_path} descargado${NC}"
  fi
  cp "$tmp" "$local_path"
  rm -f "$tmp"
}

update_static_file "docker-compose.yml" "docker-compose.yml"
update_static_file "mosquitto/mosquitto.conf" "mosquitto/mosquitto.conf"

echo -e "${YELLOW}→ Descargando nueva versión...${NC}"
docker compose pull

ENV_DEFAULTS_TMP=$(mktemp)
if curl -fsSL "$BASE_URL/.env.defaults" -o "$ENV_DEFAULTS_TMP" 2>/dev/null; then
  reconcile_env "$ENV_DEFAULTS_TMP"
fi
rm -f "$ENV_DEFAULTS_TMP"

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
