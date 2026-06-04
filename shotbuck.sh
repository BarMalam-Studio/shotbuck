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

###INVENTARIO###
OBJETOS=("Lupa" "Inversor" "Cerveza")
inv_jugador=()
inv_dealer=()
dealer_sabe_bala="" # Memoria temporal del Dealer al usar Lupa

###CONTROL CARTUCHSO###
cargar_escopeta() {
    total_balas=$(( RANDOM % 7 + 2 )) #2-8

    #1 real min, no todo de un solo tipo
    balas_reales=$(( RANDOM % (total_balas - 1) + 1 ))
    balas_seguras=$(( total_balas - balas_reales ))

    #repartir objetos (máximo 8 en inventario)
    for ((k=0; k<2; k++)); do
        if [ ${#inv_jugador[@]} -lt 8 ]; then inv_jugador+=("${OBJETOS[$((RANDOM % 3))]}"); fi
        if [ ${#inv_dealer[@]} -lt 8 ]; then inv_dealer+=("${OBJETOS[$((RANDOM % 3))]}"); fi
    done

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

###LOGICA OBJETOS###
usar_objeto() {
    local usuario=$1
    local indice=$2
    local item=""

    if [ "$usuario" == "JUGADOR" ]; then
        item="${inv_jugador[$indice]}"
        unset 'inv_jugador[$indice]'
        inv_jugador=("${inv_jugador[@]}") #Re:indexar array
    else
        item="${inv_dealer[$indice]}"
        unset 'inv_dealer[$indice]'
        inv_dealer=("${inv_dealer[@]}")
    fi
    echo -e "\n* $usuario usa: ${AMARILLO}$item${RESET} *"
    sleep 1.5

    case "$item" in
        "Lupa")
            if [ "$usuario" == "JUGADOR" ]; then
                echo -e "Revisa recamara, el cartucho actual es: ${AMARILLO}${cargador[0]}${RESET}"
                sleep 2.5
            else
                dealer_sabe_bala="${cargador[0]}"
                echo -e "Muy interesante..." #robado del juego original
                sleep 2
            fi
            ;;
        "Inversor")
            if [ "${cargador[0]}" == "real" ]; then
                cargador[0]="segura"
                ((reales_restantes--))
                ((seguras_restantes++))
            else
                cargador[0]="real"
                ((seguras_restantes--))
                ((reales_restantes++))
            fi
            #update a la memoria del diler si usó el inversor tras una lupa
            if [ "$usuario" == "DEALER" ] && [ "$dealer_sabe_bala" != "" ]; then
                dealer_sabe_bala="${cargador[0]}"
            fi
            echo -e "Se ha invertido la polaridad del cartucho."
            sleep 2
            ;;
        "Cerveza")
            local descartada=${cargador[0]}
            cargador=("${cargador[@]:1}") 
            if [ "$descartada" == "real" ]; then
                ((reales_restantes--))
                echo -e "Se expulso un cartucho ${ROJO}REAL${RESET}."
            else
                ((seguras_restantes--))
                echo -e "Se expulso un cartucho ${AZUL}SEGURO${RESET}."
            fi
            if [ "$usuario" == "DEALER" ]; then dealer_sabe_bala=""; fi
            sleep 2.5
            ;;
    esac
}

###ESTADO###
mostrar_status() {
    echo -e "\n========================================"
    echo -e " JUGADOR: [${VERDE}$vidas_jugador/$MAX_VIDAS Vidas${RESET}]  |  DEALER: [${VERDE}$vidas_dealer/$MAX_VIDAS Vidas${RESET}]"
    echo -e " OBJETOS JUGADOR: ${AMARILLO}${inv_jugador[*]}${RESET}"
    echo -e " OBJETOS DEALER: ${AMARILLO}${inv_dealer[*]}${RESET}"
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
        echo "3) Usar Objeto"
        read -p "Selecciona una opción (1-3): " opcion
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
            3)
                if [ ${#inv_jugador[@]} -eq 0 ]; then
                    echo "No tienes objetos."
                    sleep 1.5
                    clear
                    continue
                fi
                echo "Selecciona un objeto para usar:"
                for i in "${!inv_jugador[@]}"; do
                    echo "$i) ${inv_jugador[$i]}"
                done
                read -p "Ingresa objeto (o presiona Enter para volver): " obj_idx
                if [[ "$obj_idx" =~ ^[0-9]+$ ]] && [ "$obj_idx" -lt "${#inv_jugador[@]}" ]; then
                    clear
                    usar_objeto "JUGADOR" "$obj_idx"
                else
                    echo "Acción cancelada"
                    sleep 1
                fi
                clear
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
    dealer_sabe_bala="" #amnesia al inicio de su turno
    while $turno_dealer && [ $vidas_jugador -gt 0 ] && [ $vidas_dealer -gt 0 ] && [ ${#cargador[@]} -gt 0 ]; do
        mostrar_status
        echo "Turno del Dealer... pensando..."
        sleep 2
        uso_objeto=false

        #si queda 1 sola bala y sabe que es real, te dispara
        #por ahora, simplemente elige al azar 50/50

        #ahora usa probabilidad, sabe contar
        #logica del diler para objetos
        if [ ${#inv_dealer[@]} -gt 0 ]; then
            #usa Lupa si no sabe que bala es
            for i in "${!inv_dealer[@]}"; do
                if [ "${inv_dealer[$i]}" == "Lupa" ] && [ "$dealer_sabe_bala" == "" ]; then
                    usar_objeto "DEALER" $i
                    uso_objeto=true
                    break
                fi
            done

            #si sabe que la bala es segura, usar inversor y dispara
            if [ "$uso_objeto" == false ] && [ "$dealer_sabe_bala" == "segura" ]; then
                for i in "${!inv_dealer[@]}"; do
                    if [ "${inv_dealer[$i]}" == "Inversor" ]; then
                        usar_objeto "DEALER" $i
                        uso_objeto=true
                        break
                    fi
                done
            fi

            #si hay mas seguras que reales y no sabe la bala, bebe cerveza
            if [ "$uso_objeto" == false ] && [ $seguras_restantes -gt $reales_restantes ] && [ "$dealer_sabe_bala" == "" ]; then
                for i in "${!inv_dealer[@]}"; do
                    if [ "${inv_dealer[$i]}" == "Cerveza" ]; then
                        usar_objeto "DEALER" $i
                        uso_objeto=true
                        break
                    fi
                done
            fi
        fi

        #si la recamara quedo vacia tras una cerveza, sale de su ciclo interior
        if [ ${#cargador[@]} -eq 0 ]; then continue; fi
        #si usoun objeto, el ciclo while repite para permitirle seguir actuando (disparar o usar ma)
        #si no uso un objeto, normal
        if [ "$uso_objeto" == false ]; then
            clear
            if [ "$dealer_sabe_bala" == "real" ]; then
                disparar "DEALER" "JUGADOR"
                turno_dealer=false
            elif [ "$dealer_sabe_bala" == "segura" ]; then
                disparar "DEALER" "DEALER"
                if [ $? -eq 1 ]; then turno_dealer=false; fi
            else
                #version anterior de logica solo para balas
                if [ $reales_restantes -gt $seguras_restantes ]; then
                    disparar "DEALER" "JUGADOR"
                    turno_dealer=false
                elif [ $seguras_restantes -gt $reales_restantes ]; then
                    disparar "DEALER" "DEALER"
                    if [ $? -eq 1 ]; then turno_dealer=false; fi
                else
                    eleccion=$(( RANDOM % 2 ))
                    if [ $eleccion -eq 0 ]; then
                        disparar "DEALER" "JUGADOR"
                        turno_dealer=false
                    else
                        disparar "DEALER" "DEALER"
                        if [ $? -eq 1 ]; then turno_dealer=false; fi
                    fi
                fi
            fi
            dealer_sabe_bala="" #amnesia memoria tras disparar
            clear #me olvide esto
        else
            clear #limpia pantalla
        fi
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

sleep 3
exit
