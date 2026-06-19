#!/bin/bash

### COLORES ###
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

### LIMPIEZA DE PROCESOS (IPC) ###
#limpiamos las tuberias si cancelamos el script con Ctrl+C para evitar conflictos
trap 'rm -f /tmp/buckshot_1to2 /tmp/buckshot_2to1; exit' INT TERM EXIT

### VARIABLES GLOBALES ###
MAX_VIDAS=3
vidas_jugador=$MAX_VIDAS
vidas_oponente=$MAX_VIDAS
OBJETOS=("Lupa" "Inversor" "Cerveza")
inv_jugador=()
inv_oponente=()
cargador=()

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

### LOGICA DE SINCRONIZACION ###
cargar_escopeta() {
    clear
    if [ "$ES_HOST" = true ]; then
        #el host genera el nuevo entorno
        echo -e "${AMARILLO}Generando el estado de la partida...${RESET}"
        total_balas=$(( RANDOM % 7 + 2 ))
        balas_reales=$(( RANDOM % (total_balas - 1) + 1 ))
        balas_seguras=$(( total_balas - balas_reales ))

        #repartir objetos iniciales
        for ((k=0; k<2; k++)); do
            inv_jugador+=("${OBJETOS[$((RANDOM % 3))]}")
            inv_oponente+=("${OBJETOS[$((RANDOM % 3))]}")
        done

        #llenar y mezclar cargador
        for ((i=0; i<balas_reales; i++)); do cargador+=("real"); done
        for ((i=0; i<balas_seguras; i++)); do cargador+=("segura"); done
        for ((i=${#cargador[@]}-1; i>0; i--)); do
            j=$(( RANDOM % (i + 1) ))
            tmp=${cargador[i]}
            cargador[i]=${cargador[j]}
            cargador[j]=$tmp
        done

        #convertir arrays a texto y enviar al cliente, serializar
        str_cargador=$(IFS=,; echo "${cargador[*]}")
        str_inv_h=$(IFS=,; echo "${inv_jugador[*]}")
        str_inv_c=$(IFS=,; echo "${inv_oponente[*]}")

        #formato del paquete: CARGA:balas|objetos_oponente|mis_objetos
        echo "CARGA:$str_cargador|$str_inv_h|$str_inv_c" > $PIPE_OUT
    else
        #el cliente espera y des serializa el paquete
        echo -e "${AMARILLO}El Host está recargando la escopeta y repartiendo objetos...${RESET}"
        read sync_carga < $PIPE_IN

        datos=${sync_carga#CARGA:}
        IFS='|' read -r str_cargador str_inv_op str_inv_mi <<< "$datos"

        IFS=',' read -r -a cargador <<< "$str_cargador"
        IFS=',' read -r -a inv_oponente <<< "$str_inv_op"
        IFS=',' read -r -a inv_jugador <<< "$str_inv_mi"

        #contar balas solo para poder hacer la animación visual
        balas_reales=0
        balas_seguras=0
        for bala in "${cargador[@]}"; do
            if [ "$bala" == "real" ]; then ((balas_reales++)); else ((balas_seguras++)); fi
        done
    fi

    #ambos tipos de ejecucion muestran la misma animacion
    clear
    echo -e "\n${AMARILLO}---ESCOPETA EN LA MESA---${RESET}"
    echo -n "Cargando cartuchos: "
    for ((i=0; i<balas_reales; i++)); do echo -ne "${ROJO}| ${RESET}"; sleep 0.5; done
    for ((i=0; i<balas_seguras; i++)); do echo -ne "${AZUL}| ${RESET}"; sleep 0.5; done
    echo ""
    sleep 2
}

mostrar_status() {
    echo -e "\n================================================================="
    echo -e " $MI_ROL: [${VERDE}$vidas_jugador/$MAX_VIDAS Vidas${RESET}]  |  $OPONENTE_ROL: [${VERDE}$vidas_oponente/$MAX_VIDAS Vidas${RESET}]"
    if [ ${#inv_jugador[@]} -gt 0 ]; then echo -e " TUS OBJETOS: ${AMARILLO}${inv_jugador[*]}${RESET}"; else echo -e " TUS OBJETOS: Vacío"; fi
    if [ ${#inv_oponente[@]} -gt 0 ]; then echo -e " OBJETOS RIVAL: ${AMARILLO}${inv_oponente[*]}${RESET}"; else echo -e " OBJETOS RIVAL: Vacío"; fi
    echo "================================================================="
}

### PRUEBA DE LA FASE 2 ###
cargar_escopeta
clear
mostrar_status

echo -e "\n${VERDE}Generación de entorno exitosa. Ambos clientes comparten el mismo estado.${RESET}"
echo "El arreglo del cargador es: ${cargador[*]}"

exit 0
