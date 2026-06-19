#!/bin/bash

### COLORES ###
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

### LIMPIEZA DE PROCESOS (IPC) ###
#limpiamos las tuberias si cancelamos el script con Ctrl+C para evitar conflictos
trap 'rm -f /tmp/buckshot_1to2 /tmp/buckshot_2to1; exit' INT TERM EXIT

### CONFIGURACIÓN IPC Y ROLES (Handshake) ###
if [ "$1" == "host" ]; then #en caso iniciemos la partida con el argumento host
    MI_ROL="JUGADOR 1 (Host)"
    #asignamos las direcciones donde se enviaran y recibiran los datos
    PIPE_OUT="/tmp/buckshot_1to2"
    PIPE_IN="/tmp/buckshot_2to1"

    #eliminamos los posibles datos residuales de una partida concluida
    rm -f $PIPE_OUT $PIPE_IN
    #creamos las named pipes y con 2... ocultamos cualquier error
    mkfifo $PIPE_OUT 2>/dev/null
    mkfifo $PIPE_IN 2>/dev/null

    #limpiamos pantalla
    clear
    #mensajes
    echo -e "${AMARILLO}Iniciando servidor local...${RESET}"
    echo -e "${AMARILLO}Esperando a que el Jugador 2 se conecte en otra terminal...${RESET}"

    #detenemos el flujo hasta que se escriba algun dato en la tuberia
    echo "INICIO" > $PIPE_OUT

    #mensajes
    echo -e "${VERDE}El Jugador 2 se ha conectado, Handshake exitoso.${RESET}"
    sleep 2

elif [ "$1" == "cliente" ]; then
    MI_ROL="JUGADOR 2 (Cliente)"
    PIPE_OUT="/tmp/buckshot_2to1"
    PIPE_IN="/tmp/buckshot_1to2"

    #mensaje
    clear
    echo -e "${AMARILLO}Buscando partida del Host...${RESET}"

    #el cliente intenta leer la tuberia, si el host no ha escrito nada, detiene el flujo
    read sync_msg < $PIPE_IN

    #mensaje
    echo -e "${VERDE}Conectado a la partida del Host exitosamente${RESET}"
    sleep 2

else #en caso haya argumentos incorrectos
    echo -e "${ROJO}Uso incorrecto del programa.${RESET}"
    echo "Para crear una partida ejecuta: $0 host"
    echo "Para unirte a una partida ejecuta: $0 cliente"
    exit 1
fi

### VERIFICACIÓN DE FASE ###
echo -e "\n======================================================="
echo -e " Eres el: ${AMARILLO}$MI_ROL${RESET}"
echo -e " Estado:  ${VERDE}CONEXIÓN IPC ESTABLECIDA${RESET}"
echo -e "======================================================="

exit 0
