# WifiAuditor: Herramienta Avanzada de Auditoría WiFi (v2.0)

[![Spanish](https://img.shields.io/badge/language-Spanish-orange.svg)](README.md)

**WifiAuditor** es un script de Bash avanzado diseñado para realizar auditorías de seguridad en redes WiFi. Permite escanear redes, identificar clientes conectados, capturar _handshakes_ WPA/WPA2 y realizar ataques de fuerza bruta para descifrar contraseñas. Esta herramienta está pensada para profesionales de la seguridad y entusiastas con conocimientos técnicos.

## Características Principales

- **Escaneo de Redes:** Detecta redes WiFi cercanas y muestra información relevante como SSID, BSSID, canal, cifrado y potencia de la señal.
- **Identificación de Clientes:** Identifica los dispositivos conectados a una red WiFi específica.
- **Ataque de Deautenticación:** Permite desconectar clientes de una red para facilitar la captura del _handshake_.
- **Captura de Handshake:** Captura el _handshake_ WPA/WPA2 necesario para descifrar la contraseña.
- **Descifrado de Contraseñas:**
  - Utiliza diccionarios personalizados o existentes para ataques de fuerza bruta.
  - Genera diccionarios personalizados con `crunch`.
  - Soporte para `aircrack-ng` y `hashcat`.
  - Convierte capturas a formato HCCAPX para su uso posterior con `hashcat`.
- **Modo Monitor:** Configura automáticamente la interfaz de red en modo monitor.
- **Cambio de MAC:** Utiliza `macchanger` para anonimizar la dirección MAC de la interfaz.
- **Interfaz de Usuario Intuitiva:** Proporciona una interfaz de línea de comandos con colores y mensajes claros para facilitar su uso.
- **Registro de Actividad:** Guarda un registro detallado de todas las acciones en un archivo de log.
- **Limpieza Automática:** Restaura la configuración de la interfaz de red al finalizar.

## Requisitos

- **Sistema Operativo:** Linux (probado en distribuciones basadas en Debian).
- **Privilegios de Root:** El script debe ejecutarse con privilegios de superusuario (`sudo`).
- **Dependencias:**
  - `aircrack-ng`: Suite de herramientas para auditoría WiFi.
  - `macchanger`: Utilidad para cambiar la dirección MAC.
  - `xterm`: Emulador de terminal para mostrar ventanas separadas.
  - `bc`: Calculadora de precisión arbitraria.
  - `hashcat` (opcional): Herramienta de recuperación de contraseñas.
  - `crunch` (opcional): Generador de diccionarios.

## Instalación

1.  **Clonar el repositorio (si aplica):**
    ```bash
    git clone https://github.com/meyer-pidiache/wifi-security-assistant
    cd wifi-security-assistant
    ```
2.  **Instalar dependencias (ejemplo para Debian/Ubuntu):**

    ```bash
    sudo apt update
    sudo apt install aircrack-ng macchanger xterm bc hashcat crunch
    ```

3.  **Dar permisos de ejecución:**

    ```bash
    chmod +x wifi-auditor.sh
    ```

## Uso

1.  **Ejecutar el script con privilegios de root:**

    ```bash
    sudo ./wifi-auditor.sh
    ```

2.  **Seleccionar la interfaz de red:** El script detectará las interfaces inalámbricas disponibles. Selecciona la que deseas utilizar.

3.  **Escaneo de redes:** El script escaneará las redes WiFi cercanas. Presiona `Ctrl+C` cuando veas la red objetivo.

4.  **Seleccionar la red objetivo:** Elige la red que deseas auditar de la lista.

5.  **Escaneo de clientes:** El script mostrará los clientes conectados a la red seleccionada. Presiona `Ctrl+C` cuando hayas identificado los clientes.

6.  **Seleccionar el cliente (o broadcast):** Puedes elegir un cliente específico o realizar un ataque de deautenticación a todos los dispositivos (`broadcast`).

7.  **Ataque de deautenticación y captura de handshake:** El script enviará paquetes de deautenticación y capturará el _handshake_ cuando un dispositivo se reconecte. Presiona `Ctrl+C` cuando veas el mensaje "WPA handshake".

8.  **Descifrado de contraseña:**

    - **Opción 1 (Diccionario existente):** Proporciona la ruta a un diccionario de contraseñas.
    - **Opción 2 (Generar diccionario):** Configura los parámetros (longitud, caracteres) para generar un diccionario personalizado con `crunch`.
    - **Opción 3 (Convertir a HCCAPX):** Convierte la captura a formato HCCAPX para usarla con `hashcat` posteriormente.

9.  **Opciones de la línea de comandos:**

    - `-h`, `--help`: Muestra la ayuda.
    - `-i`, `--interface <iface>`: Especifica la interfaz de red directamente.
    - `-v`, `--verbose`: Modo verboso para obtener información más detallada.
    - `-c`, `--clean`: Restaura la interfaz a su estado original y sale.

**Ejemplos:**

- Ejecutar con interfaz predeterminada: `sudo ./wifi-auditor.sh`
- Especificar interfaz: `sudo ./wifi-auditor.sh -i wlan0`
- Modo verboso: `sudo ./wifi-auditor.sh -v`
- Solo limpiar: `sudo ./wifi-auditor.sh -c`

## Cosas por mejorar
- [ ] Cuando no se use sudo, evitar configurar o restablecer cosas.
- [ ] Mostrar las dependencias faltantes en una sola iteración, en lugar de una por una.
- [ ] Ordenar por potencia de señal las redes.
- [ ] Mostrar nombres de las redes después del primer Ctrl + c.
- [ ] Mejorar coincidencia de títulos con el ancho de su columna.
- [ ] Seleccionar el canal objetivo de otra manera, ya que se muestra la fecha actual en lugar del número del canal.

## Consideraciones Importantes

- **Legalidad:** Utiliza esta herramienta solo en redes WiFi de tu propiedad o en aquellas donde tengas permiso explícito para realizar pruebas de seguridad. El uso no autorizado en redes ajenas es ilegal y puede tener consecuencias legales.
- **Ética:** Realiza auditorías de seguridad de forma responsable y ética. No utilices esta herramienta para fines maliciosos.
- **Entorno Controlado:** Se recomienda utilizar esta herramienta en un entorno de pruebas controlado para evitar interrupciones en redes reales.
- **Éxito del Descifrado:** El éxito del descifrado de contraseñas depende de la complejidad de la contraseña y de la calidad del diccionario utilizado. No hay garantía de éxito.

## Descargo de Responsabilidad

Esta herramienta se proporciona "tal cual", sin garantía de ningún tipo. Los autores no se hacen responsables del uso indebido de esta herramienta ni de los daños que pueda causar. El usuario es el único responsable de sus acciones.

## Licencia

Este proyecto se distribuye bajo la licencia MIT. Consulta el archivo `LICENSE` para obtener más detalles.
