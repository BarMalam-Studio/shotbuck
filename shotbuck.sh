#!/bin/bash

###COLORES###
ROJO='\033[0;31m'
AZUL='\033[0;34m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

###VIDAS###
MAX_VIDAS=3
vidas_jugador=$MAX_VIDAS
vidas_dealer=$MAX_VIDAS

###CONTADORES DE BALAS###
reales_restantes=0
seguras_restantes=0

###CONTROL CARTUCHSO###
cargar_escopeta() {
    total_balas=$(( RANDOM % 7 + 2 )) #2-8

    #1 real min, no todo de un solo tipo
    balas_reales=$(( RANDOM % (total_balas - 1) + 1 ))
    balas_seguras=$(( total_balas - balas_reales ))

    echo -e "\n${AMARILLO}---ESCOPETA EN LA MESA---${RESET}"
    echo -n "Cargando cartuchos: "

    #reales = rojo
    for ((i=0; i<balas_reales; i++)); do
        echo -ne "${ROJO}| ${RESET}"
        sleep 1
    done

    #falsas =  azules
    for ((i=0; i<balas_seguras; i++)); do
        echo -ne "${AZUL}| ${RESET}"
        sleep 1
    done

    echo "" #salto de linea para terminar la """animacion"""
    sleep 1.5

    clear #limpiamos pantalla

    cargador=()
    #llenamos
    for ((i=0; i<balas_reales; i++)); do cargador+=("real"); done
    for ((i=0; i<balas_seguras; i++)); do cargador+=("segura"); done

    #Algoritmo Fisher-Yates simple para mezclar contenido
    for ((i=${#cargador[@]}-1; i>0; i--)); do
        j=$(( RANDOM % (i + 1) ))
        #cambio
        tmp=${cargador[i]}
        cargador[i]=${cargador[j]}
        cargador[j]=$tmp
    done
}

###ESTADO###
mostrar_status() {
    echo -e "\n========================================"
    echo -e " JUGADOR: [${VERDE}$vidas_jugador/$MAX_VIDAS Vidas${RESET}]  |  DEALER: [${VERDE}$vidas_dealer/$MAX_VIDAS Vidas${RESET}]"
    #test
    #echo " Cartuchos restantes en la recámara: ${#cargador[@]}"
    echo "========================================"
}

###DISPARO###
disparar() {
    #a quien?
    local tirador=$1
    local objetivo=$2

    #toma bala
    local bala=${cargador[0]}
    cargador=("${cargador[@]:1}") #quita bala

    echo -e "\n* $tirador apunta a $objetivo y presiona el gatillo... *"
    sleep 1.2

    if [ "$bala" == "real" ]; then #real
        echo -e "Era un cartucho ${ROJO}REAL${RESET}"
        ((reales_restantes--))
        if [ "$objetivo" == "JUGADOR" ]; then #a ti
            ((vidas_jugador--))
        else #al otro
            ((vidas_dealer--))
        fi
        sleep 2
        return 1 #daño = flujo de turnos normal
    else
        echo -e "Era un cartucho ${AZUL}SEGURO${RESET}"
        ((seguras_restantes--))
        sleep 2
        if [ "$tirador" == "$objetivo" ]; then #a ti
            echo "Conservas tu turno."
            sleep 2
            return 0 #no daño propio = no cambia turno
        fi
        return 1 #no daño = flujo normal
    fi
}

###PRINCIPAL###
while [ $vidas_jugador -gt 0 ] && [ $vidas_dealer -gt 0 ]; do

    #si esta vacia, se carga de nuevo
    if [ ${#cargador[@]} -eq 0 ]; then
        cargar_escopeta
    fi

    ###TURNO JUGADOR###
    turno_jugador=true
    while $turno_jugador && [ $vidas_jugador -gt 0 ] && [ $vidas_dealer -gt 0 ] && [ ${#cargador[@]} -gt 0 ]; do
        mostrar_status
        echo "Es tu turno. ¿Qué quieres hacer?"
        echo "1) Dispararle al Dealer"
        echo "2) Dispararte a ti mismo"
        read -p "Selecciona una opción (1-2): " opcion
        clear #limpiar
        case $opcion in
            1)
                disparar "JUGADOR" "DEALER"
                turno_jugador=false #ya no ser tu turno
                ;;
            2)
                disparar "JUGADOR" "JUGADOR"
                #si 1, cambia turno
                if [ $? -eq 1 ]; then
                    turno_jugador=false
                fi
                ;;
            *)
                echo "Opción no válida"
                sleep 1
                clear #limpiar
                continue
                ;;
        esac
        clear
    done

    #alguien se murio?
    if [ $vidas_jugador -le 0 ] || [ $vidas_dealer -le 0 ]; then break; fi
    if [ ${#cargador[@]} -eq 0 ]; then continue; fi

    ###TURNO DEALER###
    turno_dealer=true
    while $turno_dealer && [ $vidas_jugador -gt 0 ] && [ $vidas_dealer -gt 0 ] && [ ${#cargador[@]} -gt 0 ]; do
        mostrar_status
        echo "Turno del Dealer... pensando..."
        sleep 1.5
        clear
        #si queda 1 sola bala y sabe que es real, te dispara
        #por ahora, simplemente elige al azar 50/50

        #ahora usa probabilidad, sabe contar
        if [ $reales_restantes -gt $seguras_restantes ]; then
            #Si hay más rojas, te dispara
            disparar "DEALER" "JUGADOR"
            turno_dealer=false
        elif [ $seguras_restantes -gt $reales_restantes ]; then
            #Si hay más azules, se dispara
            disparar "DEALER" "DEALER"
            if [ $? -eq 1 ]; then
                turno_dealer=false #si era real XD
            fi
        else
            #50/50
            eleccion=$(( RANDOM % 2 ))
            if [ $eleccion -eq 0 ]; then
                disparar "DEALER" "JUGADOR"
                turno_dealer=false
            else
                disparar "DEALER" "DEALER"
                if [ $? -eq 1 ]; then
                    turno_dealer=false
                fi
            fi
        fi
        clear
    done
done

# --- Fin de la partida ---
clear
echo -e "\n========================================"
if [ $vidas_jugador -le 0 ]; then
    echo -e "  ${ROJO}DERROTA${RESET}"
else
    echo -e "  ${VERDE}VICTORIA${RESET}"
fi
echo -e "========================================\n"
