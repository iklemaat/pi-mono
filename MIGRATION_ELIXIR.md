# Migración a Elixir y Erlang

Este documento detalla la estrategia hiperdetallada para migrar el monorepositorio **Pi (TypeScript)** a un entorno de **Elixir y Erlang**.
La migración utilizará un **proyecto Umbrella de Elixir**, sustituyendo la lógica de peticiones con `Req`, el manejo de terminal UI con `Ratatouille` y toda la arquitectura y flujos de trabajo de los agentes de Inteligencia Artificial utilizando **Jido** y **Reactor**.

---

## 1. Arquitectura Base: Elixir Umbrella Project

El monorepositorio se mantendrá estructuralmente usando la capacidad nativa de Elixir para aplicaciones múltiples en un solo repositorio: El **Umbrella Project**.

```bash
# Creación del proyecto base
mix new pi_mono --umbrella
cd pi_mono/apps
```

### Mapeo de Paquetes (Packages) a Aplicaciones OTP (Apps)

| TypeScript Package | Elixir OTP App | Descripción y Equivalencia Tecnológica |
| :--- | :--- | :--- |
| `@mariozechner/pi-ai` | `pi_ai` | Capa de unificación LLM (OpenAI, Anthropic, Gemini, etc.). Usará **Req** en lugar de Axios/Fetch para peticiones a APIs. |
| `@mariozechner/pi-agent-core` | `pi_agent_core` | Capa base de agentes y estado. Será **completamente reescrita** utilizando el framework **Jido** (Agents, Actions) y **Reactor** (Orquestación de flujos de trabajo/Workflows). |
| `@mariozechner/pi-coding-agent` | `pi_coding_agent` | El cliente CLI/Agente interactivo de código base. Usará las abstracciones de `pi_agent_core` y expondrá herramientas para leer archivos, ejecutar bash, etc. |
| `@mariozechner/pi-tui` | `pi_tui` | Motor de Terminal UI. Se reescribirá usando **Ratatouille** y NIFs de Rust en caso de necesitar renderizado de alto rendimiento o parseo complejo, o simplemente Elixir puro con Ratatouille. |
| `@mariozechner/pi-mom` | `pi_mom` | Bot de Slack. Usará un cliente de websocket/http en Elixir y redirigirá mensajes a flujos de trabajo de **Jido/Reactor**. |
| `@mariozechner/pi-web-ui` | `pi_web_ui` | Aplicación Web. Migración a **Phoenix LiveView** (o sirviendo web components mediante Plug/Cowboy) para aprovechar web sockets nativos y renderizado en servidor. |
| `@mariozechner/pi-pods` | `pi_pods` | Orquestador de contenedores vLLM. Usará peticiones SSH y HTTP/Req para interactuar con pods remotos. |

---

## 2. Definición de Herramientas Obligatorias

*   **Jido (`jidoai`)**: framework basado en la arquitectura de actores de Erlang/Elixir, utilizado para definir las acciones atómicas (Actions), agentes con estado y memoria (Agents), y el bus de eventos subyacente.
*   **Reactor**: Para diseñar flujos de trabajo (Workflows) declarativos, manejando asincronía, reintentos y lógica de dependencias (DAG) dentro de la ejecución de los agentes.
*   **Req**: Cliente HTTP por defecto. Será la piedra angular de `pi_ai` para comunicarse con todos los proveedores de modelos.
*   **Ratatouille**: Framework TUI basado en Erlang NIFs para termbox. Servirá para renderizar de manera diferencial la interfaz de comandos en `pi_tui`.

---

## 3. Plan de Migración (Tickets y Fases)

A continuación se listan los tickets detallados para ejecutar esta migración.

### ~🎟️ Ticket 1: Inicialización del Umbrella Project y Configuración Base~ (✅ Completado)
**Objetivo:** Crear el proyecto base, configurar linters (`credo`), tipado dinámico (`dialyxir`), y formateadores, junto al esqueleto de aplicaciones Umbrella.
**Criterios de Aceptación:**
- El repositorio raíz contiene la estructura de `mix new --umbrella`.
- `mix compile` y `mix test` funcionan sin errores en el umbrella raíz.
- Credo y Dialyzer están configurados.
**Tests a Pasar:**
- No aplica lógica de negocio aún, solo validación de configuración de CI/CD base en GitHub Actions (e.g. `mix format --check-formatted`).

### ~🎟️ Ticket 2: Migrar `pi-ai` a Elixir OTP App (`pi_ai`)~ (✅ Iniciado - App y dependencias creadas)
**Objetivo:** Crear un cliente unificado de LLMs que acepte un esquema estándar de mensajes (system, user, assistant) y use **Req** para llamar a proveedores.
**Dependencias:** `req`, `jason` (para parseo JSON).
**Criterios de Aceptación:**
- Debe soportar los mismos proveedores principales: OpenAI, Anthropic, Gemini.
- Manejar streaming de tokens usando `Req` asíncrono.
- La firma de la API debe devolver tuplas `{ :ok, response }` o `{ :error, reason }`.
**Tests a Pasar:**
- `ExUnit` unitarios para los adaptadores de cada proveedor (verificando la correcta construcción del request JSON).
- Mockear peticiones HTTP con **Bypass** para simular respuestas de la API de OpenAI (incluyendo streaming chunks) y verificar el correcto ensamblado de texto y *tool calls*.

### 🎟️ Ticket 3: Migrar `pi-agent-core` usando Jido y Reactor (`pi_agent_core`)
**Objetivo:** Reemplazar el motor de bucle del agente Typescript por el modelo basado en actores y workflows.
**Dependencias:** `jido`, `reactor`, `pi_ai`.
**Criterios de Aceptación:**
- Se deben crear `Jido.Action` para invocar a `pi_ai`.
- Se deben definir `Jido.Agent` para mantener el historial de la conversación, configuración del agente y memoria a corto plazo.
- Se debe usar `Reactor` para definir el pipeline: `[Parse Input -> Invoke LLM -> Dispatch Tools -> Update Agent State]`.
- Se debe definir una abstracción genérica para añadir herramientas (Tools).
**Tests a Pasar:**
- Tests de las acciones puras (Jido.Action) alimentándolas con diferentes estados.
- Tests de flujo (Reactor) inyectando LLMs mockeados para verificar que las herramientas se llaman según la respuesta de la red neuronal.

### 🎟️ Ticket 4: Migrar `pi-tui` utilizando Ratatouille (`pi_tui`)
**Objetivo:** Migrar la librería de UI diferencial que se comunica con la terminal y dibuja cajas, texto, markdown.
**Dependencias:** `ratatouille`.
**Criterios de Aceptación:**
- Crear un motor de loop de eventos compatible con OTP (`GenServer` de Ratatouille).
- Implementar los componentes visuales: Viewports, Input Box, Chat History Scroll.
- Capturar eventos de teclado de manera asíncrona y pasarlos al controlador.
**Tests a Pasar:**
- Unitarios para validar la generación de `Ratatouille.View` trees según el estado de la UI (por ejemplo, validando si un mensaje largo renderiza la vista correctamente).
- Elixir property-based testing para enviar miles de pulsaciones de teclado a los buffers de entrada.

### 🎟️ Ticket 5: Migrar `pi-coding-agent` (`pi_coding_agent`)
**Objetivo:** Recrear la lógica central de la herramienta CLI. Implementar herramientas específicas como bash, lectura de archivos, y edición de bloques (merge diffs).
**Dependencias:** `pi_agent_core`, `pi_tui`.
**Criterios de Aceptación:**
- Debe existir un `Jido.Action` para leer un archivo (Read).
- `Jido.Action` para escribir archivos (Write/Edit).
- `Jido.Action` para ejecutar comandos bash (usando `System.cmd` o `MuonTrap` para aislar procesos bash y capturar stdout/stderr).
- El agente inicializa la UI y conecta los streams de eventos al agente base (`pi_agent_core`).
**Tests a Pasar:**
- Tests de integración montando un directorio temporal (Sandbox) y evaluando que el `Action` de bash modifica o lee correctamente el archivo real en disco.
- Tests completos de un flujo de Reactor en un Sandbox para verificar que si el "LLM" pide editar el archivo, los contenidos en el sistema de archivos efectivamente mutan.

### 🎟️ Ticket 6: Migración de `pi-web-ui` a Phoenix LiveView (`pi_web_ui`)
**Objetivo:** Reemplazar los componentes web por una UI centralizada en servidor para chatear con agentes web.
**Dependencias:** `phoenix`, `phoenix_live_view`.
**Criterios de Aceptación:**
- Renderizado diferencial y reactividad directamente desde el servidor Elixir al navegador del cliente.
- Conectar componentes web para Markdown render y copiado al portapapeles en JS (Hooks de LiveView).
**Tests a Pasar:**
- `LiveViewTest` asertando comportamientos al renderizar mensajes que llegan por PubSub (eventos de Jido de que el agente respondió algo).

### 🎟️ Ticket 7: Migrar `pi-mom` y `pi-pods`
**Objetivo:** Portar el bot de Slack y el CLI de GPU pods.
**Criterios de Aceptación:**
- `pi_mom` debe conectar con la API de SocketMode de Slack.
- `pi_pods` debe manejar la creación de droplets/pods usando `Req` contra RunPod/Vast o similar y manejar polling del estado del servidor.
**Tests a Pasar:**
- Tests con Mocks de las APIs externas para validar el enrutamiento de peticiones de Slack y el parseo de instancias de máquinas en `pi_pods`.

---
## Conclusión y Próximos Pasos

Al seguir esta guía, transformaremos un proyecto Typescript orientado a estado mutable en un proyecto distribuido, tolerante a fallos, y asíncrono utilizando los estándares del ecosistema OTP, Jido y Reactor. El primer paso recomendado para el equipo es ejecutar el **Ticket 1** y seguidamente el **Ticket 2** para asentar las bases de la API.