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

## Soporte

Para soporte técnico o consultas comerciales:

- **Email:** soporte@moctopus.com
- **Web:** [moctopus.com](https://moctopus.com)
