# Neovim + LazyVim, viniendo de VS Code

Guía de referencia para el día a día. `<leader>` es la tecla **espacio**.
Cuando la dudes, apretá espacio y esperá un segundo: which-key te muestra
todos los atajos disponibles agrupados — es el cheatsheet más actualizado
que vas a tener, más que este documento.

## 1. Los modos

Vim no es un editor de "un solo modo" como VS Code — el teclado hace cosas
distintas según en qué modo estás. Es la diferencia más grande al venir de
VS Code, y la que más cuesta al principio.

| Modo | Para qué | Cómo entrar |
|---|---|---|
| **Normal** | Moverte, borrar, copiar — el modo por defecto, donde vivís la mayor parte del tiempo | `<Esc>` desde cualquier otro modo |
| **Insert** | Escribir texto, como en VS Code siempre | `i` (insertar antes del cursor), `a` (después), `o` (línea nueva abajo) |
| **Visual** | Seleccionar texto para operar sobre él | `v` (selección normal), `V` (por líneas), `Ctrl+v` (por bloque/columna) |
| **Command** | Comandos tipo `:w`, `:%s/.../.../g` | `:` desde Normal |

La regla de oro: **`<Esc>` te devuelve a Normal desde cualquier lado**. Si
no sabés qué modo tenés, apretá `<Esc>`.

## 2. Supervivencia

| Acción | Comando |
|---|---|
| Guardar | `<C-s>` (funciona en Normal e Insert, como VS Code) o `:w` |
| Guardar y salir | `:wq` |
| Cerrar buffer actual | `<leader>bd` |
| Salir de todo | `<leader>qq` |
| Salir **sin** guardar | `:q!` |
| Deshacer | `u` |
| Rehacer | `<C-r>` |
| Cancelar/escapar lo que sea | `<Esc>` |

## 3. Los 15 movimientos más usados

Estos son estándar de Vim (LazyVim no los toca) — la base sobre la que se
apoya todo lo demás.

| Movimiento | Hace | Equivalente en VS Code |
|---|---|---|
| `h` `j` `k` `l` | izquierda / abajo / arriba / derecha | flechas |
| `w` | siguiente palabra | `Ctrl+→` |
| `b` | palabra anterior | `Ctrl+←` |
| `e` | fin de la palabra actual | (sin equivalente directo) |
| `0` | inicio de línea (columna 0) | `Home` |
| `^` | primer caracter no-blanco de la línea | `Home` (con "smart home") |
| `$` | fin de línea | `End` |
| `gg` | inicio del archivo | `Ctrl+Home` |
| `G` | fin del archivo | `Ctrl+End` |
| `{` / `}` | párrafo/bloque anterior / siguiente | `Ctrl+↑` / `Ctrl+↓` |
| `Ctrl+d` / `Ctrl+u` | media página abajo / arriba | `Page Down` / `Page Up` |
| `%` | salta al paréntesis/llave que hace match | `Ctrl+Shift+\` |
| `f{letra}` / `t{letra}` | salta hasta / justo antes de esa letra en la línea | (sin equivalente) |
| `*` / `#` | busca la palabra bajo el cursor, adelante / atrás | `Ctrl+F` con la palabra ya cargada |
| `{n}G` o `:{n}` | ir a la línea n | `Ctrl+G` |

## 4. Edición

| Acción | Comando |
|---|---|
| Copiar línea (yank) | `yy` |
| Copiar selección | seleccioná con `v`/`V` y `y` |
| Cortar línea | `dd` |
| Cortar/borrar selección | seleccioná y `d` |
| Pegar después / antes del cursor | `p` / `P` |
| Borrar un caracter | `x` |
| Seleccionar (visual) | `v` |
| Seleccionar líneas completas | `V` |
| Seleccionar columna/bloque | `Ctrl+v` |
| Repetir el último cambio | `.` |
| Buscar en el archivo actual | `/texto` (`n`/`N` para siguiente/anterior) |
| Buscar y reemplazar en el archivo | `:%s/viejo/nuevo/g` |
| Buscar y reemplazar en **todo el proyecto** | `<leader>sr` (abre grug-far, como el `Ctrl+Shift+H` de VS Code) |

## 5. El árbol de carpetas (neo-tree)

| Acción | Tecla |
|---|---|
| Abrir/cerrar el explorador | `<leader>e` |
| Abrir archivo / expandir carpeta | `<CR>` o `l` |
| Cerrar carpeta / subir un nivel | `h` |
| Crear archivo o carpeta (terminá el nombre en `/` para carpeta) | `a` |
| Renombrar | `r` |
| Borrar | `d` |
| Copiar | `c` |
| Cortar | `x` |
| Pegar | `p` |
| Refrescar | `R` |
| Abrir en split horizontal | `S` |
| Abrir en split vertical | `s` |
| Ayuda con todos los atajos del árbol | `?` |

El árbol sigue automáticamente el archivo que tenés abierto
(`follow_current_file`), como el explorador de VS Code.

## 6. Búsqueda con Telescope

| Acción | Atajo |
|---|---|
| Buscar archivos por nombre | `<leader><space>` |
| Buscar texto en todo el proyecto (live grep) | `<leader>/` |
| Buscar la palabra bajo el cursor en el proyecto | `<leader>sw` |
| Cambiar entre buffers abiertos | `<leader>,` |
| Símbolos del archivo actual (funciones, clases) | `<leader>ss` |
| Buscar en todos los atajos de teclado | `<leader>sk` |
| Recientes | `<leader>fr` |

Dentro de cualquier buscador Telescope: `Ctrl+j`/`Ctrl+k` para moverte
entre resultados, `<CR>` para abrir, `Ctrl+v`/`Ctrl+x` para abrir en split
vertical/horizontal, `Esc` para salir.

## 7. LSP (autocompletado, errores, saltar a definición)

Con `pyright`, `ruff`, `typescript-language-server`, `prettier` y `eslint`
ya instalados, esto funciona en Python, JS, TS y React sin nada más:

| Acción | Atajo |
|---|---|
| Ir a la definición | `gd` |
| Ver referencias (dónde se usa) | `gr` |
| Ir a la implementación | `gI` |
| Ver documentación/tipo (hover) | `K` |
| Renombrar el símbolo en todo el proyecto | `<leader>cr` |
| Acciones rápidas (quick fix, como el bombillo de VS Code) | `<leader>ca` |
| Ver el error/warning de la línea actual | `<leader>cd` |
| Ir al próximo / anterior diagnóstico | `]d` / `[d` |
| Lista de todos los errores del proyecto | `<leader>xx` |
| Autocompletar | automático al escribir, `Ctrl+y` confirma, `Ctrl+n`/`Ctrl+p` para moverte |
| Formatear el archivo (prettier/ruff) | `<leader>cf`, o automático al guardar |

## 8. Splits y buffers (trabajar con varios archivos)

Un **buffer** es un archivo abierto en memoria (como una pestaña de VS
Code); un **split** es dividir la pantalla para ver varios a la vez —
son cosas independientes, podés tener 10 buffers y 1 sola ventana.

| Acción | Atajo |
|---|---|
| Split horizontal | `<leader>-` |
| Split vertical | `<leader>\|` |
| Moverte entre splits | `Ctrl+h/j/k/l` |
| Buffer siguiente / anterior | `Shift+l` / `Shift+h` |
| Ver todos los buffers abiertos | `<leader>,` (Telescope) o mirá la bufferline arriba |
| Cerrar el buffer actual | `<leader>bd` |

## 9. Modificar tu propia config

Todo vive en `~/.config/nvim`, y es un repo git propio (no el template
original). La estructura importa:

- `lua/config/lazy.lua` — acá se activan los **extras** de LazyVim (los
  imports `lazyvim.plugins.extras.*`). Agregar un lenguaje nuevo es
  agregar una línea acá.
- `lua/plugins/*.lua` — cada archivo devuelve una lista de specs de
  plugins. Podés agregar plugins nuevos o sobreescribir opciones de los
  que ya vienen con LazyVim (así están armados `theme.lua` y
  `neo-tree.lua` en esta config).
- `lua/plugins/example.lua` — queda de referencia (está desactivado con
  un `if true then return {} end` al principio), mostrando la sintaxis.

**Agregar un plugin nuevo:** creá un archivo en `lua/plugins/`, por
ejemplo `lua/plugins/mi-plugin.lua`:
```lua
return {
  { "autor/nombre-del-plugin" },
}
```
Guardá y corré `:Lazy sync` (o reiniciá nvim, LazyVim detecta el archivo
nuevo solo).

**Si rompiste algo:**
- `:Lazy` te muestra el estado de todos los plugins — desde ahí podés
  actualizar, deshabilitar o ver logs de errores.
- Como `~/.config/nvim` es un repo git propio: `git diff` para ver qué
  cambiaste, `git checkout -- lua/plugins/archivo.lua` para revertir un
  archivo puntual, o `git log` + `git reset --hard <commit>` si necesitás
  volver a un estado anterior completo.
- En el peor caso, `mv ~/.config/nvim ~/.config/nvim.roto` y volvé a
  clonar el starter — no perdés nada que no esté en el repo.

## Primera semana: los 20 comandos para memorizar primero

En orden de "cuánto los vas a usar", no de complejidad:

1. `<Esc>` — volver a modo Normal
2. `i` — insertar (empezar a escribir)
3. `<C-s>` — guardar
4. `h j k l` — moverte
5. `<leader>e` — abrir/cerrar el árbol de archivos
6. `<leader><space>` — buscar archivo por nombre
7. `<leader>/` — buscar texto en todo el proyecto
8. `v` — seleccionar
9. `y` / `d` / `p` — copiar / cortar / pegar (sobre selección o línea con `yy`/`dd`)
10. `u` / `Ctrl+r` — deshacer / rehacer
11. `o` — nueva línea abajo y a insertar
12. `gd` — ir a la definición
13. `K` — ver documentación/tipo bajo el cursor
14. `<leader>ca` — acciones rápidas (quick fix)
15. `Shift+h` / `Shift+l` — cambiar de buffer
16. `<leader>,` — ver/cambiar entre buffers abiertos
17. `<leader>xx` — ver todos los errores del proyecto
18. `<leader>-` / `<leader>|` — split horizontal / vertical
19. `<leader>gg` — abrir lazygit
20. `:%s/viejo/nuevo/g` — buscar y reemplazar en el archivo

Con esos 20 ya rendís igual o mejor que en VS Code para el 90% del
trabajo diario. Todo lo demás (macros, marks, registros, text objects
como `ciw`/`di"`) se va agregando solo, a medida que googleás "cómo hago
X en vim" cuando te frena algo puntual — no hace falta aprenderlo de
entrada.
