#!/bin/bash
set -e

# ─── Moctopus Gateway — Script de Instalación ───────────────────────────────
# Uso: curl -fsSL https://raw.githubusercontent.com/moctopus/gateway/main/scripts/install.sh | bash
# O:   chmod +x install.sh && ./install.sh

GATEWAY_VERSION="${GATEWAY_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/moctopus-gateway}"
GATEWAY_PORT="${GATEWAY_PORT:-3000}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
  echo ""
  echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Moctopus Gateway — Instalación        ║${NC}"
  echo -e "${BLUE}║     Soluciones Inteligentes               ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
  echo ""
}

check_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      DISTRO=$ID
    fi
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
    echo -e "${YELLOW}⚠ Windows detectado. Asegúrate de tener WSL2 instalado.${NC}"
    echo "  Instala WSL2 desde: https://docs.microsoft.com/es-es/windows/wsl/install"
    exit 1
  fi
  echo -e "${GREEN}✓ Sistema operativo: $OS${NC}"
}

install_docker() {
  if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo -e "${GREEN}✓ Docker ya instalado: $DOCKER_VERSION${NC}"
    return
  fi

  echo -e "${YELLOW}→ Instalando Docker...${NC}"

  if [[ "$OS" == "macos" ]]; then
    echo -e "${RED}✗ En macOS, instala Docker Desktop manualmente:${NC}"
    echo "  https://www.docker.com/products/docker-desktop/"
    exit 1
  fi

  # Linux — script oficial de Docker
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER

  echo -e "${GREEN}✓ Docker instalado correctamente${NC}"
  echo -e "${YELLOW}⚠ Cierra y vuelve a abrir la sesión para aplicar los permisos de Docker${NC}"
}

check_docker_compose() {
  if docker compose version &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose disponible${NC}"
  else
    echo -e "${RED}✗ Docker Compose no encontrado. Actualiza Docker a la versión más reciente.${NC}"
    exit 1
  fi
}

setup_directory() {
  echo -e "${YELLOW}→ Creando directorio de instalación: $INSTALL_DIR${NC}"
  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"
}

download_files() {
  BASE_URL="https://raw.githubusercontent.com/moctopus-one-click/iiot-gateway-public/main"

  echo -e "${YELLOW}→ Descargando archivos de configuración...${NC}"
  curl -fsSL "$BASE_URL/docker-compose.yml" -o docker-compose.yml
  curl -fsSL "$BASE_URL/scripts/update.sh" -o update.sh
  chmod +x update.sh

  echo -e "${GREEN}✓ Archivos descargados${NC}"
}

generate_secrets() {
  echo -e "${YELLOW}→ Generando configuración...${NC}"

  JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('hex'))" 2>/dev/null || \
               openssl rand -hex 64 2>/dev/null || \
               cat /dev/urandom | tr -dc 'a-f0-9' | head -c 128)

  JWT_REFRESH_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('hex'))" 2>/dev/null || \
                       openssl rand -hex 64 2>/dev/null || \
                       cat /dev/urandom | tr -dc 'a-f0-9' | head -c 128)

  echo ""
  echo -n "  Nombre de esta instalación (ej: planta-norte): "
  read -r GATEWAY_ID_INPUT </dev/tty
  GATEWAY_ID="${GATEWAY_ID_INPUT:-gateway-001}"

  LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

  cat > .env << EOF
GATEWAY_VERSION=$GATEWAY_VERSION
GATEWAY_PORT=$GATEWAY_PORT
GATEWAY_ID=$GATEWAY_ID
JWT_SECRET=$JWT_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET
URL_FRONTEND=http://$LOCAL_IP:$GATEWAY_PORT
EOF

  echo -e "${GREEN}✓ Configuración generada${NC}"
}

start_gateway() {
  echo -e "${YELLOW}→ Descargando imagen de Moctopus Gateway...${NC}"
  docker compose pull || { echo -e "${RED}✗ Error descargando la imagen${NC}"; exit 1; }

  echo -e "${YELLOW}→ Iniciando gateway...${NC}"
  docker compose up -d

  echo ""
  echo -e "${YELLOW}→ Esperando que el gateway esté listo...${NC}"
  sleep 10

  ATTEMPTS=0
  until curl -sf http://localhost:$GATEWAY_PORT/api/health > /dev/null 2>&1; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ $ATTEMPTS -ge 12 ]; then
      echo -e "${RED}✗ El gateway no respondió en 60 segundos${NC}"
      echo "  Revisa los logs con: docker compose logs -f"
      exit 1
    fi
    sleep 5
  done
}

seed_admin() {
  echo -e "${YELLOW}→ Creando usuario administrador inicial...${NC}"
  docker compose exec gateway npm run seed:admin 2>/dev/null || \
  docker exec moctopus-gateway npm run seed:admin 2>/dev/null || \
  echo -e "${YELLOW}  (El usuario admin puede ya existir)${NC}"
}

generate_recovery() {
  echo -e "${YELLOW}→ Generando código de recuperación...${NC}"
  echo ""
  docker compose exec gateway npm run gateway:generate-recovery || \
  docker exec moctopus-gateway npm run gateway:generate-recovery
  echo ""
  echo -e "${RED}⚠ GUARDA EL CÓDIGO ANTERIOR EN UN LUGAR SEGURO${NC}"
  echo -e "${RED}  Lo necesitarás si olvidas la contraseña del administrador${NC}"
  echo ""
}

print_success() {
  LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║     ✓ Moctopus Gateway instalado correctamente    ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Accede desde este equipo:  ${BLUE}http://localhost:$GATEWAY_PORT${NC}"
  echo -e "  Accede desde la red local: ${BLUE}http://$LOCAL_IP:$GATEWAY_PORT${NC}"
  echo ""
  echo -e "  Usuario inicial: ${YELLOW}admin@gateway.local${NC}"
  echo -e "  Contraseña:      ${YELLOW}Admin1234!${NC}"
  echo -e "  ${RED}(Cámbiala en el primer login)${NC}"
  echo ""
  echo -e "  Para ver los logs:    ${BLUE}docker compose logs -f${NC}"
  echo -e "  Para detener:         ${BLUE}docker compose down${NC}"
  echo -e "  Para actualizar:      ${BLUE}./update.sh${NC}"
  echo ""
  echo -e "  Directorio:           $INSTALL_DIR"
  echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────────
print_header
check_os
install_docker
check_docker_compose
setup_directory
download_files
generate_secrets
start_gateway
seed_admin
generate_recovery
print_success
