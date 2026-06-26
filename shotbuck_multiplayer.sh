#!/bin/bash

### COLORES ###
ROJO='\033[0;31m'
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

### LIMPIEZA DE PROCESOS (IPC) ###
trap 'rm -f /tmp/buckshot_1to2 /tmp/buckshot_2to1; exit' INT TERM EXIT

### CONFIGURACIÓN IPC Y ROLES ###
if [ "$1" == "host" ]; then
    MI_ROL="JUGADOR 1 (Host)"
    OPONENTE_ROL="JUGADOR 2 (Cliente)"
    TU_TURNO=true
    ES_HOST=true
    PIPE_OUT="/tmp/buckshot_1to2"
    PIPE_IN="/tmp/buckshot_2to1"

    rm -f $PIPE_OUT $PIPE_IN
    mkfifo $PIPE_OUT 2>/dev/null
    mkfifo $PIPE_IN 2>/dev/null

    clear
    echo -e "${AMARILLO}Esperando a que el Jugador 2 se conecte...${RESET}"
    echo "INICIO" > $PIPE_OUT
elif [ "$1" == "cliente" ]; then
    MI_ROL="JUGADOR 2 (Cliente)"
    OPONENTE_ROL="JUGADOR 1 (Host)"
    TU_TURNO=false
    ES_HOST=false
    PIPE_OUT="/tmp/buckshot_2to1"
    PIPE_IN="/tmp/buckshot_1to2"

    clear
    echo "Conectando con el Host..."
    read sync_msg < $PIPE_IN
    echo -e "${VERDE}¡Conectado a la partida!${RESET}"
    sleep 1.5
else
    echo "Uso: $0 [host|cliente]"
    exit 1
fi

### VARIABLES GLOBALES ###
MAX_VIDAS=3
vidas_jugador=$MAX_VIDAS
vidas_oponente=$MAX_VIDAS
OBJETOS=("Lupa" "Inversor" "Cerveza")
inv_jugador=()
inv_oponente=()

### CONTROL CARTUCHOS ###
cargar_escopeta() {
    clear
    if [ "$ES_HOST" = true ]; then
        total_balas=$(( RANDOM % 7 + 2 ))
        balas_reales=$(( RANDOM % (total_balas - 1) + 1 ))
        balas_seguras=$(( total_balas - balas_reales ))

        for ((k=0; k<2; k++)); do
            if [ ${#inv_jugador[@]} -lt 8 ]; then inv_jugador+=("${OBJETOS[$((RANDOM % 3))]}"); fi
            if [ ${#inv_oponente[@]} -lt 8 ]; then inv_oponente+=("${OBJETOS[$((RANDOM % 3))]}"); fi
        done

        cargador=()
        for ((i=0; i<balas_reales; i++)); do cargador+=("real"); done
        for ((i=0; i<balas_seguras; i++)); do cargador+=("segura"); done

        for ((i=${#cargador[@]}-1; i>0; i--)); do
            j=$(( RANDOM % (i + 1) ))
            tmp=${cargador[i]}
            cargador[i]=${cargador[j]}
            cargador[j]=$tmp
        done

        str_cargador=$(IFS=,; echo "${cargador[*]}")
        str_inv_h=$(IFS=,; echo "${inv_jugador[*]}")
        str_inv_c=$(IFS=,; echo "${inv_oponente[*]}")
        echo "CARGA:$str_cargador|$str_inv_h|$str_inv_c" > $PIPE_OUT
    else
        echo -e "${AMARILLO}El Host está recargando la escopeta...${RESET}"
        read sync_carga < $PIPE_IN

        datos=${sync_carga#CARGA:}
        IFS='|' read -r str_cargador str_inv_op str_inv_mi <<< "$datos"

        IFS=',' read -r -a cargador <<< "$str_cargador"
        IFS=',' read -r -a inv_oponente <<< "$str_inv_op"
        IFS=',' read -r -a inv_jugador <<< "$str_inv_mi"

        balas_reales=0
        balas_seguras=0
        for bala in "${cargador[@]}"; do
            if [ "$bala" == "real" ]; then ((balas_reales++)); else ((balas_seguras++)); fi
        done
    fi

    clear
    echo -e "\n${AMARILLO}---ESCOPETA EN LA MESA---${RESET}"
    echo -n "Cargando cartuchos: "
    for ((i=0; i<balas_reales; i++)); do echo -ne "${ROJO}| ${RESET}"; sleep 0.5; done
    for ((i=0; i<balas_seguras; i++)); do echo -ne "${AZUL}| ${RESET}"; sleep 0.5; done
    echo ""
    sleep 2
}

### ESTADO ###
mostrar_status() {
    echo -e "\n================================================================="
    echo -e " $MI_ROL: [${VERDE}$vidas_jugador/$MAX_VIDAS Vidas${RESET}]  |  $OPONENTE_ROL: [${VERDE}$vidas_oponente/$MAX_VIDAS Vidas${RESET}]"
    if [ ${#inv_jugador[@]} -gt 0 ]; then echo -e " TUS OBJETOS: ${AMARILLO}${inv_jugador[*]}${RESET}"; else echo -e " TUS OBJETOS: Vacío"; fi
    if [ ${#inv_oponente[@]} -gt 0 ]; then echo -e " OBJETOS RIVAL: ${AMARILLO}${inv_oponente[*]}${RESET}"; else echo -e " OBJETOS RIVAL: Vacío"; fi
    echo "================================================================="
}

### BUCLE PRINCIPAL ###
while [ $vidas_jugador -gt 0 ] && [ $vidas_oponente -gt 0 ]; do

    if [ ${#cargador[@]} -eq 0 ]; then
        cargar_escopeta
    fi

    clear
    mostrar_status

    if [ "$TU_TURNO" = true ]; then
        echo -e "\n${VERDE}¡ES TU TURNO!${RESET} ¿Qué quieres hacer?"
        echo "1) Dispararle al Oponente"
        echo "2) Dispararte a ti mismo"
        echo "3) Usar Objeto"
        read -p "Selecciona una opción (1-3): " opcion

        clear
        mostrar_status

        case $opcion in
            1)
                bala=${cargador[0]}
                cargador=("${cargador[@]:1}")
                echo "DISPARO:OPONENTE:$bala" > $PIPE_OUT

                echo -e "\n* Apuntas a tu oponente y presionas el gatillo... *"
                sleep 1.2
                if [ "$bala" == "real" ]; then
                    echo -e "Era un cartucho ${ROJO}REAL${RESET}. ¡Le diste!"
                    ((vidas_oponente--))
                else
                    echo -e "*Click* Era un cartucho ${AZUL}SEGURO${RESET}."
                fi
                TU_TURNO=false
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
            3)
                if [ ${#inv_jugador[@]} -eq 0 ]; then
                    echo -e "\nNo tienes objetos."
                    sleep 1.5; continue
                fi
                echo -e "\nSelecciona un objeto:"
                for i in "${!inv_jugador[@]}"; do echo "$i) ${inv_jugador[$i]}"; done
                read -p "Índice (Enter para cancelar): " obj_idx

                clear
                mostrar_status

                if [[ "$obj_idx" =~ ^[0-9]+$ ]] && [ "$obj_idx" -lt "${#inv_jugador[@]}" ]; then
                    item="${inv_jugador[$obj_idx]}"
                    unset 'inv_jugador[$obj_idx]'
                    inv_jugador=("${inv_jugador[@]}") # Reindexar

                    echo "OBJETO:$item" > $PIPE_OUT
                    echo -e "\n* Usas: ${AMARILLO}$item${RESET} *"
                    sleep 1.5

                    case "$item" in
                        "Lupa")
                            echo -e "Revisas la recámara, el cartucho es: ${AMARILLO}${cargador[0]}${RESET}"
                            sleep 2.5 ;;
                        "Inversor")
                            if [ "${cargador[0]}" == "real" ]; then cargador[0]="segura"; else cargador[0]="real"; fi
                            echo -e "Se ha invertido la polaridad del cartucho."
                            sleep 2.5 ;;
                        "Cerveza")
                            descartada=${cargador[0]}
                            cargador=("${cargador[@]:1}")
                            if [ "$descartada" == "real" ]; then echo -e "Se expulsó un cartucho ${ROJO}REAL${RESET}."; else echo -e "Se expulsó un cartucho ${AZUL}SEGURO${RESET}."; fi
                            sleep 3 ;;
                    esac
                else
                    echo -e "\nAcción cancelada."; sleep 1.5
                fi
                ;;
            *)
                echo -e "\nOpción no válida"; sleep 1.5 ;;
        esac
    else
        echo -e "\n${AMARILLO}Esperando la jugada de tu oponente...${RESET}"

        # Bloqueo: Esperar mensaje del otro proceso
        read evento < $PIPE_IN

        clear
        mostrar_status

        accion=$(echo $evento | cut -d':' -f1)

        if [ "$accion" == "DISPARO" ]; then
            objetivo=$(echo $evento | cut -d':' -f2)
            bala=$(echo $evento | cut -d':' -f3)
            cargador=("${cargador[@]:1}")

            if [ "$objetivo" == "OPONENTE" ]; then
                echo -e "\n* ¡El oponente te apunta y dispara! *"
                sleep 1.5
                if [ "$bala" == "real" ]; then
                    echo -e "Era un cartucho ${ROJO}REAL${RESET}. Pierdes 1 vida."
                    ((vidas_jugador--))
                else
                    echo -e "Era un cartucho ${AZUL}SEGURO${RESET}. Te salvaste."
                fi
                TU_TURNO=true
            elif [ "$objetivo" == "YO" ]; then
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

        elif [ "$accion" == "OBJETO" ]; then
            item=$(echo $evento | cut -d':' -f2)

            # Quitar objeto del inventario visual del rival
            unset 'inv_oponente[0]'
            inv_oponente=("${inv_oponente[@]}")

            echo -e "\n* El oponente usa: ${AMARILLO}$item${RESET} *"
            sleep 1.5

            case "$item" in
                "Lupa")
                    echo -e "El oponente revisó la recámara."
                    sleep 2.5 ;;
                "Inversor")
                    if [ "${cargador[0]}" == "real" ]; then cargador[0]="segura"; else cargador[0]="real"; fi
                    echo -e "El oponente invirtió la polaridad del cartucho actual."
                    sleep 2.5 ;;
                "Cerveza")
                    descartada=${cargador[0]}
                    cargador=("${cargador[@]:1}")
                    if [ "$descartada" == "real" ]; then echo -e "El oponente expulsó un cartucho ${ROJO}REAL${RESET}."; else echo -e "El oponente expulsó un cartucho ${AZUL}SEGURO${RESET}."; fi
                    sleep 3 ;;
            esac
        fi
    fi
done

# --- Fin de la partida ---
clear
mostrar_status
echo -e "\n================================================================="
if [ $vidas_jugador -le 0 ]; then
    echo -e "                 ${ROJO}HAS MUERTO. FIN DEL JUEGO.${RESET}"
else
    echo -e "                 ${VERDE}¡HAS SOBREVIVIDO! VICTORIA.${RESET}"
fi
echo -e "=================================================================\n"
sleep 4
exit
