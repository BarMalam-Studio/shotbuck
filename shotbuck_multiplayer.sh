#!/bin/bash

### COLORES ###
ROJO='\033[0;31m'
AZUL='\033[0;34m' #Olvide añadir el color azul
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
    OPONENTE_ROL="JUGADOR 2 (Cliente)"
    ES_HOST=true #para levantar la vandera que somos host
    #manejo de los turnos
    TU_TURNO=true  #el host siempre empieza

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
    echo -e "${AMARILLO}Esperando a que el Jugador 2 se conecte...${RESET}"
    echo "INICIO" > $PIPE_OUT

elif [ "$1" == "cliente" ]; then
    MI_ROL="JUGADOR 2 (Cliente)"
    OPONENTE_ROL="JUGADOR 1 (Host)"
    TU_TURNO=false # El Cliente empieza esperando
    ES_HOST=false
    PIPE_OUT="/tmp/buckshot_2to1"
    PIPE_IN="/tmp/buckshot_1to2"

    #mensaje
    clear
    echo "Conectando con el Host..."
    read sync_msg < $PIPE_IN
    echo -e "${VERDE}¡Conectado a la partida!${RESET}"
    sleep 1.5
else #en caso haya argumentos incorrectos
    echo "Uso: $0 [host|cliente]"
    exit 1
fi

### CARGAR ESCOPETA ###
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
        echo -e "${AMARILLO}El Host está recargando la escopeta...${RESET}"
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

### BUCLE PRINCIPAL DE EVENTOS (heredado del single player) ###
while [ $vidas_jugador -gt 0 ] && [ $vidas_oponente -gt 0 ]; do

    #si se acaban las balas, el host genera más y sincroniza
    if [ ${#cargador[@]} -eq 0 ]; then
        cargar_escopeta
    fi

    clear
    mostrar_status

    if [ "$TU_TURNO" = true ]; then
        echo -e "\n${VERDE}ES TU TURNO${RESET} Que quieres hacer?"
        echo "1) Dispararle al Oponente"
        echo "2) Dispararte a ti mismo"
        echo -e "${AZUL}3) Usar Objeto (Bloqueado)${RESET}"
        read -p "Selecciona una opción (1-2): " opcion

        clear
        mostrar_status

        case $opcion in
            1)
                #extraemos la bala localmente
                bala=${cargador[0]}
                cargador=("${cargador[@]:1}")

                #enviamos la opcion al oponente
                echo "DISPARO:OPONENTE:$bala" > $PIPE_OUT

                echo -e "\n* Apuntas a tu oponente y presionas el gatillo... *"
                sleep 1.2
                if [ "$bala" == "real" ]; then
                    echo -e "Era un cartucho ${ROJO}REAL${RESET}. ¡Le diste!"
                    ((vidas_oponente--))
                else
                    echo -e "*Click* Era un cartucho ${AZUL}SEGURO${RESET}."
                fi
                TU_TURNO=false #pasamos el turno
                sleep 2.5
                ;;
            2)
                bala=${cargador[0]}
                cargador=("${cargador[@]:1}")
                echo "DISPARO:YO:$bala" > $PIPE_OUT

                echo -e "\n* Te apuntas a ti mismo y presionas el gatillo... *"
                sleep 1.2
                if [ "$bala" == "real" ]; then
                    echo -e "Era un cartucho ${ROJO}REAL${RESET}. Pierdes una vida."
                    ((vidas_jugador--))
                    TU_TURNO=false
                else
                    echo -e "*Click* Era un cartucho ${AZUL}SEGURO${RESET}. Conservas tu turno."
                fi
                sleep 2.5
                ;;
            *)
                echo -e "\nOpción no válida"; sleep 1.5 ;;
        esac
    else
        echo -e "\n${AMARILLO}Esperando la jugada de tu oponente...${RESET}"

        #esperamos que el rival escriba en su turno
        read evento < $PIPE_IN

        clear
        mostrar_status

        #PARSEAR EL MENSAJE RECIBIDO
        accion=$(echo $evento | cut -d':' -f1)

        if [ "$accion" == "DISPARO" ]; then
            objetivo=$(echo $evento | cut -d':' -f2)
            bala=$(echo $evento | cut -d':' -f3)

            #sincronizamos nuestro cargador local sacando la bala usada
            cargador=("${cargador[@]:1}")

            #interpretar la accion desde nuestra perspectiva
            if [ "$objetivo" == "OPONENTE" ]; then
                #si se apunta a oponente, te dispara
                echo -e "\n* ¡El oponente te apunta y dispara! *"
                sleep 1.5
                if [ "$bala" == "real" ]; then
                    echo -e "Era un cartucho ${ROJO}REAL${RESET}. Pierdes 1 vida."
                    ((vidas_jugador--))
                else
                    echo -e "Era un cartucho ${AZUL}SEGURO${RESET}. Te salvaste."
                fi
                TU_TURNO=true #nos devuelve el turno
            elif [ "$objetivo" == "YO" ]; then
                #se dispara a si mismo
                echo -e "\n* El oponente se apunta a sí mismo y dispara... *"
                sleep 1.5
                if [ "$bala" == "real" ]; then
                    echo -e "Era un cartucho ${ROJO}REAL${RESET}. El oponente pierde 1 vida."
                    ((vidas_oponente--))
                    TU_TURNO=true
                else
                    echo -e "Era un cartucho ${AZUL}SEGURO${RESET}. El oponente conserva su turno."
                fi
            fi
            sleep 3
        fi
    fi
done

### menu modificado del single player ###
clear
mostrar_status
echo -e "\n================================================================="
if [ $vidas_jugador -le 0 ]; then
    echo -e "                 ${ROJO}HAS MUERTO. FIN DEL JUEGO.${RESET}"
else
    echo -e "                 ${VERDE}¡HAS SOBREVIVIDO! VICTORIA.${RESET}"
fi
echo -e "=================================================================\n"
exit 0
