#!/bin/bash

LOCATION="$(dirname "$(realpath "$0")")"
LASTTERMINALCOLOR="$LOCATION/terminalcolor.last"


. "${LOCATION}/terminalcolor.alias"

active=0
if [[ -e $LASTTERMINALCOLOR ]]; then
    active=$(( $(cat "${LASTTERMINALCOLOR}") + 0))
fi

# Load the color scheme as textcolor-backgroundcolor string pairs
#
colorscheme=( $(cat "$LOCATION/terminalcolor.colorscheme") )


# With just 10 titlelines the script became notably slow. Rather than fixing the
# code the titlelines are precached at startup in the following dictionary.
#
declare -A titlecache

splitcolors() {
    local -n textcol="$1" backcol="$2"
    textcol=$(echo "$3" | cut -d - -f 1)
    backcol=$(echo "$3" | cut -d - -f 2)
}


# Based on https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu/673436#673436
#
multiselect() {
    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()   { printf "$ESC[?25h"; }
    cursor_blink_off()  { printf "$ESC[?25l"; }
    cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
    get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    
    print_active() {
        text="${titlecache[$1]}"
        printf "$ESC[7m    ${text}    \e[0m"; }

    print_inactive() { 
        text="${titlecache[$1]}"
        printf "    \e[0m${text}\e[0m        "; }

    local -n options=$1

    for ((i=0; i<${#options[@]}; i++)); do
        printf "\n"
    done

    # determine current screen position for overwriting the options
    local lastrow=$(get_cursor_row)
    local startrow=$(($lastrow - ${#options[@]}))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    key_input() {
        local key
        IFS= read -rsn1 key 2>/dev/null >&2
        if [[ $key = $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key = [A || $key = k ]]; then echo up;    fi;
            if [[ $key = [B || $key = j ]]; then echo down;  fi;
        fi 
        if [[ $key = ""      ]]; then echo enter; fi;
        if [[ $key = $'\x20' ]]; then echo space; fi;
        if [[ $key = "k" ]]; then echo up; fi;
        if [[ $key = "j" ]]; then echo down; fi;
    }

    print_options() {
        # print options by overwriting the last lines
        local idx=0
        for option in "${options[@]}"; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq "$1" ]; then
                print_active "$option"
            else
                print_inactive "$option"
            fi
            ((idx++))
        done
        printf "\n"
    }

    while true; do
        print_options $active

        # user key control
        case `key_input` in
            enter)  print_options -1; break;;
            
            up)     ((active--));
                    if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi
                    splitcolors textcolor backcolor "${options[active]}"
                    terminalcolor "${textcolor}" "${backcolor}";;
                    
            down)   ((active++));
                    if [ $active -ge ${#options[@]} ]; then active=0; fi
                    splitcolors textcolor backcolor "${options[active]}"
                    terminalcolor "${textcolor}" "${backcolor}";;
        esac
    done

    # cursor position back to normal
    cursor_to "$lastrow"
    cursor_blink_on
    
    echo "${active}" > "${LASTTERMINALCOLOR}"
}


# Fill the menu title-cache
#
for pair in "${colorscheme[@]}"; do
    splitcolors textcolor backcolor "$pair"
    title=$(printf %-29s "    ${textcolor} on ${backcolor}")
    text=$(colorprint "$textcolor" "$backcolor" "${title}")
    titlecache["$pair"]="${text}"
done

           
splitcolors textcolor backcolor "${colorscheme[active]}"
terminalcolor "${textcolor}" "${backcolor}"

multiselect colorscheme

# Something above clears e.g. a bold attribute from last call to terminalcolor ?!?
# So just do a refresh before exiting
# 
splitcolors textcolor backcolor "${colorscheme[active]}"
terminalcolor "${textcolor}" "${backcolor}"
