#!/usr/bin/env bash

# Cyber-Breach Hack-RPG (TUI Edition)
# A cyberpunk hacking RPG with terminal interface
# Pure bash implementation

set -euo pipefail

# ============================================================================
# ANSI COLOR CODES & TUI UTILITIES
# ============================================================================

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_MAGENTA="\033[35m"
C_CYAN="\033[36m"
C_WHITE="\033[37m"
C_BRIGHT_RED="\033[91m"
C_BRIGHT_GREEN="\033[92m"
C_BRIGHT_YELLOW="\033[93m"
C_BRIGHT_BLUE="\033[94m"
C_BRIGHT_MAGENTA="\033[95m"
C_BRIGHT_CYAN="\033[96m"

# Background colors
BG_BLACK="\033[40m"
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_BLUE="\033[44m"
BG_CYAN="\033[46m"

# Cursor control
hide_cursor() { printf "\033[?25l"; }
show_cursor() { printf "\033[?25h"; }
clear_screen() { printf "\033[2J\033[H"; }
move_cursor() { printf "\033[${1};${2}H"; }
save_cursor() { printf "\033[s"; }
restore_cursor() { printf "\033[u"; }

# ============================================================================
# GAME STATE VARIABLES
# ============================================================================

# Player stats
PLAYER_NAME="N3WB13"
PLAYER_CREDITS=500
PLAYER_LEVEL=1
PLAYER_XP=0
PLAYER_XP_NEEDED=100

# Rig stats (hardware)
RIG_CPU=1        # Processing power (affects hack speed)
RIG_RAM=1        # Memory (affects simultaneous operations)
RIG_FIREWALL=1   # Defense (affects trace resistance)
RIG_BANDWIDTH=1  # Network speed (affects data transfer)

# Software/Skills
SKILL_CRACK=1    # Password cracking
SKILL_EXPLOIT=1  # Exploit finding
SKILL_STEALTH=1  # Trace evasion
SKILL_DECRYPT=1  # Decryption

# Inventory
declare -A INVENTORY=(
    [icebreaker]=0
    [trojan]=0
    [rootkit]=0
    [dataminer]=0
)

# Contract system
CURRENT_CONTRACT=""
CONTRACT_DIFFICULTY=0
CONTRACTS_COMPLETED=0

# Game state
GAME_RUNNING=true
TRACE_LEVEL=0
MAX_TRACE=100

# Contract database (name|difficulty|payout|xp|description)
declare -a CONTRACTS=(
    "LOCAL_SHOP|1|200|50|Hack a local convenience store's terminal"
    "CORP_EMAIL|2|500|100|Breach a small corp's email server"
    "BANK_ATM|3|1000|200|Compromise an ATM network node"
    "SECURITY_FIRM|4|2000|400|Infiltrate a security company database"
    "DATABANK|5|4000|800|Extract data from a corporate databank"
    "MEGACORP_HR|6|8000|1600|Breach MegaCorp HR records"
    "MILITARY_SUB|7|15000|3000|Access military subnet (DANGEROUS)"
    "BLACKSITE|8|30000|6000|Infiltrate classified black site"
    "AI_CORE|9|60000|12000|Hack rogue AI core matrix"
    "GLOBAL_NET|10|100000|25000|Take down Global Network Hub"
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

random() {
    local min=$1
    local max=$2
    echo $(( min + RANDOM % (max - min + 1) ))
}

print_at() {
    local row=$1
    local col=$2
    shift 2
    move_cursor "$row" "$col"
    echo -ne "$*"
}

draw_box() {
    local row=$1
    local col=$2
    local width=$3
    local height=$4
    local title=$5
    
    # Top border
    move_cursor "$row" "$col"
    echo -ne "${C_CYAN}╔"
    for ((i=0; i<width-2; i++)); do echo -ne "═"; done
    echo -ne "╗${C_RESET}"
    
    # Title
    if [[ -n "$title" ]]; then
        local title_pos=$(( col + (width - ${#title}) / 2 ))
        move_cursor "$row" "$title_pos"
        echo -ne "${C_BRIGHT_CYAN}${C_BOLD}$title${C_RESET}"
    fi
    
    # Sides
    for ((i=1; i<height-1; i++)); do
        move_cursor $((row + i)) "$col"
        echo -ne "${C_CYAN}║${C_RESET}"
        move_cursor $((row + i)) $((col + width - 1))
        echo -ne "${C_CYAN}║${C_RESET}"
    done
    
    # Bottom border
    move_cursor $((row + height - 1)) "$col"
    echo -ne "${C_CYAN}╚"
    for ((i=0; i<width-2; i++)); do echo -ne "═"; done
    echo -ne "╝${C_RESET}"
}

progress_bar() {
    local current=$1
    local max=$2
    local width=$3
    local filled=$(( current * width / max ))
    
    echo -ne "${C_BRIGHT_BLUE}["
    for ((i=0; i<width; i++)); do
        if ((i < filled)); then
            echo -ne "${C_BRIGHT_GREEN}█${C_BRIGHT_BLUE}"
        else
            echo -ne "${C_DIM}░${C_BRIGHT_BLUE}"
        fi
    done
    echo -ne "]${C_RESET}"
}

animate_text() {
    local text="$1"
    local delay=${2:-0.03}
    
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
}

level_up_check() {
    while ((PLAYER_XP >= PLAYER_XP_NEEDED)); do
        PLAYER_XP=$((PLAYER_XP - PLAYER_XP_NEEDED))
        ((PLAYER_LEVEL++))
        PLAYER_XP_NEEDED=$((PLAYER_XP_NEEDED + 50))
        
        clear_screen
        draw_box 10 30 40 8 "LEVEL UP!"
        print_at 12 35 "${C_BRIGHT_YELLOW}LEVEL ${PLAYER_LEVEL} ACHIEVED!${C_RESET}"
        print_at 14 35 "${C_GREEN}+1 Skill Point Available${C_RESET}"
        print_at 16 35 "${C_CYAN}Press any key...${C_RESET}"
        read -n 1 -s
    done
}

# ============================================================================
# MAIN MENU & HUD
# ============================================================================

draw_main_hud() {
    clear_screen
    
    # Header
    print_at 1 1 "${C_BRIGHT_CYAN}${C_BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    print_at 2 1 "║"
    print_at 2 3 "    ▄████▄▓██   ██▓ ▄▄▄▄   ▓█████  ██▀███      ▄▄▄▄    ██▀███  ▓█████ ▄▄▄      "
    print_at 2 79 "║"
    print_at 3 1 "║"
    print_at 3 3 "   ▒██▀ ▀█ ▒██  ██▒▓█████▄ ▓█   ▀ ▓██ ▒ ██▒   ▓█████▄ ▓██ ▒ ██▒▓█   ▀▒████▄    "
    print_at 3 79 "║"
    print_at 4 1 "║"
    print_at 4 3 "   ▒▓█    ▄ ▒██ ██░▒██▒ ▄██▒███   ▓██ ░▄█ ▒   ▒██▒ ▄██▓██ ░▄█ ▒▒███  ▒██  ▀█▄  "
    print_at 4 79 "║"
    print_at 5 1 "║${C_RESET}${C_CYAN}"
    print_at 5 40 "THE MATRIX AWAITS..."
    print_at 5 79 "${C_BRIGHT_CYAN}${C_BOLD}║"
    print_at 6 1 "╚═══════════════════════════════════════════════════════════════════════════════╝${C_RESET}"
    
    # Player info bar
    print_at 8 2 "${C_BRIGHT_GREEN}> USER: ${C_WHITE}${PLAYER_NAME}${C_RESET}"
    print_at 8 25 "${C_YELLOW}CREDITS: ${C_BRIGHT_YELLOW}¢${PLAYER_CREDITS}${C_RESET}"
    print_at 8 50 "${C_MAGENTA}LVL: ${C_BRIGHT_MAGENTA}${PLAYER_LEVEL}${C_RESET}"
    print_at 8 62 "${C_CYAN}XP: ${C_RESET}"
    progress_bar "$PLAYER_XP" "$PLAYER_XP_NEEDED" 15
    
    echo ""
}

main_menu() {
    while true; do
        draw_main_hud
        
        draw_box 10 5 35 15 "MAIN TERMINAL"
        
        print_at 12 8 "${C_BRIGHT_GREEN}1.${C_WHITE} CONTRACT BOARD${C_RESET}"
        print_at 13 8 "${C_BRIGHT_GREEN}2.${C_WHITE} UPGRADE RIG${C_RESET}"
        print_at 14 8 "${C_BRIGHT_GREEN}3.${C_WHITE} SKILL TREE${C_RESET}"
        print_at 15 8 "${C_BRIGHT_GREEN}4.${C_WHITE} INVENTORY${C_RESET}"
        print_at 16 8 "${C_BRIGHT_GREEN}5.${C_WHITE} STATUS${C_RESET}"
        print_at 17 8 "${C_BRIGHT_GREEN}6.${C_WHITE} SAVE & QUIT${C_RESET}"
        
        # System info panel
        draw_box 10 42 38 15 "RIG STATUS"
        print_at 12 45 "${C_CYAN}CPU:${C_RESET}       Lvl ${RIG_CPU}"
        print_at 13 45 "${C_CYAN}RAM:${C_RESET}       Lvl ${RIG_RAM}"
        print_at 14 45 "${C_CYAN}FIREWALL:${C_RESET}  Lvl ${RIG_FIREWALL}"
        print_at 15 45 "${C_CYAN}BANDWIDTH:${C_RESET} Lvl ${RIG_BANDWIDTH}"
        print_at 17 45 "${C_GREEN}Contracts:${C_RESET} ${CONTRACTS_COMPLETED}"
        print_at 18 45 "${C_YELLOW}Rep Level:${C_RESET} ${PLAYER_LEVEL}"
        
        print_at 26 2 "${C_DIM}> ${C_RESET}"
        read -n 1 choice
        
        case $choice in
            1) contract_board ;;
            2) upgrade_rig ;;
            3) skill_tree ;;
            4) show_inventory ;;
            5) show_status ;;
            6) 
                clear_screen
                show_cursor
                echo -e "${C_BRIGHT_CYAN}Disconnecting from the matrix...${C_RESET}"
                sleep 1
                exit 0
                ;;
        esac
    done
}

# ============================================================================
# CONTRACT BOARD
# ============================================================================

contract_board() {
    while true; do
        draw_main_hud
        draw_box 10 2 76 14 "AVAILABLE CONTRACTS"
        
        local row=12
        local index=0
        
        for contract in "${CONTRACTS[@]}"; do
            IFS='|' read -r name diff payout xp desc <<< "$contract"
            
            if ((diff <= PLAYER_LEVEL + 2)); then
                ((index++))
                
                local color="${C_GREEN}"
                if ((diff > PLAYER_LEVEL + 1)); then
                    color="${C_RED}"
                elif ((diff > PLAYER_LEVEL)); then
                    color="${C_YELLOW}"
                fi
                
                print_at "$row" 5 "${C_BRIGHT_GREEN}${index}.${C_RESET} ${color}[Lvl ${diff}]${C_RESET} ${C_WHITE}${name}${C_RESET}"
                print_at "$row" 45 "${C_YELLOW}¢${payout}${C_RESET} ${C_CYAN}+${xp}XP${C_RESET}"
                ((row++))
            fi
            
            if ((row >= 23)); then break; fi
        done
        
        print_at 25 2 "${C_DIM}Select contract (1-${index}) or [B]ack:${C_RESET} "
        read -n 1 choice
        
        if [[ "$choice" =~ [Bb] ]]; then
            return
        elif [[ "$choice" =~ [1-9] ]] && ((choice <= index)); then
            local selected_contract="${CONTRACTS[$((choice - 1))]}"
            IFS='|' read -r name diff payout xp desc <<< "$selected_contract"
            show_contract_details "$name" "$diff" "$payout" "$xp" "$desc"
            return
        fi
    done
}

show_contract_details() {
    local name=$1
    local diff=$2
    local payout=$3
    local xp=$4
    local desc=$5
    
    clear_screen
    draw_main_hud
    
    draw_box 10 10 60 12 "CONTRACT BRIEFING"
    
    print_at 12 13 "${C_BRIGHT_CYAN}TARGET:${C_RESET} ${C_WHITE}${name}${C_RESET}"
    print_at 13 13 "${C_BRIGHT_CYAN}DIFFICULTY:${C_RESET} ${C_YELLOW}Level ${diff}${C_RESET}"
    print_at 14 13 "${C_BRIGHT_CYAN}PAYOUT:${C_RESET} ${C_BRIGHT_YELLOW}¢${payout}${C_RESET}"
    print_at 15 13 "${C_BRIGHT_CYAN}EXPERIENCE:${C_RESET} ${C_BRIGHT_MAGENTA}+${xp} XP${C_RESET}"
    print_at 17 13 "${C_DIM}${desc}${C_RESET}"
    
    print_at 20 13 "${C_GREEN}[A]ccept${C_RESET} ${C_RED}[D]ecline${C_RESET}"
    print_at 21 13 "${C_DIM}> ${C_RESET}"
    
    read -n 1 choice
    
    if [[ "$choice" =~ [Aa] ]]; then
        start_hack "$name" "$diff" "$payout" "$xp"
    fi
}

# ============================================================================
# HACKING MINI-GAMES
# ============================================================================

start_hack() {
    local target=$1
    local difficulty=$2
    local payout=$3
    local xp=$4
    
    TRACE_LEVEL=0
    
    clear_screen
    draw_main_hud
    
    draw_box 10 2 76 14 "INITIATING HACK: ${target}"
    
    print_at 12 5 "${C_BRIGHT_GREEN}> Establishing connection...${C_RESET}"
    sleep 0.5
    print_at 13 5 "${C_BRIGHT_GREEN}> Probing network defenses...${C_RESET}"
    sleep 0.5
    print_at 14 5 "${C_BRIGHT_GREEN}> Searching for vulnerabilities...${C_RESET}"
    sleep 0.5
    
    # Choose random minigame
    local game_type=$(random 1 3)
    
    case $game_type in
        1) password_crack_game "$target" "$difficulty" "$payout" "$xp" ;;
        2) port_scan_game "$target" "$difficulty" "$payout" "$xp" ;;
        3) encryption_break_game "$target" "$difficulty" "$payout" "$xp" ;;
    esac
}

password_crack_game() {
    local target=$1
    local difficulty=$2
    local payout=$3
    local xp=$4
    
    clear_screen
    draw_main_hud
    
    draw_box 10 2 76 14 "PASSWORD CRACKER v2.4"
    
    print_at 12 5 "${C_YELLOW}Analyzing password hash...${C_RESET}"
    sleep 1
    
    # Generate random password
    local password_length=$((4 + difficulty))
    local charset="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local password=""
    
    for ((i=0; i<password_length; i++)); do
        local idx=$(random 0 $((${#charset} - 1)))
        password+="${charset:$idx:1}"
    done
    
    print_at 14 5 "${C_CYAN}Password length: ${password_length} characters${C_RESET}"
    print_at 15 5 "${C_CYAN}Attempts remaining: ${C_BRIGHT_GREEN}$((5 + RIG_CPU))${C_RESET}"
    
    local attempts=$((5 + RIG_CPU))
    local guess_row=17
    
    for ((attempt=1; attempt<=attempts; attempt++)); do
        TRACE_LEVEL=$((TRACE_LEVEL + 10 + difficulty * 2))
        
        print_at 25 2 "${C_RED}TRACE: ${C_RESET}"
        progress_bar "$TRACE_LEVEL" "$MAX_TRACE" 30
        
        if ((TRACE_LEVEL >= MAX_TRACE)); then
            hack_failed "TRACE COMPLETE - CONNECTION TERMINATED"
            return
        fi
        
        print_at "$guess_row" 5 "${C_DIM}Attempt ${attempt}/${attempts}:${C_RESET} "
        read -r guess
        
        guess=$(echo "$guess" | tr '[:lower:]' '[:upper:]')
        
        if [[ "$guess" == "$password" ]]; then
            hack_success "$payout" "$xp"
            return
        else
            # Give feedback
            local correct=0
            for ((i=0; i<${#guess}; i++)); do
                if [[ "${guess:$i:1}" == "${password:$i:1}" ]]; then
                    ((correct++))
                fi
            done
            print_at "$guess_row" 40 "${C_YELLOW}Correct positions: ${correct}${C_RESET}"
            ((guess_row++))
        fi
    done
    
    hack_failed "MAXIMUM ATTEMPTS EXCEEDED"
}

port_scan_game() {
    local target=$1
    local difficulty=$2
    local payout=$3
    local xp=$4
    
    clear_screen
    draw_main_hud
    
    draw_box 10 2 76 14 "PORT SCANNER v3.1"
    
    print_at 12 5 "${C_YELLOW}Scanning for open ports...${C_RESET}"
    
    # Generate ports
    local num_ports=$((5 + difficulty))
    local vulnerable_port=$(random 1 num_ports)
    
    local row=14
    for ((i=1; i<=num_ports; i++)); do
        sleep 0.3
        local port=$((8000 + RANDOM % 2000))
        local status="CLOSED"
        local color="${C_RED}"
        
        if ((i == vulnerable_port)); then
            status="OPEN"
            color="${C_BRIGHT_GREEN}"
        fi
        
        print_at "$row" 5 "${C_CYAN}Port ${port}:${C_RESET} ${color}${status}${C_RESET}"
        ((row++))
        
        TRACE_LEVEL=$((TRACE_LEVEL + 8))
    done
    
    print_at 25 2 "${C_RED}TRACE: ${C_RESET}"
    progress_bar "$TRACE_LEVEL" "$MAX_TRACE" 30
    
    sleep 1
    print_at $((row + 1)) 5 "${C_BRIGHT_GREEN}Exploiting open port...${C_RESET}"
    sleep 1
    
    if ((TRACE_LEVEL >= MAX_TRACE)); then
        hack_failed "DETECTED BY IDS"
        return
    fi
    
    # Quick reflex test
    print_at $((row + 2)) 5 "${C_BRIGHT_YELLOW}FIREWALL DETECTED! Press SPACE when the bar is in the green zone!${C_RESET}"
    sleep 1
    
    local bar_pos=0
    local success_zone=$((15 + RIG_FIREWALL * 3))
    local caught=0
    
    for ((i=0; i<50; i++)); do
        bar_pos=$((i % 40))
        
        print_at $((row + 4)) 5 "["
        for ((j=0; j<40; j++)); do
            if ((j >= success_zone - 3 && j <= success_zone + 3)); then
                echo -ne "${C_GREEN}█${C_RESET}"
            elif ((j == bar_pos)); then
                echo -ne "${C_BRIGHT_YELLOW}▐${C_RESET}"
            else
                echo -ne "${C_DIM}░${C_RESET}"
            fi
        done
        echo -ne "]"
        
        read -t 0.1 -n 1 key && {
            if [[ "$key" == " " ]]; then
                if ((bar_pos >= success_zone - 3 && bar_pos <= success_zone + 3)); then
                    hack_success "$payout" "$xp"
                    return
                else
                    caught=1
                    break
                fi
            fi
        } || true
    done
    
    hack_failed "TIMING FAILURE - FIREWALL ACTIVATED"
}

encryption_break_game() {
    local target=$1
    local difficulty=$2
    local payout=$3
    local xp=$4
    
    clear_screen
    draw_main_hud
    
    draw_box 10 2 76 14 "ENCRYPTION BREAKER v1.9"
    
    print_at 12 5 "${C_YELLOW}Analyzing encryption algorithm...${C_RESET}"
    sleep 1
    
    # Memory pattern game
    local pattern_length=$((3 + difficulty))
    local pattern=""
    local symbols=("◆" "●" "■" "▲" "★")
    
    for ((i=0; i<pattern_length; i++)); do
        pattern+="${symbols[$(random 0 4)]}"
    done
    
    print_at 14 5 "${C_CYAN}Memorize the encryption key:${C_RESET}"
    print_at 16 5 "${C_BRIGHT_YELLOW}${pattern}${C_RESET}"
    
    sleep $((2 + pattern_length / 2))
    
    # Clear pattern
    print_at 16 5 "                                        "
    
    print_at 18 5 "${C_CYAN}Enter the pattern (1=◆ 2=● 3=■ 4=▲ 5=★):${C_RESET}"
    print_at 19 5 "${C_DIM}> ${C_RESET}"
    
    read -r input
    
    # Convert input to symbols
    local user_pattern=""
    for ((i=0; i<${#input}; i++)); do
        local digit="${input:$i:1}"
        if [[ "$digit" =~ [1-5] ]]; then
            user_pattern+="${symbols[$((digit - 1))]}"
        fi
    done
    
    TRACE_LEVEL=$((TRACE_LEVEL + 20))
    
    if [[ "$user_pattern" == "$pattern" ]]; then
        hack_success "$payout" "$xp"
    else
        hack_failed "DECRYPTION FAILED"
    fi
}

hack_success() {
    local payout=$1
    local xp=$2
    
    clear_screen
    draw_main_hud
    
    draw_box 12 20 40 10 "HACK SUCCESSFUL"
    
    print_at 14 25 "${C_BRIGHT_GREEN}ACCESS GRANTED${C_RESET}"
    print_at 16 25 "${C_YELLOW}Credits: +¢${payout}${C_RESET}"
    print_at 17 25 "${C_MAGENTA}XP: +${xp}${C_RESET}"
    
    PLAYER_CREDITS=$((PLAYER_CREDITS + payout))
    PLAYER_XP=$((PLAYER_XP + xp))
    ((CONTRACTS_COMPLETED++))
    
    print_at 20 25 "${C_DIM}Press any key...${C_RESET}"
    read -n 1 -s
    
    level_up_check
}

hack_failed() {
    local reason=$1
    
    clear_screen
    draw_main_hud
    
    draw_box 12 20 40 8 "HACK FAILED"
    
    print_at 14 25 "${C_BRIGHT_RED}ACCESS DENIED${C_RESET}"
    print_at 16 25 "${C_RED}${reason}${C_RESET}"
    
    print_at 19 25 "${C_DIM}Press any key...${C_RESET}"
    read -n 1 -s
}

# ============================================================================
# UPGRADE SYSTEM
# ============================================================================

upgrade_rig() {
    while true; do
        draw_main_hud
        draw_box 10 5 70 12 "RIG UPGRADES"
        
        local cpu_cost=$((RIG_CPU * 500))
        local ram_cost=$((RIG_RAM * 400))
        local fw_cost=$((RIG_FIREWALL * 600))
        local bw_cost=$((RIG_BANDWIDTH * 450))
        
        print_at 12 8 "${C_BRIGHT_GREEN}1.${C_RESET} CPU Lvl ${RIG_CPU} → ${RIG_CPU+1} ${C_YELLOW}(¢${cpu_cost})${C_RESET} - Faster hacking"
        print_at 13 8 "${C_BRIGHT_GREEN}2.${C_RESET} RAM Lvl ${RIG_RAM} → ${RIG_RAM+1} ${C_YELLOW}(¢${ram_cost})${C_RESET} - More attempts"
        print_at 14 8 "${C_BRIGHT_GREEN}3.${C_RESET} Firewall Lvl ${RIG_FIREWALL} → ${RIG_FIREWALL+1} ${C_YELLOW}(¢${fw_cost})${C_RESET} - Better defense"
        print_at 15 8 "${C_BRIGHT_GREEN}4.${C_RESET} Bandwidth Lvl ${RIG_BANDWIDTH} → ${RIG_BANDWIDTH+1} ${C_YELLOW}(¢${bw_cost})${C_RESET} - Faster transfers"
        
        print_at 17 8 "${C_CYAN}Current Credits: ${C_BRIGHT_YELLOW}¢${PLAYER_CREDITS}${C_RESET}"
        
        print_at 20 8 "${C_DIM}Select upgrade (1-4) or [B]ack:${C_RESET} "
        read -n 1 choice
        
        case $choice in
            1)
                if ((PLAYER_CREDITS >= cpu_cost)); then
                    PLAYER_CREDITS=$((PLAYER_CREDITS - cpu_cost))
                    ((RIG_CPU++))
                    show_upgrade_message "CPU upgraded!"
                else
                    show_upgrade_message "Insufficient credits!"
                fi
                ;;
            2)
                if ((PLAYER_CREDITS >= ram_cost)); then
                    PLAYER_CREDITS=$((PLAYER_CREDITS - ram_cost))
                    ((RIG_RAM++))
                    show_upgrade_message "RAM upgraded!"
                else
                    show_upgrade_message "Insufficient credits!"
                fi
                ;;
            3)
                if ((PLAYER_CREDITS >= fw_cost)); then
                    PLAYER_CREDITS=$((PLAYER_CREDITS - fw_cost))
                    ((RIG_FIREWALL++))
                    show_upgrade_message "Firewall upgraded!"
                else
                    show_upgrade_message "Insufficient credits!"
                fi
                ;;
            4)
                if ((PLAYER_CREDITS >= bw_cost)); then
                    PLAYER_CREDITS=$((PLAYER_CREDITS - bw_cost))
                    ((RIG_BANDWIDTH++))
                    show_upgrade_message "Bandwidth upgraded!"
                else
                    show_upgrade_message "Insufficient credits!"
                fi
                ;;
            [Bb]) return ;;
        esac
    done
}

show_upgrade_message() {
    local msg=$1
    print_at 22 8 "${C_BRIGHT_CYAN}${msg}${C_RESET}"
    sleep 1
}

# ============================================================================
# SKILL TREE
# ============================================================================

skill_tree() {
    while true; do
        draw_main_hud
        draw_box 10 5 70 12 "SKILL TREE"
        
        local skill_points=$((PLAYER_LEVEL - (SKILL_CRACK + SKILL_EXPLOIT + SKILL_STEALTH + SKILL_DECRYPT - 4)))
        
        print_at 12 8 "${C_CYAN}Available Skill Points: ${C_BRIGHT_CYAN}${skill_points}${C_RESET}"
        print_at 14 8 "${C_BRIGHT_GREEN}1.${C_RESET} Password Cracking: Lvl ${SKILL_CRACK} - Better password hints"
        print_at 15 8 "${C_BRIGHT_GREEN}2.${C_RESET} Exploit Finding: Lvl ${SKILL_EXPLOIT} - Find vulnerabilities faster"
        print_at 16 8 "${C_BRIGHT_GREEN}3.${C_RESET} Stealth: Lvl ${SKILL_STEALTH} - Slower trace buildup"
        print_at 17 8 "${C_BRIGHT_GREEN}4.${C_RESET} Decryption: Lvl ${SKILL_DECRYPT} - Easier encryption breaking"
        
        print_at 20 8 "${C_DIM}Select skill (1-4) or [B]ack:${C_RESET} "
        read -n 1 choice
        
        if ((skill_points <= 0)) && [[ ! "$choice" =~ [Bb] ]]; then
            print_at 22 8 "${C_RED}No skill points available!${C_RESET}"
            sleep 1
            continue
        fi
        
        case $choice in
            1) ((SKILL_CRACK++)); show_upgrade_message "Cracking skill improved!" ;;
            2) ((SKILL_EXPLOIT++)); show_upgrade_message "Exploit skill improved!" ;;
            3) ((SKILL_STEALTH++)); show_upgrade_message "Stealth skill improved!" ;;
            4) ((SKILL_DECRYPT++)); show_upgrade_message "Decryption skill improved!" ;;
            [Bb]) return ;;
        esac
    done
}

# ============================================================================
# INVENTORY & STATUS
# ============================================================================

show_inventory() {
    draw_main_hud
    draw_box 10 5 70 12 "INVENTORY"
    
    print_at 12 8 "${C_CYAN}Software Tools:${C_RESET}"
    print_at 14 8 "Icebreaker: ${INVENTORY[icebreaker]}"
    print_at 15 8 "Trojan: ${INVENTORY[trojan]}"
    print_at 16 8 "Rootkit: ${INVENTORY[rootkit]}"
    print_at 17 8 "Data Miner: ${INVENTORY[dataminer]}"
    
    print_at 20 8 "${C_DIM}Press any key to return...${C_RESET}"
    read -n 1 -s
}

show_status() {
    draw_main_hud
    draw_box 10 5 70 14 "SYSTEM STATUS"
    
    print_at 12 8 "${C_BRIGHT_CYAN}═══ IDENTITY ═══${C_RESET}"
    print_at 13 8 "Handle: ${C_WHITE}${PLAYER_NAME}${C_RESET}"
    print_at 14 8 "Level: ${C_BRIGHT_MAGENTA}${PLAYER_LEVEL}${C_RESET}"
    print_at 15 8 "Reputation: ${CONTRACTS_COMPLETED} jobs completed"
    
    print_at 17 8 "${C_BRIGHT_CYAN}═══ HARDWARE ═══${C_RESET}"
    print_at 18 8 "CPU: Lvl ${RIG_CPU} | RAM: Lvl ${RIG_RAM}"
    print_at 19 8 "Firewall: Lvl ${RIG_FIREWALL} | Bandwidth: Lvl ${RIG_BANDWIDTH}"
    
    print_at 21 8 "${C_BRIGHT_CYAN}═══ SOFTWARE ═══${C_RESET}"
    print_at 22 8 "Cracking: Lvl ${SKILL_CRACK} | Exploits: Lvl ${SKILL_EXPLOIT}"
    print_at 23 8 "Stealth: Lvl ${SKILL_STEALTH} | Decryption: Lvl ${SKILL_DECRYPT}"
    
    print_at 26 8 "${C_DIM}Press any key to return...${C_RESET}"
    read -n 1 -s
}

# ============================================================================
# INTRO SEQUENCE
# ============================================================================

intro_sequence() {
    clear_screen
    hide_cursor
    
    print_at 10 25 "${C_BRIGHT_CYAN}${C_BOLD}"
    animate_text "BOOTING CYBERDECK..." 0.05
    echo ""
    
    sleep 0.5
    
    print_at 12 20 "${C_GREEN}"
    animate_text "Initializing neural interface..." 0.03
    sleep 0.5
    
    print_at 13 20 "${C_GREEN}"
    animate_text "Loading ICE breaker protocols..." 0.03
    sleep 0.5
    
    print_at 14 20 "${C_GREEN}"
    animate_text "Connecting to darknet nodes..." 0.03
    sleep 0.5
    
    print_at 16 20 "${C_BRIGHT_YELLOW}"
    animate_text "SYSTEM READY" 0.05
    echo -e "${C_RESET}"
    
    sleep 1
    
    clear_screen
    
    draw_box 8 15 50 12 "WELCOME TO THE MATRIX"
    
    print_at 11 18 "${C_CYAN}You are a freelance hacker in the${C_RESET}"
    print_at 12 18 "${C_CYAN}sprawling neon-lit megacity of 2087.${C_RESET}"
    print_at 14 18 "${C_WHITE}Your mission: Complete contracts,${C_RESET}"
    print_at 15 18 "${C_WHITE}upgrade your rig, and become a${C_RESET}"
    print_at 16 18 "${C_WHITE}legend in the digital underground.${C_RESET}"
    
    print_at 19 18 "${C_DIM}Press any key to jack in...${C_RESET}"
    
    read -n 1 -s
}

# ============================================================================
# CLEANUP & SIGNAL HANDLING
# ============================================================================

cleanup() {
    show_cursor
    clear_screen
    echo -e "${C_BRIGHT_CYAN}Connection terminated. Stay safe out there, runner.${C_RESET}"
}

trap cleanup EXIT
trap 'GAME_RUNNING=false; cleanup; exit' INT TERM

# ============================================================================
# MAIN GAME LOOP
# ============================================================================

main() {
    hide_cursor
    intro_sequence
    main_menu
}

# Start the game
main
