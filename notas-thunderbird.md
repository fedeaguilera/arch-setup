# Thunderbird — notas de configuración

Perfil real: `~/.thunderbird/dm18m8n6.default-release/` (el `cx2vlqsu.default`
que también existe es un stub viejo que Thunderbird no usa — lo dice
`profiles.ini`). Corre nativo en Wayland (`xwayland: false` en `hyprctl
clients`), autoarranca en el workspace 3 sin robarte la vista
(`exec-once` + `windowrule = workspace 3 silent` en `hyprland.conf`).

## Gmail y Outlook con OAuth2 (sin contraseña manual)

Mismo flujo para las dos:

1. `Configuración` → `Administración de cuentas` → `Acción de cuenta` →
   **Agregar cuenta de correo**.
2. Cargá tu nombre y la dirección completa (`@gmail.com`, `@outlook.com`,
   `@hotmail.com` o tu cuenta de Microsoft 365 del trabajo). Dejá el campo
   de contraseña vacío.
3. Thunderbird detecta el dominio solo y configura IMAP con **OAuth2**
   como método de autenticación — no hace falta tocar nada manual.
4. Al confirmar, se abre una ventana con el login de Google o Microsoft.
   Iniciás sesión ahí (con 2FA si lo tenés activado) y aceptás el permiso
   para Thunderbird.
5. Volvés a Thunderbird con la cuenta ya andando. La contraseña real
   nunca pasa por Thunderbird, solo un token OAuth revocable desde tu
   cuenta de Google/Microsoft cuando quieras.

Si Thunderbird no detecta OAuth2 solo (pasa a veces con cuentas de
Workspace/M365 corporativas con políticas raras), en el paso de
configuración manual elegís método de autenticación **"OAuth2"** a mano en
vez de "Contraseña normal".

## Yahoo: contraseña de aplicación (no soporta OAuth2 de terceros)

Yahoo sí tiene OAuth2, pero no lo habilita para clientes de terceros como
Thunderbird — hay que generar una **contraseña de aplicación** en su lugar.

1. Entrá a [login.yahoo.com](https://login.yahoo.com) → **Información de
   la cuenta** → **Seguridad de la cuenta**.
2. Activá **verificación en dos pasos** si todavía no la tenés (Yahoo
   exige 2FA activo antes de dejarte generar contraseñas de aplicación).
3. Buscá **"Generar contraseña de aplicación"** (o "Administrar
   contraseñas de aplicación") → elegí "Otra app" → nombrala "Thunderbird".
4. Yahoo te muestra una contraseña de 16 caracteres **una sola vez**
   — copiala antes de cerrar esa pantalla.
5. En Thunderbird, al agregar la cuenta, usá esa contraseña generada (no
   tu contraseña real de Yahoo) cuando te la pida.

Si el autoconfig de Thunderbird no encuentra los servidores solo, cargalos
a mano:

| | Servidor | Puerto | Seguridad | Usuario |
|---|---|---|---|---|
| IMAP | `imap.mail.yahoo.com` | 993 | SSL/TLS | tu dirección completa |
| SMTP | `smtp.mail.yahoo.com` | 465 | SSL/TLS | tu dirección completa |

Método de autenticación: **contraseña normal** (usando la contraseña de
aplicación, no la de tu cuenta).

## Bandeja unificada (ver las tres cuentas juntas)

Abajo a la izquierda del panel de carpetas hay un ícono para cambiar el
modo de vista (Todas las carpetas / Carpetas unificadas / Recientes /
Favoritas). Elegí **Carpetas unificadas** — junta Recibidos, Enviados,
Borradores y Papelera de las tres cuentas en una sola lista, cada una
expandible para ver el desglose por cuenta.

## Que los links se abran en Firefox

Esto no se configura adentro de Thunderbird — usa el navegador
predeterminado del sistema (vía `xdg-open`, igual que cualquier app GTK
en Linux). Se fija así:

```sh
xdg-settings set default-web-browser firefox.desktop
```

Para confirmar que quedó bien:

```sh
xdg-settings get default-web-browser
xdg-mime query default x-scheme-handler/https
```

Ambos deberían decir `firefox.desktop`.

## Si una actualización rompe el tema

Los temas de terceros a veces quedan deshabilitados después de un update
mayor de Thunderbird (marcados como "incompatibles" hasta que alguien
confirma que siguen andando). Para reaplicarlo:

1. `Configuración` → `Complementos y temas` → pestaña **Temas**.
2. Buscá **"catppuccin-mocha-mauve"** en la lista.
   - Si está pero apagado: **Activar**.
   - Si desapareció: reinstalalo desde
     `~/.local/share/thunderbird-theme/mocha-mauve.xpi` (o desde
     `~/arch-setup/dotfiles/thunderbird/mocha-mauve.xpi` si estás
     reinstalando la máquina entera) con el mismo método de siempre
     (⚙ → Instalar complemento desde archivo).
3. Si ni siquiera te deja instalarlo (raro, pero puede pasar si
   Thunderbird empieza a exigir firma para temas locales): `about:config`
   → buscá `xpinstall.signatures.required` → ponelo en `false`, reinstalá
   el tema, y podés volver a dejarlo en `true` después si querés.

Otros colores de acento están en el mismo repo
(`github.com/catppuccin/thunderbird`, carpeta `themes/mocha/`) si en
algún momento querés cambiar de Mauve a otro.
