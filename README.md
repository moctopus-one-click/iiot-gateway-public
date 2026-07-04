<p align="center">
  <img src="apps/ui/public/logo.svg" alt="Moctopus" width="180" />
</p>

<h1 align="center">Moctopus IIoT Gateway</h1>

<p align="center">
  Plataforma de monitoreo industrial para conectar, visualizar y gestionar tus dispositivos desde un único lugar.
</p>

---

## Requisitos

- Sistema operativo: Linux (Ubuntu 20.04+, Debian 11+) o macOS
- Docker 24+ con Docker Compose

> En Windows se requiere WSL2 con Ubuntu instalado.

---

## Instalación

Ejecuta este comando en tu servidor o equipo industrial:

```bash
curl -fsSL https://raw.githubusercontent.com/moctopus-one-click/iiot-gateway-public/main/scripts/install.sh | bash
```

El script instala Docker si no está presente, configura el gateway y lo deja funcionando en menos de 5 minutos.

---

## Acceso inicial

Una vez instalado, abre el navegador en:

```
http://<IP-del-equipo>:3000
```

Credenciales por defecto:

| Campo      | Valor                  |
|------------|------------------------|
| Usuario    | `admin@gateway.local`  |
| Contraseña | `Admin1234!`           |

> Cambia la contraseña en el primer inicio de sesión.

---

## Actualización

Desde el directorio de instalación:

```bash
./update.sh
```

El script descarga la nueva versión, hace backup de la base de datos y reinicia el gateway automáticamente.

---

## Notas para hardware específico

### Jetson Nano (JetPack 4.x / Ubuntu Bionic)

Si tu Jetson Nano usa una versión antigua de JetPack, el instalador de Docker puede fallar porque Ubuntu Bionic (18.04) llegó a fin de soporte. Instala Docker manualmente antes de correr el script:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  bionic stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
```

Cierra sesión y vuelve a entrar, luego corre el instalador normalmente:

```bash
curl -fsSL https://raw.githubusercontent.com/moctopus-one-click/iiot-gateway-public/main/scripts/install.sh | bash
```

---

## Soporte

Para soporte técnico o consultas comerciales:

- **Email:** info@moctopuss.com
- **Web:** [moctopussas.com](https://moctopussas.com)
