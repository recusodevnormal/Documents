#!/usr/bin/env bash
# =============================================================================
# CYBER-BREACH: HACK-RPG (TUI Edition)
# A cyberpunk hacking RPG in a single Bash script
# =============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# TERMINAL SETUP & CLEANUP
# =============================================================================

# Save terminal state
OLD_STTY=$(stty -g 2>/dev/null || echo "")
TERM_WIDTH=$(tput cols 2>/dev/null || echo "80")
TERM_HEIGHT=$(tput lines 2>/dev/null || echo "24")

cleanup() {
    tput rmcup 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    tput sgr0 2>/dev/null || true
    [[ -n "$OLD_STTY" ]] && stty "$OLD_STTY" 2>/dev/null || true
    echo ""
    echo ">>> JACK OUT COMPLETE. STAY FROSTY, RUNNER. <<<"
}
trap cleanup EXIT INT TERM

# Initialize alternate screen
tput smcup 2>/dev/null || true
tput civis 2>/dev/null || true
tput clear 2>/dev/null || true

# =============================================================================
# ANSI COLOR & STYLE CODES
# =============================================================================

# Reset
R="\e[0m"

# Regular colors
BLACK="\e[30m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"

# Bright colors
BBLACK="\e[90m"
BRED="\e[91m"
BGREEN="\e[92m"
BYELLOW="\e[93m"
BBLUE="\e[94m"
BMAGENTA="\e[95m"
BCYAN="\e[96m"
BWHITE="\e[97m"

# Background colors
BG_BLACK="\e[40m"
BG_RED="\e[41m"
BG_GREEN="\e[42m"
BG_YELLOW="\e[43m"
BG_BLUE="\e[44m"
BG_MAGENTA="\e[45m"
BG_CYAN="\e[46m"
BG_WHITE="\e[47m"
BG_BBLACK="\e[100m"

# Styles
BOLD="\e[1m"
DIM="\e[2m"
ITALIC="\e[3m"
UNDERLINE="\e[4m"
BLINK="\e[5m"
REVERSE="\e[7m"

# =============================================================================
# GAME STATE VARIABLES
# =============================================================================

# Player stats
PLAYER_NAME=""
PLAYER_CREDITS=500
PLAYER_REP=0
PLAYER_LEVEL=1
PLAYER_XP=0
PLAYER_XP_NEXT=100
PLAYER_HEAT=0          # Police/Corp attention level (0-100)
PLAYER_HEALTH=100
PLAYER_MAX_HEALTH=100

# Rig stats
RIG_CPU=1              # Processing power (affects minigame speed/difficulty)
RIG_RAM=1              # Memory (affects simultaneous operations)
RIG_STEALTH=1          # Reduces heat generation
RIG_ICE_BREAK=1        # ICE breaking power
RIG_FIREWALL=1         # Defense against counter-hacks
RIG_NET_TAP=1          # Network analysis (reveals more info)

# Upgrade costs (base, multiplied by current level)
declare -A UPGRADE_BASE_COST
UPGRADE_BASE_COST[CPU]=300
UPGRADE_BASE_COST[RAM]=250
UPGRADE_BASE_COST[STEALTH]=400
UPGRADE_BASE_COST[ICE_BREAK]=350
UPGRADE_BASE_COST[FIREWALL]=300
UPGRADE_BASE_COST[NET_TAP]=200

declare -A UPGRADE_MAX_LEVEL
UPGRADE_MAX_LEVEL[CPU]=5
UPGRADE_MAX_LEVEL[RAM]=5
UPGRADE_MAX_LEVEL[STEALTH]=5
UPGRADE_MAX_LEVEL[ICE_BREAK]=5
UPGRADE_MAX_LEVEL[FIREWALL]=5
UPGRADE_MAX_LEVEL[NET_TAP]=5

# Installed programs/tools
TOOL_PHANTOM=0         # Reduces heat by 20% per run
TOOL_BRUTEFORCE=0      # Auto-breaks one firewall layer
TOOL_DECRYPT=0         # Helps with cipher minigame
TOOL_TRACE_BLOCK=0     # Blocks one trace attempt
TOOL_OVERCLOCK=0       # Speeds up all minigames

TOOL_PHANTOM_COST=800
TOOL_BRUTEFORCE_COST=1200
TOOL_DECRYPT_COST=900
TOOL_TRACE_BLOCK_COST=1100
TOOL_OVERCLOCK_COST=1500

# Contract tracking
CONTRACTS_COMPLETED=0
CURRENT_CONTRACT=""
CURRENT_CONTRACT_DIFF=1
CURRENT_CONTRACT_PAY=0
CURRENT_CONTRACT_XP=0
CURRENT_CONTRACT_HEAT=0

# Game flags
GAME_RUNNING=1
LAST_MESSAGE=""
HACKED_CORPS=""  # Comma-separated list of hacked corps

# Log entries
declare -a HACK_LOG
HACK_LOG=()

# =============================================================================
# TUI UTILITY FUNCTIONS
# =============================================================================

# Move cursor to row, col (1-indexed)
move_to() {
    local row=$1 col=$2
    printf "\e[%d;%dH" "$row" "$col"
}

# Clear screen
clear_screen() {
    printf "\e[2J\e[H"
}

# Clear line from cursor
clear_eol() {
    printf "\e[K"
}

# Draw a horizontal line
draw_hline() {
    local row=$1 col=$2 len=$3 char=${4:-"─"}
    move_to "$row" "$col"
    local line=""
    for ((i=0; i<len; i++)); do line+="$char"; done
    printf "%s" "$line"
}

# Draw a vertical line
draw_vline() {
    local start_row=$1 col=$2 len=$3 char=${4:-"│"}
    for ((i=0; i<len; i++)); do
        move_to $((start_row + i)) "$col"
        printf "%s" "$char"
    done
}

# Draw a box with title
draw_box() {
    local row=$1 col=$2 width=$3 height=$4
    local title=${5:-""}
    local color=${6:-"$CYAN"}

    printf "%b" "$color"

    # Top border
    move_to "$row" "$col"
    printf "╔"
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local left_pad=$(( (width - title_len - 2) / 2 ))
        local right_pad=$(( width - title_len - 2 - left_pad ))
        for ((i=0; i<left_pad; i++)); do printf "═"; done
        printf "%b" "${BOLD}${BYELLOW}[ ${title} ]${R}${color}"
        for ((i=0; i<right_pad; i++)); do printf "═"; done
    else
        for ((i=0; i<width-2; i++)); do printf "═"; done
    fi
    printf "╗"

    # Side borders
    for ((r=1; r<height-1; r++)); do
        move_to $((row + r)) "$col"
        printf "║"
        move_to $((row + r)) $((col + width - 1))
        printf "║"
    done

    # Bottom border
    move_to $((row + height - 1)) "$col"
    printf "╚"
    for ((i=0; i<width-2; i++)); do printf "═"; done
    printf "╝"

    printf "%b" "$R"
}

# Draw inner box (lighter border)
draw_inner_box() {
    local row=$1 col=$2 width=$3 height=$4
    local title=${5:-""}
    local color=${6:-"$BBLACK"}

    printf "%b" "$color"

    move_to "$row" "$col"
    printf "┌"
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local left_pad=$(( (width - title_len - 2) / 2 ))
        local right_pad=$(( width - title_len - 2 - left_pad ))
        for ((i=0; i<left_pad; i++)); do printf "─"; done
        printf "%b" "${BOLD}${BCYAN} ${title} ${R}${color}"
        for ((i=0; i<right_pad; i++)); do printf "─"; done
    else
        for ((i=0; i<width-2; i++)); do printf "─"; done
    fi
    printf "┐"

    for ((r=1; r<height-1; r++)); do
        move_to $((row + r)) "$col"
        printf "│"
        move_to $((row + r)) $((col + width - 1))
        printf "│"
    done

    move_to $((row + height - 1)) "$col"
    printf "└"
    for ((i=0; i<width-2; i++)); do printf "─"; done
    printf "┘"

    printf "%b" "$R"
}

# Print text inside box (auto-truncates)
print_in_box() {
    local row=$1 col=$2 width=$3 text=$4
    local color=${5:-"$WHITE"}
    local inner_width=$((width - 4))
    local text_plain
    # Strip ANSI for length calculation
    text_plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#text_plain}
    if [[ $text_len -gt $inner_width ]]; then
        text="${text:0:$inner_width}"
    fi
    move_to "$row" $((col + 2))
    printf "%b" "$color"
    printf "%b" "$text"
    printf "%b" "$R"
    # Pad with spaces
    local pad_len=$((inner_width - text_len))
    if [[ $pad_len -gt 0 ]]; then
        printf "%${pad_len}s" ""
    fi
}

# Progress bar
draw_progress() {
    local val=$1 max=$2 width=$3
    local color=${4:-"$GREEN"}
    local filled=$(( (val * width) / max ))
    [[ $filled -gt $width ]] && filled=$width
    local empty=$((width - filled))
    printf "%b" "$color"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf "%b" "$BBLACK"
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "%b" "$R"
}

# Colored text helper
ctext() {
    local color=$1 text=$2
    printf "%b%s%b" "$color" "$text" "$R"
}

# Animate typing effect
type_text() {
    local text=$1
    local delay=${2:-0.03}
    local i char
    for ((i=0; i<${#text}; i++)); do
        char="${text:$i:1}"
        printf "%s" "$char"
        sleep "$delay"
    done
}

# Get a random element from a list
rand_choice() {
    local arr=("$@")
    local len=${#arr[@]}
    echo "${arr[$((RANDOM % len))]}"
}

# Random number between min and max (inclusive)
rand_range() {
    local min=$1 max=$2
    echo $(( min + RANDOM % (max - min + 1) ))
}

# =============================================================================
# GAME SCREEN LAYOUT
# =============================================================================

# Main layout constants
HEADER_ROW=1
STATS_ROW=3
STATS_HEIGHT=7
MAIN_ROW=10
MAIN_HEIGHT=14
LOG_ROW=10
LOG_COL=55
LOG_WIDTH=26
LOG_HEIGHT=14
INPUT_ROW=24
FOOTER_ROW=25
SCREEN_WIDTH=80
SCREEN_HEIGHT=25

# Draw the static chrome/frame
draw_chrome() {
    clear_screen

    # Top header bar
    move_to 1 1
    printf "%b" "${BG_BBLACK}${BRED}${BOLD}"
    printf "%-80s" ""
    move_to 1 1
    printf "  ▓▓ CYBER-BREACH v2.077 ▓▓"
    move_to 1 35
    printf "%b" "${BYELLOW}"
    printf "[ RUNNER TERMINAL ]"
    move_to 1 60
    printf "%b" "${BCYAN}"
    printf "NET://DARKWEB.0x4F2A"
    printf "%b" "$R"

    # Decorative line
    move_to 2 1
    printf "%b" "${BBLACK}"
    for ((i=0; i<80; i++)); do printf "▀"; done
    printf "%b" "$R"

    # Stats panel border
    draw_box 3 1 53 7 "RUNNER STATUS" "$CYAN"

    # Log panel
    draw_box 10 55 26 14 "HACK LOG" "$MAGENTA"

    # Main content area
    draw_box 10 1 54 14 "" "$BLUE"

    # Input area
    move_to 24 1
    printf "%b" "${BBLACK}"
    for ((i=0; i<80; i++)); do printf "▄"; done
    printf "%b" "$R"

    # Footer
    move_to 25 1
    printf "%b" "${BG_BBLACK}${BBLACK}"
    printf "%-80s" ""
    move_to 25 1
    printf "%b" "${BBLACK}"
    printf " [WASD/HJKL:NAV] [ENTER:SELECT] [ESC:BACK] [Q:QUIT]"
    printf "%b" "$R"
}

# Update stats panel
update_stats() {
    # Line 1: Name and Level
    move_to 4 3
    printf "%b" "${BOLD}${BCYAN}RUNNER:${R} ${BYELLOW}%-12s${R}  " "$PLAYER_NAME"
    printf "%b" "${BOLD}${BCYAN}LVL:${R} ${BWHITE}%02d${R}" "$PLAYER_LEVEL"

    # Line 2: Credits and Rep
    move_to 5 3
    printf "%b" "${BOLD}${BGREEN}CR:${R}${BWHITE} %-8s${R}  " "¥$PLAYER_CREDITS"
    printf "%b" "${BOLD}${BYELLOW}REP:${R} ${BWHITE}%d${R}" "$PLAYER_REP"

    # Line 3: XP bar
    move_to 6 3
    printf "%b" "${BOLD}${BCYAN}XP:${R} "
    draw_progress "$PLAYER_XP" "$PLAYER_XP_NEXT" 20 "$BBLUE"
    printf " ${BWHITE}%d/${R}${BBLACK}%d${R}" "$PLAYER_XP" "$PLAYER_XP_NEXT"

    # Line 4: Health bar
    move_to 7 3
    printf "%b" "${BOLD}${BRED}HP:${R} "
    local hp_color="$BGREEN"
    [[ $PLAYER_HEALTH -lt 50 ]] && hp_color="$BYELLOW"
    [[ $PLAYER_HEALTH -lt 25 ]] && hp_color="$BRED"
    draw_progress "$PLAYER_HEALTH" "$PLAYER_MAX_HEALTH" 15 "$hp_color"
    printf " ${BWHITE}%d/%d${R}" "$PLAYER_HEALTH" "$PLAYER_MAX_HEALTH"

    # Heat bar
    move_to 7 35
    printf "%b" "${BOLD}${BRED}HEAT:${R} "
    local heat_color="$BGREEN"
    [[ $PLAYER_HEAT -gt 40 ]] && heat_color="$BYELLOW"
    [[ $PLAYER_HEAT -gt 70 ]] && heat_color="$BRED"
    draw_progress "$PLAYER_HEAT" 100 10 "$heat_color"
    printf " ${BWHITE}%d%%${R}" "$PLAYER_HEAT"

    # Line 5: Rig stats
    move_to 8 3
    printf "%b" "${BBLACK}CPU:${R}${BWHITE}%d${R} " "$RIG_CPU"
    printf "%b" "${BBLACK}RAM:${R}${BWHITE}%d${R} " "$RIG_RAM"
    printf "%b" "${BBLACK}STL:${R}${BWHITE}%d${R} " "$RIG_STEALTH"
    printf "%b" "${BBLACK}ICE:${R}${BWHITE}%d${R} " "$RIG_ICE_BREAK"
    printf "%b" "${BBLACK}FWL:${R}${BWHITE}%d${R} " "$RIG_FIREWALL"
    printf "%b" "${BBLACK}NET:${R}${BWHITE}%d${R}" "$RIG_NET_TAP"

    # Tools indicator
    move_to 8 44
    local tools=""
    [[ $TOOL_PHANTOM -eq 1 ]] && tools+="${BCYAN}P${R}"
    [[ $TOOL_BRUTEFORCE -eq 1 ]] && tools+="${BRED}B${R}"
    [[ $TOOL_DECRYPT -eq 1 ]] && tools+="${BGREEN}D${R}"
    [[ $TOOL_TRACE_BLOCK -eq 1 ]] && tools+="${BYELLOW}T${R}"
    [[ $TOOL_OVERCLOCK -eq 1 ]] && tools+="${BMAGENTA}O${R}"
    printf "%b" "${BBLACK}TOOLS:${R}"
    if [[ -n "$tools" ]]; then
        printf "%b" "$tools"
    else
        printf "%b" "${BBLACK}----${R}"
    fi
}

# Update hack log panel
update_log() {
    local start_row=11
    local max_lines=12
    local log_count=${#HACK_LOG[@]}
    local start_idx=0
    [[ $log_count -gt $max_lines ]] && start_idx=$((log_count - max_lines))

    for ((i=0; i<max_lines; i++)); do
        move_to $((start_row + i)) 57
        printf "%-22s" ""
    done

    local display_idx=0
    for ((i=start_idx; i<log_count; i++)); do
        move_to $((start_row + display_idx)) 57
        local entry="${HACK_LOG[$i]}"
        # Truncate if too long (accounting for ANSI)
        printf "%b" "${entry:0:60}"
        display_idx=$((display_idx + 1))
    done
}

# Add to hack log
log_add() {
    local msg=$1
    local timestamp
    timestamp=$(date +"%H:%M")
    HACK_LOG+=("${BBLACK}${timestamp}${R} ${msg}")
    update_log
}

# Clear main content area
clear_main() {
    for ((r=11; r<=22; r++)); do
        move_to "$r" 3
        printf "%-50s" ""
    done
}

# Print message in main area
main_print() {
    local row=$1 text=$2
    move_to $((10 + row)) 3
    printf "%b" "$text"
    printf "%b" "$R"
}

# Show input prompt at bottom
show_input() {
    local prompt=${1:-""}
    move_to 24 2
    printf "%b" "${BBLACK}▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${R}"
    move_to 24 2
    printf "%b" "${BYELLOW}${BOLD}>${R} ${BCYAN}${prompt}${R}"
    tput cnorm 2>/dev/null || true
}

hide_input() {
    move_to 24 2
    printf "%-78s" ""
    tput civis 2>/dev/null || true
}

# Wait for keypress
wait_key() {
    local key
    tput cnorm 2>/dev/null || true
    read -r -s -n 1 key
    tput civis 2>/dev/null || true
    echo "$key"
}

# Read string input
read_input() {
    local prompt=${1:-""}
    local default=${2:-""}
    show_input "$prompt"
    tput cnorm 2>/dev/null || true
    local input
    read -r input
    tput civis 2>/dev/null || true
    hide_input
    echo "${input:-$default}"
}

# =============================================================================
# MENU SYSTEM
# =============================================================================

# Generic menu selector
# Returns selected index (0-based) in global MENU_RESULT
MENU_RESULT=0

show_menu() {
    local title=$1
    shift
    local options=("$@")
    local num_opts=${#options[@]}
    local selected=0
    local key

    while true; do
        clear_main

        move_to 11 3
        printf "%b" "${BOLD}${BYELLOW}${title}${R}"

        for ((i=0; i<num_opts; i++)); do
            move_to $((12 + i)) 3
            if [[ $i -eq $selected ]]; then
                printf "%b" "${BG_BLUE}${BOLD}${BWHITE} ▶ %-46s ${R}" "${options[$i]}"
            else
                printf "%b" "${BBLACK}   ${R}${WHITE}%-46s${R}" "${options[$i]}"
            fi
        done

        move_to $((12 + num_opts + 1)) 3
        printf "%b" "${BBLACK}[↑↓/jk: Navigate] [Enter: Select] [q: Back]${R}"

        tput cnorm 2>/dev/null || true
        read -r -s -n 1 key || key=""
        tput civis 2>/dev/null || true

        case "$key" in
            $'\e')
                # Check for escape sequences
                read -r -s -n 2 -t 0.1 seq || seq=""
                case "$seq" in
                    "[A") ((selected > 0)) && selected=$((selected - 1)) ;;
                    "[B") ((selected < num_opts - 1)) && selected=$((selected + 1)) ;;
                esac
                ;;
            k|K) ((selected > 0)) && selected=$((selected - 1)) ;;
            j|J) ((selected < num_opts - 1)) && selected=$((selected + 1)) ;;
            w|W) ((selected > 0)) && selected=$((selected - 1)) ;;
            s|S) ((selected < num_opts - 1)) && selected=$((selected + 1)) ;;
            $'\n'|$'\r'|"") MENU_RESULT=$selected; return 0 ;;
            q|Q) MENU_RESULT=-1; return 1 ;;
        esac
    done
}

# =============================================================================
# MINIGAME 1: FIREWALL BREACH (Code Sequence)
# Player must enter a sequence of numbers in the right order
# =============================================================================

minigame_firewall() {
    local difficulty=$1
    local seq_len=$(( 3 + difficulty + (RIG_CPU > 2 ? 0 : 1) ))
    [[ $TOOL_OVERCLOCK -eq 1 ]] && seq_len=$((seq_len - 1))
    [[ $seq_len -lt 2 ]] && seq_len=2

    local time_limit=$(( 15 - difficulty * 2 + RIG_CPU ))
    [[ $time_limit -lt 5 ]] && time_limit=5

    # Generate sequence
    local -a sequence
    for ((i=0; i<seq_len; i++)); do
        sequence+=( $(rand_range 0 9) )
    done

    # BRUTEFORCE tool breaks one layer
    if [[ $TOOL_BRUTEFORCE -eq 1 && $difficulty -gt 1 ]]; then
        difficulty=$((difficulty - 1))
        log_add "${BRED}BRUTEFORCE${R} bypassed layer!"
    fi

    clear_main
    draw_inner_box 11 3 52 12 "FIREWALL BREACH" "$BCYAN"

    move_to 12 5
    printf "%b" "${BBLACK}Memorize the sequence. You have ${BYELLOW}${time_limit}s${R}${BBLACK} to input it.${R}"

    move_to 14 5
    printf "%b" "${BOLD}${BWHITE}SEQUENCE: ${R}"
    for num in "${sequence[@]}"; do
        printf "%b" "${BOLD}${BYELLOW} [%d] ${R}" "$num"
        sleep 0.15
    done

    sleep 2

    # Clear the sequence display
    move_to 14 5
    printf "%-48s" ""
    move_to 14 5
    printf "%b" "${BOLD}${BWHITE}SEQUENCE: ${R}${BBLACK}[HIDDEN]${R}"

    move_to 16 5
    printf "%b" "${BCYAN}Enter sequence (space-separated): ${R}"

    # Timer display
    local start_time=$SECONDS
    show_input "Sequence > "
    local input
    read -r -t "$time_limit" input || input=""
    hide_input

    local elapsed=$(( SECONDS - start_time ))
    [[ $elapsed -gt $time_limit ]] && input=""

    # Check answer
    local expected="${sequence[*]}"
    if [[ "$input" == "$expected" ]]; then
        move_to 18 5
        printf "%b" "${BOLD}${BGREEN}✓ FIREWALL BREACHED! Sequence correct!${R}"
        sleep 1
        return 0
    else
        move_to 18 5
        printf "%b" "${BOLD}${BRED}✗ BREACH FAILED! Expected: ${BYELLOW}${expected}${R}"
        sleep 2
        return 1
    fi
}

# =============================================================================
# MINIGAME 2: ICE CRACKER (Pattern Matching)
# Player must identify the correct hexadecimal pattern
# =============================================================================

minigame_ice_crack() {
    local difficulty=$1
    local grid_size=$(( 4 + difficulty ))
    [[ $grid_size -gt 8 ]] && grid_size=8

    clear_main
    draw_inner_box 11 3 52 12 "ICE CRACKER" "$BRED"

    # Generate hex grid
    local -a hex_grid
    local target_row=$(rand_range 0 $((grid_size - 1)))
    local target_col=$(rand_range 0 $((grid_size - 1)))
    local target_val

    move_to 12 5
    printf "%b" "${BBLACK}Find the ${BYELLOW}TARGET${R}${BBLACK} hex value in the grid.${R}"

    # Generate hex values
    declare -a grid_vals
    for ((r=0; r<grid_size; r++)); do
        for ((c=0; c<grid_size; c++)); do
            grid_vals[$((r * grid_size + c))]=$(printf "%02X" $((RANDOM % 256)))
        done
    done
    target_val="${grid_vals[$((target_row * grid_size + target_col))]}"

    # Display target with some decoys
    move_to 13 5
    printf "%b" "${BOLD}${BYELLOW}TARGET: 0x${target_val}${R}"

    # Display grid
    for ((r=0; r<grid_size; r++)); do
        move_to $((14 + r)) 5
        for ((c=0; c<grid_size; c++)); do
            local val="${grid_vals[$((r * grid_size + c))]}"
            if [[ $r -eq $target_row && $c -eq $target_col ]]; then
                # Briefly highlight or just show normal (player must find it)
                printf "%b" "${BBLACK}${val}${R} "
            else
                printf "%b" "${BBLACK}${val}${R} "
            fi
        done
    done

    move_to $((14 + grid_size + 1)) 5
    printf "%b" "${BCYAN}Enter position (row col, 0-indexed): ${R}"

    show_input "Position > "
    local input
    read -r -t 20 input || input=""
    hide_input

    local input_row input_col
    read -r input_row input_col <<< "$input"

    if [[ "$input_row" == "$target_row" && "$input_col" == "$target_col" ]]; then
        move_to $((14 + grid_size + 2)) 5
        printf "%b" "${BOLD}${BGREEN}✓ ICE CRACKED! Node located!${R}"
        sleep 1
        return 0
    else
        # Reveal correct position
        move_to $((14 + grid_size + 2)) 5
        printf "%b" "${BOLD}${BRED}✗ FAILED! Was at: ${BYELLOW}${target_row} ${target_col}${R}"
        sleep 2
        return 1
    fi
}

# =============================================================================
# MINIGAME 3: CIPHER DECRYPT (Caesar/ROT cipher)
# Player decrypts a short message
# =============================================================================

minigame_cipher() {
    local difficulty=$1

    clear_main
    draw_inner_box 11 3 52 12 "CIPHER DECRYPT" "$BMAGENTA"

    local messages=(
        "ACCESS GRANTED"
        "VAULT OPEN"
        "UPLOAD COMPLETE"
        "TRANSFER DONE"
        "SYSTEM BREACH"
        "DATA EXTRACTED"
    )
    local plaintext
    plaintext=$(rand_choice "${messages[@]}")

    # Pick a shift based on difficulty
    local shift=$(( (difficulty * 3 + RANDOM % 5 + 1) % 26 ))
    [[ $shift -eq 0 ]] && shift=1

    # If player has DECRYPT tool, give hint
    local hint_text=""
    if [[ $TOOL_DECRYPT -eq 1 ]]; then
        hint_text="(DECRYPT tool: shift ~${shift}, ±2)"
        shift_hint=$shift
    fi

    # Encrypt
    local ciphertext=""
    for ((i=0; i<${#plaintext}; i++)); do
        local char="${plaintext:$i:1}"
        if [[ "$char" =~ [A-Z] ]]; then
            local ord=$(printf "%d" "'$char")
            local shifted_ord=$(( (ord - 65 + shift) % 26 + 65 ))
            ciphertext+=$(printf "\\$(printf '%03o' "$shifted_ord")")
        else
            ciphertext+="$char"
        fi
    done

    move_to 12 5
    printf "%b" "${BBLACK}Decrypt the intercepted transmission.${R}"
    [[ -n "$hint_text" ]] && printf " %b" "${BCYAN}${hint_text}${R}"

    move_to 14 5
    printf "%b" "${BOLD}${BRED}CIPHER: ${BYELLOW}${ciphertext}${R}"

    move_to 16 5
    printf "%b" "${BBLACK}Hint: ROT cipher (shift A-Z). Spaces preserved.${R}"

    show_input "Decrypt > "
    local input
    read -r -t 30 input || input=""
    hide_input

    input="${input^^}"  # uppercase

    if [[ "$input" == "$plaintext" ]]; then
        move_to 18 5
        printf "%b" "${BOLD}${BGREEN}✓ DECRYPTED! Message: ${BYELLOW}${plaintext}${R}"
        sleep 1
        return 0
    else
        move_to 18 5
        printf "%b" "${BOLD}${BRED}✗ WRONG! Was: ${BYELLOW}${plaintext}${R}${BRED} (shift ${shift})${R}"
        sleep 2
        return 1
    fi
}

# =============================================================================
# MINIGAME 4: TRACE EVADE (Reaction game)
# Player must press the right key before trace completes
# =============================================================================

minigame_trace_evade() {
    local difficulty=$1

    clear_main
    draw_inner_box 11 3 52 12 "TRACE EVADE" "$BYELLOW"

    local rounds=$(( 2 + difficulty ))
    [[ $TOOL_TRACE_BLOCK -eq 1 ]] && rounds=$((rounds - 1))
    [[ $rounds -lt 1 ]] && rounds=1

    move_to 12 5
    printf "%b" "${BBLACK}Evade the corporate trace! React to the prompts.${R}"

    local keys=("A" "S" "D" "F" "J" "K" "L" "W" "E" "R")
    local success=0
    local failed=0

    for ((round=1; round<=rounds; round++)); do
        local target_key
        target_key=$(rand_choice "${keys[@]}")
        local react_time=$(( 3 - difficulty + RIG_STEALTH ))
        [[ $react_time -lt 1 ]] && react_time=1
        [[ $TOOL_OVERCLOCK -eq 1 ]] && react_time=$((react_time + 1))

        move_to $((13 + round)) 5
        printf "%-45s" ""
        move_to $((13 + round)) 5
        printf "%b" "${BBLACK}Round ${round}/${rounds}: ${R}"

        # Countdown
        for ((cd=3; cd>=1; cd--)); do
            move_to $((13 + round)) 20
            printf "%b" "${BYELLOW}[%d]${R}" "$cd"
            sleep 0.4
        done

        move_to $((13 + round)) 20
        printf "%b" "${BOLD}${BRED}>>> PRESS [%s] <<<${R}" "$target_key"

        # Read with timeout
        tput cnorm 2>/dev/null || true
        local pressed=""
        read -r -s -n 1 -t "$react_time" pressed || pressed=""
        tput civis 2>/dev/null || true

        pressed="${pressed^^}"

        if [[ "$pressed" == "$target_key" ]]; then
            printf " %b" "${BGREEN}✓${R}"
            success=$((success + 1))
        else
            printf " %b" "${BRED}✗ (was ${target_key})${R}"
            failed=$((failed + 1))
        fi
    done

    sleep 0.5

    if [[ $failed -eq 0 ]]; then
        move_to $((13 + rounds + 2)) 5
        printf "%b" "${BOLD}${BGREEN}✓ TRACE EVADED! Clean escape!${R}"
        sleep 1
        return 0
    elif [[ $success -gt $failed ]]; then
        move_to $((13 + rounds + 2)) 5
        printf "%b" "${BYELLOW}⚠ PARTIAL EVADE! Partially traced.${R}"
        sleep 1
        return 0  # Partial success
    else
        move_to $((13 + rounds + 2)) 5
        printf "%b" "${BRED}✗ TRACED! Heat increased!${R}"
        sleep 2
        return 1
    fi
}

# =============================================================================
# MINIGAME 5: PORT SCAN (Number guessing with hints)
# =============================================================================

minigame_port_scan() {
    local difficulty=$1
    local max_port=$(( 9999 + difficulty * 1000 ))
    local attempts=$(( 8 - difficulty + RIG_NET_TAP ))
    [[ $attempts -lt 3 ]] && attempts=3
    [[ $TOOL_OVERCLOCK -eq 1 ]] && attempts=$((attempts + 2))

    local target_port
    target_port=$(rand_range 1 "$max_port")

    clear_main
    draw_inner_box 11 3 52 12 "PORT SCAN" "$BBLUE"

    move_to 12 5
    printf "%b" "${BBLACK}Locate the open port (1-${max_port}). ${BCYAN}${attempts} attempts.${R}"

    local attempt=0
    local found=0

    while [[ $attempt -lt $attempts ]]; do
        move_to $((13 + attempt)) 5
        printf "%-45s" ""
        move_to $((13 + attempt)) 5
        printf "%b" "${BBLACK}Scan %d/${attempts}: ${R}" "$((attempt + 1))"

        show_input "Port (1-${max_port}) > "
        local guess
        read -r guess || guess=""
        hide_input

        # Validate input
        if ! [[ "$guess" =~ ^[0-9]+$ ]]; then
            move_to $((13 + attempt)) 30
            printf "%b" "${BRED}Invalid${R}"
            attempt=$((attempt + 1))
            continue
        fi

        move_to $((13 + attempt)) 5
        printf "%b" "${BBLACK}Port ${guess}: ${R}"

        if [[ $guess -eq $target_port ]]; then
            printf "%b" "${BOLD}${BGREEN}OPEN! ✓${R}"
            found=1
            break
        elif [[ $guess -lt $target_port ]]; then
            local diff=$(( target_port - guess ))
            if [[ $diff -lt 100 ]]; then
                printf "%b" "${BYELLOW}Too low (very close!)${R}"
            elif [[ $diff -lt 1000 ]]; then
                printf "%b" "${BBLUE}Too low (warm)${R}"
            else
                printf "%b" "${BBLACK}Too low (cold)${R}"
            fi
        else
            local diff=$(( guess - target_port ))
            if [[ $diff -lt 100 ]]; then
                printf "%b" "${BYELLOW}Too high (very close!)${R}"
            elif [[ $diff -lt 1000 ]]; then
                printf "%b" "${BBLUE}Too high (warm)${R}"
            else
                printf "%b" "${BBLACK}Too high (cold)${R}"
            fi
        fi

        attempt=$((attempt + 1))
    done

    if [[ $found -eq 1 ]]; then
        move_to $((13 + attempts + 1)) 5
        printf "%b" "${BOLD}${BGREEN}✓ PORT FOUND! Connection established!${R}"
        sleep 1
        return 0
    else
        move_to $((13 + attempts + 1)) 5
        printf "%b" "${BRED}✗ SCAN FAILED! Port was: ${BYELLOW}${target_port}${R}"
        sleep 2
        return 1
    fi
}

# =============================================================================
# CONTRACT SYSTEM
# =============================================================================

declare -a CONTRACT_NAMES
CONTRACT_NAMES=(
    "Steal NeoCorp Financial Records"
    "Breach ArasakaNet Server Farm"
    "Extract Biotech Research Data"
    "Infiltrate MegaPlex Defense Grid"
    "Download OmniCorp Black Ledger"
    "Disable SynthTech Surveillance Net"
    "Plant Logic Bomb in GridPlex"
    "Exfiltrate Classified Dossiers"
    "Crack ZetaCorp Encryption Keys"
    "Sabotage NovaMed Clinical Database"
    "Ghost Run on GovNet Alpha"
    "Rip VaultMind AI Core Secrets"
    "Burn the Trail on DataHaven"
    "Mirror QuantumNet Protocol Stack"
    "Splice into Nexus Prime Backbone"
)

declare -a CONTRACT_CORPS
CONTRACT_CORPS=(
    "NeoCorp" "ArasakaNet" "BioTech Industries"
    "MegaPlex" "OmniCorp" "SynthTech"
    "GridPlex" "QuantumSec" "ZetaCorp"
    "NovaMed" "GovNet" "VaultMind"
)

generate_contract() {
    local diff=$1  # 1-5

    local name
    name=$(rand_choice "${CONTRACT_NAMES[@]}")
    local corp
    corp=$(rand_choice "${CONTRACT_CORPS[@]}")

    local base_pay=$(( 200 + diff * 150 + RANDOM % 200 ))
    local base_xp=$(( 30 + diff * 25 ))
    local base_heat=$(( 5 + diff * 8 ))

    CURRENT_CONTRACT="$name"
    CURRENT_CONTRACT_DIFF=$diff
    CURRENT_CONTRACT_PAY=$base_pay
    CURRENT_CONTRACT_XP=$base_xp
    CURRENT_CONTRACT_HEAT=$base_heat

    echo "$corp"
}

# Show contract board
show_contracts() {
    local -a available_diffs
    local -a available_names
    local -a available_pays
    local -a available_xps
    local -a available_corps

    # Generate 4-6 contracts based on player level
    local num_contracts=$(( 3 + PLAYER_LEVEL / 2 ))
    [[ $num_contracts -gt 6 ]] && num_contracts=6

    clear_main

    draw_inner_box 11 3 52 12 "CONTRACT BOARD" "$BYELLOW"

    move_to 12 5
    printf "%b" "${BBLACK}Available runs. Higher difficulty = better pay + XP.${R}"

    local -a menu_items=()

    for ((i=0; i<num_contracts; i++)); do
        local max_diff=$(( 1 + PLAYER_LEVEL / 2 ))
        [[ $max_diff -gt 5 ]] && max_diff=5
        local diff=$(rand_range 1 $max_diff)
        local corp
        corp=$(generate_contract "$diff")

        available_diffs+=("$diff")
        available_corps+=("$corp")
        available_names+=("$CURRENT_CONTRACT")
        available_pays+=("$CURRENT_CONTRACT_PAY")
        available_xps+=("$CURRENT_CONTRACT_XP")

        local diff_str=""
        case $diff in
            1) diff_str="${BGREEN}[EASY]${R}" ;;
            2) diff_str="${BCYAN}[MED] ${R}" ;;
            3) diff_str="${BYELLOW}[HARD]${R}" ;;
            4) diff_str="${BRED}[XHRD]${R}" ;;
            5) diff_str="${BMAGENTA}[LETL]${R}" ;;
        esac

        menu_items+=("$diff_str ${corp}: ¥${CURRENT_CONTRACT_PAY} / ${CURRENT_CONTRACT_XP}XP")
    done
    menu_items+=("[ BACK TO MAIN MENU ]")

    # Show menu
    local selected=0
    local num_opts=${#menu_items[@]}
    local key

    while true; do
        for ((i=0; i<num_opts; i++)); do
            move_to $((13 + i)) 5
            if [[ $i -eq $selected ]]; then
                printf "%b" "${BG_BLUE}${BOLD}${BWHITE} ▶ "
                printf "%b" "${menu_items[$i]}"
                printf "%b" " ${R}"
                # Pad
                move_to $((13 + i)) 48
                printf "%b" "${BG_BLUE} ${R}"
            else
                printf "   %b" "${menu_items[$i]}"
                printf "%b" "${R}"
            fi
        done

        tput cnorm 2>/dev/null || true
        read -r -s -n 1 key || key=""
        tput civis 2>/dev/null || true

        case "$key" in
            $'\e')
                read -r -s -n 2 -t 0.1 seq || seq=""
                case "$seq" in
                    "[A") ((selected > 0)) && selected=$((selected - 1)) ;;
                    "[B") ((selected < num_opts - 1)) && selected=$((selected + 1)) ;;
                esac
                ;;
            k|K|w|W) ((selected > 0)) && selected=$((selected - 1)) ;;
            j|J|s|S) ((selected < num_opts - 1)) && selected=$((selected + 1)) ;;
            $'\n'|$'\r'|"")
                if [[ $selected -eq $((num_opts - 1)) ]]; then
                    return 1  # Back
                fi
                # Execute selected contract
                CURRENT_CONTRACT="${available_names[$selected]}"
                CURRENT_CONTRACT_DIFF="${available_diffs[$selected]}"
                CURRENT_CONTRACT_PAY="${available_pays[$selected]}"
                CURRENT_CONTRACT_XP="${available_xps[$selected]}"
                CURRENT_CONTRACT_HEAT=$(( 5 + available_diffs[$selected] * 8 ))
                execute_contract "${available_corps[$selected]}"
                return 0
                ;;
            q|Q) return 1 ;;
        esac
    done
}

# =============================================================================
# CONTRACT EXECUTION
# =============================================================================

execute_contract() {
    local corp=$1
    local diff=$CURRENT_CONTRACT_DIFF
    local total_stages=0
    local stages_passed=0

    log_add "${BYELLOW}RUN:${R} ${CURRENT_CONTRACT:0:18}"

    # Determine which minigames to run based on difficulty
    local -a stages=()
    stages+=("firewall")   # Always starts with firewall

    if [[ $diff -ge 2 ]]; then stages+=("trace_evade"); fi
    if [[ $diff -ge 2 ]]; then stages+=("port_scan"); fi
    if [[ $diff -ge 3 ]]; then stages+=("ice_crack"); fi
    if [[ $diff -ge 3 ]]; then stages+=("cipher"); fi
    if [[ $diff -ge 4 ]]; then stages+=("firewall"); fi
    if [[ $diff -ge 5 ]]; then stages+=("trace_evade"); fi

    total_stages=${#stages[@]}

    # Show contract briefing
    clear_main
    draw_inner_box 11 3 52 12 "MISSION BRIEFING" "$BGREEN"

    move_to 12 5
    printf "%b" "${BOLD}${BYELLOW}TARGET: ${BWHITE}${corp}${R}"
    move_to 13 5
    printf "%b" "${BOLD}${BCYAN}CONTRACT: ${BWHITE}${CURRENT_CONTRACT:0:42}${R}"
    move_to 14 5
    printf "%b" "${BBLACK}Difficulty: ${R}"
    for ((d=1; d<=5; d++)); do
        if [[ $d -le $diff ]]; then
            printf "%b" "${BRED}■${R}"
        else
            printf "%b" "${BBLACK}□${R}"
        fi
    done
    move_to 15 5
    printf "%b" "${BGREEN}Pay: ¥${CURRENT_CONTRACT_PAY}${R}  ${BCYAN}XP: +${CURRENT_CONTRACT_XP}${R}  ${BRED}Heat: +${CURRENT_CONTRACT_HEAT}%%${R}"
    move_to 16 5
    printf "%b" "${BBLACK}Stages: ${BWHITE}${total_stages}${R}"
    move_to 18 5
    printf "%b" "${BBLACK}Initiating ghost protocol...${R}"

    # Animate loading
    move_to 19 5
    local loading_chars=("▰▱▱▱▱▱▱▱▱▱" "▰▰▱▱▱▱▱▱▱▱" "▰▰▰▱▱▱▱▱▱▱" "▰▰▰▰▱▱▱▱▱▱"
                          "▰▰▰▰▰▱▱▱▱▱" "▰▰▰▰▰▰▱▱▱▱" "▰▰▰▰▰▰▰▱▱▱" "▰▰▰▰▰▰▰▰▱▱"
                          "▰▰▰▰▰▰▰▰▰▱" "▰▰▰▰▰▰▰▰▰▰")
    for lc in "${loading_chars[@]}"; do
        move_to 19 5
        printf "%b" "${BCYAN}[${lc}]${R}"
        sleep 0.1
    done

    printf "%b" " ${BGREEN}LOCKED${R}"
    sleep 0.5

    # Run stages
    local stage_num=0
    for stage in "${stages[@]}"; do
        stage_num=$((stage_num + 1))

        clear_main
        move_to 11 3
        printf "%b" "${BBLACK}Stage ${stage_num}/${total_stages}: ${BYELLOW}${stage^^}${R}"
        sleep 0.5

        local result=0
        case "$stage" in
            firewall)   minigame_firewall "$diff" || result=1 ;;
            ice_crack)  minigame_ice_crack "$diff" || result=1 ;;
            cipher)     minigame_cipher "$diff" || result=1 ;;
            trace_evade) minigame_trace_evade "$diff" || result=1 ;;
            port_scan)  minigame_port_scan "$diff" || result=1 ;;
        esac

        if [[ $result -eq 0 ]]; then
            stages_passed=$((stages_passed + 1))
            log_add "${BGREEN}✓${R} Stage ${stage_num} OK"
        else
            log_add "${BRED}✗${R} Stage ${stage_num} FAIL"
            # Optional: abort on critical fail
            if [[ $diff -ge 4 && $result -eq 1 ]]; then
                break
            fi
        fi
    done

    # Determine outcome
    local success_ratio
    success_ratio=$(( (stages_passed * 100) / total_stages ))

    clear_main
    draw_inner_box 11 3 52 12 "RUN COMPLETE" "$BCYAN"

    move_to 12 5
    printf "%b" "${BOLD}${BYELLOW}RUN RESULTS${R}"

    move_to 13 5
    printf "%b" "${BBLACK}Stages cleared: ${BWHITE}${stages_passed}/${total_stages}${R}"

    move_to 14 5
    draw_progress "$stages_passed" "$total_stages" 30 "$BCYAN"

    if [[ $success_ratio -ge 100 ]]; then
        # Perfect run
        local bonus=$(( CURRENT_CONTRACT_PAY / 5 ))
        PLAYER_CREDITS=$(( PLAYER_CREDITS + CURRENT_CONTRACT_PAY + bonus ))
        PLAYER_XP=$(( PLAYER_XP + CURRENT_CONTRACT_XP ))
        local heat_add=$(( CURRENT_CONTRACT_HEAT / 2 ))
        [[ $TOOL_PHANTOM -eq 1 ]] && heat_add=$(( heat_add * 8 / 10 ))
        PLAYER_HEAT=$(( PLAYER_HEAT + heat_add ))
        PLAYER_REP=$(( PLAYER_REP + CURRENT_CONTRACT_DIFF * 2 ))
        CONTRACTS_COMPLETED=$(( CONTRACTS_COMPLETED + 1 ))

        move_to 16 5
        printf "%b" "${BOLD}${BGREEN}✓ PERFECT RUN!${R}"
        move_to 17 5
        printf "%b" "${BGREEN}Credits: +¥${CURRENT_CONTRACT_PAY} (+¥${bonus} bonus)${R}"
        move_to 18 5
        printf "%b" "${BCYAN}XP: +${CURRENT_CONTRACT_XP}${R}  ${BRED}Heat: +${heat_add}%%${R}"

        log_add "${BGREEN}PERFECT${R} ¥+${CURRENT_CONTRACT_PAY}"

    elif [[ $success_ratio -ge 60 ]]; then
        # Partial success
        local partial_pay=$(( CURRENT_CONTRACT_PAY * success_ratio / 100 ))
        local partial_xp=$(( CURRENT_CONTRACT_XP * success_ratio / 100 ))
        PLAYER_CREDITS=$(( PLAYER_CREDITS + partial_pay ))
        PLAYER_XP=$(( PLAYER_XP + partial_xp ))
        local heat_add=$CURRENT_CONTRACT_HEAT
        [[ $TOOL_PHANTOM -eq 1 ]] && heat_add=$(( heat_add * 8 / 10 ))
        PLAYER_HEAT=$(( PLAYER_HEAT + heat_add ))
        PLAYER_REP=$(( PLAYER_REP + CURRENT_CONTRACT_DIFF ))
        CONTRACTS_COMPLETED=$(( CONTRACTS_COMPLETED + 1 ))

        move_to 16 5
        printf "%b" "${BYELLOW}⚠ PARTIAL SUCCESS (${success_ratio}%%)${R}"
        move_to 17 5
        printf "%b" "${BGREEN}Credits: +¥${partial_pay}${R}  ${BCYAN}XP: +${partial_xp}${R}"
        move_to 18 5
        printf "%b" "${BRED}Heat: +${heat_add}%%${R}"

        log_add "${BYELLOW}PARTIAL${R} ¥+${partial_pay}"

    else
        # Failed run
        local heat_add=$(( CURRENT_CONTRACT_HEAT * 2 ))
        [[ $TOOL_PHANTOM -eq 1 ]] && heat_add=$(( heat_add * 8 / 10 ))
        PLAYER_HEAT=$(( PLAYER_HEAT + heat_add ))
        local dmg=$(( 10 + diff * 5 ))
        PLAYER_HEALTH=$(( PLAYER_HEALTH - dmg ))
        [[ $PLAYER_HEALTH -lt 0 ]] && PLAYER_HEALTH=0

        move_to 16 5
        printf "%b" "${BOLD}${BRED}✗ RUN FAILED!${R}"
        move_to 17 5
        printf "%b" "${BRED}No payout. Heat: +${heat_add}%% HP: -${dmg}${R}"

        log_add "${BRED}FAILED${R} HP-${dmg}"
    fi

    # Cap heat
    [[ $PLAYER_HEAT -gt 100 ]] && PLAYER_HEAT=100

    # Check for level up
    check_levelup

    # Check if heat is critical
    if [[ $PLAYER_HEAT -ge 100 ]]; then
        move_to 19 5
        printf "%b" "${BOLD}${BLINK}${BRED}⚠ CRITICAL HEAT! CORPS ARE CLOSING IN!${R}"
        PLAYER_HEALTH=$(( PLAYER_HEALTH - 20 ))
        [[ $PLAYER_HEALTH -lt 0 ]] && PLAYER_HEALTH=0
    fi

    move_to 21 5
    printf "%b" "${BBLACK}[Press any key to continue...]${R}"
    wait_key > /dev/null

    update_stats
}

# =============================================================================
# LEVEL UP SYSTEM
# =============================================================================

check_levelup() {
    while [[ $PLAYER_XP -ge $PLAYER_XP_NEXT ]]; do
        PLAYER_XP=$(( PLAYER_XP - PLAYER_XP_NEXT ))
        PLAYER_LEVEL=$(( PLAYER_LEVEL + 1 ))
        PLAYER_XP_NEXT=$(( PLAYER_XP_NEXT + 50 * PLAYER_LEVEL ))
        PLAYER_MAX_HEALTH=$(( 100 + (PLAYER_LEVEL - 1) * 10 ))
        PLAYER_HEALTH=$PLAYER_MAX_HEALTH

        clear_main
        draw_inner_box 11 3 52 12 "LEVEL UP!" "$BYELLOW"

        move_to 12 5
        printf "%b" "${BOLD}${BYELLOW}◄◄◄ RUNNER LEVELED UP! ►►►${R}"
        move_to 13 5
        printf "%b" "${BCYAN}You are now Level ${BWHITE}${PLAYER_LEVEL}${R}"
        move_to 14 5
        printf "%b" "${BGREEN}Max HP increased to ${BWHITE}${PLAYER_MAX_HEALTH}${R}"
        move_to 15 5
        printf "%b" "${BBLUE}HP fully restored!${R}"
        move_to 16 5
        printf "%b" "${BBLACK}Next level at: ${BWHITE}${PLAYER_XP_NEXT} XP${R}"
        move_to 18 5
        printf "%b" "${BBLACK}[Press any key...]${R}"

        log_add "${BYELLOW}LVL UP!${R} Now Level ${PLAYER_LEVEL}"
        wait_key > /dev/null
    done
}

# =============================================================================
# UPGRADE SHOP
# =============================================================================

show_upgrades() {
    while true; do
        clear_main
        draw_inner_box 11 3 52 12 "UPGRADE SHOP" "$BMAGENTA"

        move_to 12 5
        printf "%b" "${BOLD}${BYELLOW}Available Credits: ¥${PLAYER_CREDITS}${R}"

        local -a menu_items=()
        local -a menu_keys=()

        # Hardware upgrades
        menu_items+=("─── HARDWARE ─────────────────────────")
        menu_keys+=("SEP")

        for hw in CPU RAM STEALTH ICE_BREAK FIREWALL NET_TAP; do
            local current_level
            local max_level="${UPGRADE_MAX_LEVEL[$hw]}"
            local base_cost="${UPGRADE_BASE_COST[$hw]}"

            case $hw in
                CPU) current_level=$RIG_CPU; local desc="Processing Speed" ;;
                RAM) current_level=$RIG_RAM; local desc="Memory Buffer" ;;
                STEALTH) current_level=$RIG_STEALTH; local desc="Heat Reduction" ;;
                ICE_BREAK) current_level=$RIG_ICE_BREAK; local desc="ICE Power" ;;
                FIREWALL) current_level=$RIG_FIREWALL; local desc="Defense Rating" ;;
                NET_TAP) current_level=$RIG_NET_TAP; local desc="Net Analysis" ;;
            esac

            local cost=$(( base_cost * current_level ))
            if [[ $current_level -ge $max_level ]]; then
                menu_items+=("${hw} (${desc}) Lv.${current_level}/${max_level} [MAXED]")
            else
                menu_items+=("${hw} (${desc}) Lv.${current_level}→$((current_level+1)) | ¥${cost}")
            fi
            menu_keys+=("$hw")
        done

        # Software/Tools
        menu_items+=("─── SOFTWARE TOOLS ───────────────────")
        menu_keys+=("SEP")

        # Phantom
        if [[ $TOOL_PHANTOM -eq 0 ]]; then
            menu_items+=("PHANTOM.EXE (20% heat reduction) | ¥${TOOL_PHANTOM_COST}")
        else
            menu_items+=("PHANTOM.EXE [INSTALLED]")
        fi
        menu_keys+=("PHANTOM")

        # Bruteforce
        if [[ $TOOL_BRUTEFORCE -eq 0 ]]; then
            menu_items+=("BRUTE.EXE (bypass 1 firewall layer) | ¥${TOOL_BRUTEFORCE_COST}")
        else
            menu_items+=("BRUTE.EXE [INSTALLED]")
        fi
        menu_keys+=("BRUTEFORCE")

        # Decrypt
        if [[ $TOOL_DECRYPT -eq 0 ]]; then
            menu_items+=("DECRYPT.EXE (cipher hints) | ¥${TOOL_DECRYPT_COST}")
        else
            menu_items+=("DECRYPT.EXE [INSTALLED]")
        fi
        menu_keys+=("DECRYPT")

        # Trace Block
        if [[ $TOOL_TRACE_BLOCK -eq 0 ]]; then
            menu_items+=("TBLOCK.EXE (block 1 trace) | ¥${TOOL_TRACE_BLOCK_COST}")
        else
            menu_items+=("TBLOCK.EXE [INSTALLED]")
        fi
        menu_keys+=("TRACE_BLOCK")

        # Overclock
        if [[ $TOOL_OVERCLOCK -eq 0 ]]; then
            menu_items+=("OVERCLOCK.EXE (speed boost) | ¥${TOOL_OVERCLOCK_COST}")
        else
            menu_items+=("OVERCLOCK.EXE [INSTALLED]")
        fi
        menu_keys+=("OVERCLOCK")

        menu_items+=("[ BACK ]")
        menu_keys+=("BACK")

        local num_opts=${#menu_items[@]}
        local selected=0
        local key

        # Find first non-separator
        while [[ "${menu_keys[$selected]}" == "SEP" ]]; do
            selected=$((selected + 1))
        done

        # Render menu
        while true; do
            for ((i=0; i<num_opts; i++)); do
                move_to $((12 + i)) 5
                if [[ "${menu_keys[$i]}" == "SEP" ]]; then
                    printf "%b" "${BBLACK}${menu_items[$i]}${R}"
                elif [[ $i -eq $selected ]]; then
                    printf "%b" "${BG_BLUE}${BOLD}${BWHITE} ▶ %-43s ${R}" "${menu_items[$i]}"
                else
                    printf "   %b%-43s%b" "${WHITE}" "${menu_items[$i]}" "${R}"
                fi
            done

            tput cnorm 2>/dev/null || true
            read -r -s -n 1 key || key=""
            tput civis 2>/dev/null || true

            case "$key" in
                $'\e')
                    read -r -s -n 2 -t 0.1 seq || seq=""
                    case "$seq" in
                        "[A")
                            selected=$((selected - 1))
                            while [[ $selected -ge 0 && "${menu_keys[$selected]}" == "SEP" ]]; do
                                selected=$((selected - 1))
                            done
                            [[ $selected -lt 0 ]] && selected=0
                            ;;
                        "[B")
                            selected=$((selected + 1))
                            while [[ $selected -lt $num_opts && "${menu_keys[$selected]}" == "SEP" ]]; do
                                selected=$((selected + 1))
                            done
                            [[ $selected -ge $num_opts ]] && selected=$((num_opts - 1))
                            ;;
                    esac
                    ;;
                k|K|w|W)
                    selected=$((selected - 1))
                    while [[ $selected -ge 0 && "${menu_keys[$selected]}" == "SEP" ]]; do
                        selected=$((selected - 1))
                    done
                    [[ $selected -lt 0 ]] && selected=0
                    ;;
                j|J|s|S)
                    selected=$((selected + 1))
                    while [[ $selected -lt $num_opts && "${menu_keys[$selected]}" == "SEP" ]]; do
                        selected=$((selected + 1))
                    done
                    [[ $selected -ge $num_opts ]] && selected=$((num_opts - 1))
                    ;;
                $'\n'|$'\r'|"")
                    local chosen_key="${menu_keys[$selected]}"
                    case "$chosen_key" in
                        BACK) return 0 ;;
                        SEP) ;;
                        CPU|RAM|STEALTH|ICE_BREAK|FIREWALL|NET_TAP)
                            purchase_hardware "$chosen_key"
                            ;;
                        PHANTOM|BRUTEFORCE|DECRYPT|TRACE_BLOCK|OVERCLOCK)
                            purchase_tool "$chosen_key"
                            ;;
                    esac
                    break  # Re-render menu
                    ;;
                q|Q) return 0 ;;
            esac
        done
    done
}

purchase_hardware() {
    local hw=$1
    local current_level max_level cost

    case $hw in
        CPU) current_level=$RIG_CPU ;;
        RAM) current_level=$RIG_RAM ;;
        STEALTH) current_level=$RIG_STEALTH ;;
        ICE_BREAK) current_level=$RIG_ICE_BREAK ;;
        FIREWALL) current_level=$RIG_FIREWALL ;;
        NET_TAP) current_level=$RIG_NET_TAP ;;
    esac

    max_level="${UPGRADE_MAX_LEVEL[$hw]}"

    if [[ $current_level -ge $max_level ]]; then
        show_flash_message "${BYELLOW}Already at maximum level!${R}"
        return
    fi

    cost=$(( "${UPGRADE_BASE_COST[$hw]}" * current_level ))

    if [[ $PLAYER_CREDITS -lt $cost ]]; then
        show_flash_message "${BRED}Insufficient credits! Need ¥${cost}${R}"
        return
    fi

    PLAYER_CREDITS=$(( PLAYER_CREDITS - cost ))

    case $hw in
        CPU) RIG_CPU=$((RIG_CPU + 1)) ;;
        RAM) RIG_RAM=$((RIG_RAM + 1)) ;;
        STEALTH) RIG_STEALTH=$((RIG_STEALTH + 1)) ;;
        ICE_BREAK) RIG_ICE_BREAK=$((RIG_ICE_BREAK + 1)) ;;
        FIREWALL) RIG_FIREWALL=$((RIG_FIREWALL + 1)) ;;
        NET_TAP) RIG_NET_TAP=$((RIG_NET_TAP + 1)) ;;
    esac

    log_add "${BMAGENTA}UPGRADE${R} ${hw} → Lv.$((current_level+1))"
    show_flash_message "${BGREEN}${hw} upgraded to Level $((current_level+1))! -¥${cost}${R}"
    update_stats
}

purchase_tool() {
    local tool=$1
    local cost installed

    case $tool in
        PHANTOM) cost=$TOOL_PHANTOM_COST; installed=$TOOL_PHANTOM ;;
        BRUTEFORCE) cost=$TOOL_BRUTEFORCE_COST; installed=$TOOL_BRUTEFORCE ;;
        DECRYPT) cost=$TOOL_DECRYPT_COST; installed=$TOOL_DECRYPT ;;
        TRACE_BLOCK) cost=$TOOL_TRACE_BLOCK_COST; installed=$TOOL_TRACE_BLOCK ;;
        OVERCLOCK) cost=$TOOL_OVERCLOCK_COST; installed=$TOOL_OVERCLOCK ;;
    esac

    if [[ $installed -eq 1 ]]; then
        show_flash_message "${BYELLOW}Tool already installed!${R}"
        return
    fi

    if [[ $PLAYER_CREDITS -lt $cost ]]; then
        show_flash_message "${BRED}Insufficient credits! Need ¥${cost}${R}"
        return
    fi

    PLAYER_CREDITS=$(( PLAYER_CREDITS - cost ))

    case $tool in
        PHANTOM) TOOL_PHANTOM=1 ;;
        BRUTEFORCE) TOOL_BRUTEFORCE=1 ;;
        DECRYPT) TOOL_DECRYPT=1 ;;
        TRACE_BLOCK) TOOL_TRACE_BLOCK=1 ;;
        OVERCLOCK) TOOL_OVERCLOCK=1 ;;
    esac

    log_add "${BMAGENTA}INSTALL${R} ${tool}.EXE"
    show_flash_message "${BGREEN}${tool}.EXE installed! -¥${cost}${R}"
    update_stats
}

# Flash message in main area
show_flash_message() {
    local msg=$1
    move_to 22 5
    printf "%-48s" ""
    move_to 22 5
    printf "%b" "  ${msg}${R}"
    sleep 1.5
    move_to 22 5
    printf "%-48s" ""
}

# =============================================================================
# BLACK MARKET
# =============================================================================

show_black_market() {
    clear_main
    draw_inner_box 11 3 52 12 "BLACK MARKET" "$BRED"

    move_to 12 5
    printf "%b" "${BOLD}${BRED}⚠ UNDERGROUND DEALS ⚠${R}"
    move_to 13 5
    printf "%b" "${BBLACK}Reduce heat, restore HP, or get insider info.${R}"

    local -a options=(
        "Scrub Records (reduce heat -20%) | ¥400"
        "Doc Fix (restore HP to full)     | ¥300"
        "Insider Tip (+50 XP, +15 rep)    | ¥250"
        "Ghost Protocol (heat → 0)        | ¥1500"
        "[ BACK ]"
    )

    local selected=0
    local key

    while true; do
        for ((i=0; i<${#options[@]}; i++)); do
            move_to $((14 + i)) 5
            if [[ $i -eq $selected ]]; then
                printf "%b" "${BG_RED}${BOLD}${BWHITE} ▶ %-43s ${R}" "${options[$i]}"
            else
                printf "   %b%-43s%b" "${WHITE}" "${options[$i]}" "${R}"
            fi
        done

        tput cnorm 2>/dev/null || true
        read -r -s -n 1 key || key=""
        tput civis 2>/dev/null || true

        case "$key" in
            $'\e')
                read -r -s -n 2 -t 0.1 seq || seq=""
                case "$seq" in
                    "[A") ((selected > 0)) && selected=$((selected - 1)) ;;
                    "[B") ((selected < ${#options[@]} - 1)) && selected=$((selected + 1)) ;;
                esac
                ;;
            k|K|w|W) ((selected > 0)) && selected=$((selected - 1)) ;;
            j|J|s|S) ((selected < ${#options[@]} - 1)) && selected=$((selected + 1)) ;;
            $'\n'|$'\r'|"")
                case $selected in
                    0)  # Scrub records
                        if [[ $PLAYER_CREDITS -ge 400 ]]; then
                            PLAYER_CREDITS=$(( PLAYER_CREDITS - 400 ))
                            PLAYER_HEAT=$(( PLAYER_HEAT - 20 ))
                            [[ $PLAYER_HEAT -lt 0 ]] && PLAYER_HEAT=0
                            log_add "${BBLACK}SCRUB${R} Heat-20%%"
                            show_flash_message "${BGREEN}Records scrubbed! Heat: -20%%${R}"
                            update_stats
                        else
                            show_flash_message "${BRED}Insufficient credits!${R}"
                        fi
                        ;;
                    1)  # Doc fix
                        if [[ $PLAYER_CREDITS -ge 300 ]]; then
                            PLAYER_CREDITS=$(( PLAYER_CREDITS - 300 ))
                            PLAYER_HEALTH=$PLAYER_MAX_HEALTH
                            log_add "${BGREEN}DOC FIX${R} HP full"
                            show_flash_message "${BGREEN}HP restored to ${PLAYER_MAX_HEALTH}!${R}"
                            update_stats
                        else
                            show_flash_message "${BRED}Insufficient credits!${R}"
                        fi
                        ;;
                    2)  # Insider tip
                        if [[ $PLAYER_CREDITS -ge 250 ]]; then
                            PLAYER_CREDITS=$(( PLAYER_CREDITS - 250 ))
                            PLAYER_XP=$(( PLAYER_XP + 50 ))
                            PLAYER_REP=$(( PLAYER_REP + 15 ))
                            log_add "${BCYAN}TIP${R} +50XP +15REP"
                            check_levelup
                            show_flash_message "${BGREEN}Intel acquired! +50 XP, +15 REP${R}"
                            update_stats
                        else
                            show_flash_message "${BRED}Insufficient credits!${R}"
                        fi
                        ;;
                    3)  # Ghost protocol
                        if [[ $PLAYER_CREDITS -ge 1500 ]]; then
                            PLAYER_CREDITS=$(( PLAYER_CREDITS - 1500 ))
                            PLAYER_HEAT=0
                            log_add "${BMAGENTA}GHOST${R} Heat zeroed"
                            show_flash_message "${BGREEN}Ghost Protocol engaged! Heat → 0%%${R}"
                            update_stats
                        else
                            show_flash_message "${BRED}Insufficient credits!${R}"
                        fi
                        ;;
                    4)  # Back
                        return 0
                        ;;
                esac
                ;;
            q|Q) return 0 ;;
        esac
    done
}

# =============================================================================
# RUNNER DOSSIER / STATUS SCREEN
# =============================================================================

show_status() {
    clear_main
    draw_inner_box 11 3 52 12 "RUNNER DOSSIER" "$BCYAN"

    move_to 12 5
    printf "%b" "${BOLD}${BYELLOW}NAME:${R} ${BWHITE}${PLAYER_NAME}${R}"

    move_to 13 5
    printf "%b" "${BCYAN}Level:${R} ${BWHITE}${PLAYER_LEVEL}${R}  "
    printf "%b" "${BCYAN}XP:${R} ${BWHITE}${PLAYER_XP}/${PLAYER_XP_NEXT}${R}  "
    printf "%b" "${BCYAN}Rep:${R} ${BWHITE}${PLAYER_REP}${R}"

    move_to 14 5
    printf "%b" "${BGREEN}Credits:${R} ${BWHITE}¥${PLAYER_CREDITS}${R}  "
    printf "%b" "${BRED}Heat:${R} ${BWHITE}${PLAYER_HEAT}%%${R}  "
    printf "%b" "${BRED}HP:${R} ${BWHITE}${PLAYER_HEALTH}/${PLAYER_MAX_HEALTH}${R}"

    move_to 15 5
    printf "%b" "${BBLACK}Contracts completed: ${BWHITE}${CONTRACTS_COMPLETED}${R}"

    move_to 16 5
    printf "%b" "${BOLD}${BMAGENTA}RIG STATS:${R}"
    move_to 17 7
    printf "%b" "${BBLACK}CPU: ${R}${BWHITE}${RIG_CPU}${R}/5  "
    printf "%b" "${BBLACK}RAM: ${R}${BWHITE}${RIG_RAM}${R}/5  "
    printf "%b" "${BBLACK}STEALTH: ${R}${BWHITE}${RIG_STEALTH}${R}/5"
    move_to 18 7
    printf "%b" "${BBLACK}ICE_BREAK: ${R}${BWHITE}${RIG_ICE_BREAK}${R}/5  "
    printf "%b" "${BBLACK}FIREWALL: ${R}${BWHITE}${RIG_FIREWALL}${R}/5  "
    printf "%b" "${BBLACK}NET_TAP: ${R}${BWHITE}${RIG_NET_TAP}${R}/5"

    move_to 19 5
    printf "%b" "${BOLD}${BBLUE}INSTALLED TOOLS:${R} "
    local any_tool=0
    [[ $TOOL_PHANTOM -eq 1 ]] && { printf "%b" "${BCYAN}PHANTOM.EXE  ${R}"; any_tool=1; }
    [[ $TOOL_BRUTEFORCE -eq 1 ]] && { printf "%b" "${BRED}BRUTE.EXE  ${R}"; any_tool=1; }
    [[ $TOOL_DECRYPT -eq 1 ]] && { printf "%b" "${BGREEN}DECRYPT.EXE  ${R}"; any_tool=1; }
    [[ $TOOL_TRACE_BLOCK -eq 1 ]] && { printf "%b" "${BYELLOW}TBLOCK.EXE  ${R}"; any_tool=1; }
    [[ $TOOL_OVERCLOCK -eq 1 ]] && { printf "%b" "${BMAGENTA}OVERCLOCK.EXE${R}"; any_tool=1; }
    [[ $any_tool -eq 0 ]] && printf "%b" "${BBLACK}None${R}"

    # Reputation rank
    local rank="UNKNOWN"
    [[ $PLAYER_REP -ge 10 ]] && rank="SCRIPT KIDDIE"
    [[ $PLAYER_REP -ge 30 ]] && rank="NETRUNNER"
    [[ $PLAYER_REP -ge 60 ]] && rank="GHOST"
    [[ $PLAYER_REP -ge 100 ]] && rank="PHANTOM"
    [[ $PLAYER_REP -ge 150 ]] && rank="LEGEND"

    move_to 20 5
    printf "%b" "${BOLD}${BYELLOW}RANK: ${BWHITE}${rank}${R}"

    move_to 22 5
    printf "%b" "${BBLACK}[Press any key to continue...]${R}"
    wait_key > /dev/null
}

# =============================================================================
# HELP / TUTORIAL
# =============================================================================

show_help() {
    clear_main
    draw_inner_box 11 3 52 12 "RUNNER'S GUIDE" "$BGREEN"

    local help_lines=(
        "${BOLD}${BYELLOW}CYBER-BREACH: QUICK START${R}"
        ""
        "${BCYAN}CONTRACTS:${R} Accept jobs from the board."
        "  Complete minigames to earn credits & XP."
        ""
        "${BCYAN}MINIGAMES:${R}"
        "  ${BWHITE}Firewall${R}: Memorize & recall a number sequence"
        "  ${BWHITE}ICE Crack${R}: Find target value in hex grid"
        "  ${BWHITE}Cipher${R}:   Decrypt a ROT-encoded message"
        "  ${BWHITE}Trace${R}:    React to keypresses before timeout"
        "  ${BWHITE}Port Scan${R}: Binary search for open port"
        ""
        "${BRED}HEAT:${R} Rises with each run. At 100%% → damage!"
        "  Use Black Market to reduce heat."
    )

    for ((i=0; i<${#help_lines[@]}; i++)); do
        move_to $((12 + i)) 5
        printf "%b" "${help_lines[$i]}${R}"
        [[ $((12 + i)) -ge 22 ]] && break
    done

    move_to 22 5
    printf "%b" "${BBLACK}[Press any key to continue...]${R}"
    wait_key > /dev/null
}

# =============================================================================
# INTRO SEQUENCE
# =============================================================================

show_intro() {
    clear_screen

    local art=(
        "  ██████╗██╗   ██╗██████╗ ███████╗██████╗       "
        " ██╔════╝╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗      "
        " ██║      ╚████╔╝ ██████╔╝█████╗  ██████╔╝      "
        " ██║       ╚██╔╝  ██╔══██╗██╔══╝  ██╔══██╗      "
        " ╚██████╗   ██║   ██████╔╝███████╗██║  ██║      "
        "  ╚═════╝   ╚═╝   ╚═════╝ ╚══════╝╚═╝  ╚═╝      "
        "                                                  "
        " ██████╗ ██████╗ ███████╗ █████╗  ██████╗██╗  ██╗"
        " ██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║"
        " ██████╔╝██████╔╝█████╗  ███████║██║     ███████║"
        " ██╔══██╗██╔══██╗██╔══╝  ██╔══██║██║     ██╔══██║"
        " ██████╔╝██║  ██║███████╗██║  ██║╚██████╗██║  ██║"
        " ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"
    )

    local colors=("$BRED" "$BMAGENTA" "$BBLUE" "$BCYAN" "$BGREEN" "$BYELLOW" "$BWHITE")

    for ((i=0; i<${#art[@]}; i++)); do
        move_to $((3 + i)) 14
        local color_idx=$(( i % ${#colors[@]} ))
        printf "%b" "${BOLD}${colors[$color_idx]}${art[$i]}${R}"
        sleep 0.04
    done

    move_to 17 24
    printf "%b" "${BBLACK}H A C K - R P G   T U I   E D I T I O N${R}"

    move_to 19 30
    printf "%b" "${BCYAN}Initializing DARKNET connection...${R}"

    sleep 0.5

    move_to 20 30
    local conn_chars=("." ".." "..." "....") 
    for c in "${conn_chars[@]}"; do
        move_to 20 30
        printf "%b" "${BGREEN}Connected${c}${R}           "
        sleep 0.3
    done

    move_to 21 30
    printf "%b" "${BYELLOW}>> JACK IN TO BEGIN <<${R}"

    move_to 23 30
    printf "%b" "${BBLACK}[Press any key]${R}"

    wait_key > /dev/null
}

# =============================================================================
# NAME ENTRY
# =============================================================================

get_player_name() {
    clear_screen
    tput cnorm 2>/dev/null || true

    move_to 10 25
    printf "%b" "${BOLD}${BCYAN}┌────────────────────────────┐${R}"
    move_to 11 25
    printf "%b" "${BOLD}${BCYAN}│   RUNNER IDENTIFICATION     │${R}"
    move_to 12 25
    printf "%b" "${BOLD}${BCYAN}│                            │${R}"
    move_to 13 25
    printf "%b" "${BOLD}${BCYAN}│  Enter your handle:        │${R}"
    move_to 14 25
    printf "%b" "${BOLD}${BCYAN}│  > ${R}"
    printf "%b" "${BYELLOW}"

    local name
    read -r name
    name="${name:-Runner}"
    # Sanitize: only allow alphanumeric and basic punctuation
    name=$(echo "$name" | tr -dc '[:alnum:]_.-' | head -c 12)
    [[ -z "$name" ]] && name="Runner"

    PLAYER_NAME="$name"

    move_to 16 25
    printf "%b" "${BGREEN}Handle accepted: ${BYELLOW}${PLAYER_NAME}${R}"
    sleep 1
    tput civis 2>/dev/null || true
}

# =============================================================================
# DEATH SCREEN
# =============================================================================

show_death() {
    clear_screen

    move_to 8 20
    printf "%b" "${BOLD}${BRED}"
    echo "  ██████╗ ███████╗ █████╗ ██████╗ "
    move_to 9 20
    echo " ██╔══██╗██╔════╝██╔══██╗██╔══██╗"
    move_to 10 20
    echo " ██║  ██║█████╗  ███████║██║  ██║"
    move_to 11 20
    echo " ██║  ██║██╔══╝  ██╔══██║██║  ██║"
    move_to 12 20
    echo " ██████╔╝███████╗██║  ██║██████╔╝"
    move_to 13 20
    echo " ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═════╝ "
    printf "%b" "$R"

    move_to 15 22
    printf "%b" "${BRED}Runner ${PLAYER_NAME} flatlined.${R}"

    move_to 16 22
    printf "%b" "${BBLACK}Corps caught up. No second chances in the net.${R}"

    move_to 18 22
    printf "%b" "${BBLACK}Contracts: ${BWHITE}${CONTRACTS_COMPLETED}${R}  "
    printf "%b" "${BBLACK}Level: ${BWHITE}${PLAYER_LEVEL}${R}  "
    printf "%b" "${BBLACK}Credits: ${BWHITE}¥${PLAYER_CREDITS}${R}"

    move_to 20 22
    printf "%b" "${BBLACK}[Press any key to exit]${R}"

    wait_key > /dev/null
    GAME_RUNNING=0
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_main_menu() {
    while true; do
        clear_main

        draw_inner_box 11 3 52 12 "MAIN TERMINAL" "$BCYAN"

        move_to 12 5
        printf "%b" "${BOLD}${BGREEN}CYBER-BREACH NETWORK TERMINAL${R}"
        move_to 13 5
        printf "%b" "${BBLACK}Welcome back, ${BYELLOW}${PLAYER_NAME}${R}${BBLACK}. What's your play?${R}"

        local menu_opts=(
            "▶  Accept Contract       [Hit the streets]"
            "▶  Upgrade Rig           [Soup up your deck]"
            "▶  Black Market          [Underground deals]"
            "▶  Runner Dossier        [Check your status]"
            "▶  Help / Tutorial       [New to the net?]"
            "▶  Jack Out              [Exit game]"
        )

        local selected=0
        local key

        while true; do
            for ((i=0; i<${#menu_opts[@]}; i++)); do
                move_to $((15 + i)) 5
                if [[ $i -eq $selected ]]; then
                    printf "%b" "${BG_BLUE}${BOLD}${BWHITE} %-47s ${R}" "${menu_opts[$i]}"
                else
                    printf " %b%-47s%b" "${WHITE}" "${menu_opts[$i]}" "${R}"
                fi
            done

            # Show heat warning
            if [[ $PLAYER_HEAT -ge 80 ]]; then
                move_to 22 5
                printf "%b" "${BLINK}${BRED}⚠ HEAT CRITICAL: CorpSec may be tracking you!${R}"
            else
                move_to 22 5
                printf "%-48s" ""
            fi

            # Check for death condition
            if [[ $PLAYER_HEALTH -le 0 ]]; then
                show_death
                return 1
            fi

            tput cnorm 2>/dev/null || true
            read -r -s -n 1 key || key=""
            tput civis 2>/dev/null || true

            case "$key" in
                $'\e')
                    read -r -s -n 2 -t 0.1 seq || seq=""
                    case "$seq" in
                        "[A") ((selected > 0)) && selected=$((selected - 1)) ;;
                        "[B") ((selected < ${#menu_opts[@]} - 1)) && selected=$((selected + 1)) ;;
                    esac
                    ;;
                k|K|w|W) ((selected > 0)) && selected=$((selected - 1)) ;;
                j|J|s|S) ((selected < ${#menu_opts[@]} - 1)) && selected=$((selected + 1)) ;;
                $'\n'|$'\r'|"")
                    case $selected in
                        0)
                            show_contracts
                            draw_chrome
                            update_stats
                            update_log
                            break
                            ;;
                        1)
                            show_upgrades
                            draw_chrome
                            update_stats
                            update_log
                            break
                            ;;
                        2)
                            show_black_market
                            draw_chrome
                            update_stats
                            update_log
                            break
                            ;;
                        3)
                            show_status
                            draw_chrome
                            update_stats
                            update_log
                            break
                            ;;
                        4)
                            show_help
                            draw_chrome
                            update_stats
                            update_log
                            break
                            ;;
                        5)
                            GAME_RUNNING=0
                            return 0
                            ;;
                    esac
                    ;;
                q|Q)
                    GAME_RUNNING=0
                    return 0
                    ;;
            esac
        done

        # Check death after every action
        if [[ $PLAYER_HEALTH -le 0 ]]; then
            show_death
            return 1
        fi

        [[ $GAME_RUNNING -eq 0 ]] && return 0
    done
}

# =============================================================================
# AMBIENT EFFECTS (background network noise)
# =============================================================================

draw_ambient_glitch() {
    # Occasionally flash some "network data" in the corners
    local chance=$(( RANDOM % 10 ))
    if [[ $chance -lt 2 ]]; then
        local col=$(( 57 + RANDOM % 20 ))
        local row=$(( RANDOM % 3 + 1 ))
        [[ $row -eq 1 ]] && row=2  # Don't overwrite header
        # Commented out: Can cause visual artifacts in some terminals
        # move_to "$row" "$col"
        # printf "%b" "${BBLACK}$(printf '%02X' $((RANDOM % 256)))${R}"
        true
    fi
}

# =============================================================================
# MAIN GAME LOOP
# =============================================================================

main() {
    # Check terminal size
    if [[ $TERM_WIDTH -lt 80 || $TERM_HEIGHT -lt 25 ]]; then
        tput rmcup 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        echo "ERROR: Terminal must be at least 80x25 (current: ${TERM_WIDTH}x${TERM_HEIGHT})"
        echo "Please resize your terminal and try again."
        exit 1
    fi

    # Check for required tools
    for cmd in tput printf read sleep date; do
        if ! command -v "$cmd" &>/dev/null; then
            tput rmcup 2>/dev/null || true
            tput cnorm 2>/dev/null || true
            echo "ERROR: Required command not found: $cmd"
            exit 1
        fi
    done

    # Show intro
    show_intro

    # Get player name
    get_player_name

    # Initialize display
    draw_chrome
    update_stats

    # Welcome log messages
    log_add "${BGREEN}SYS:${R} DARKNET connected"
    log_add "${BGREEN}SYS:${R} Runner identified"
    log_add "${BYELLOW}SYS:${R} Rig online"
    log_add "${BBLACK}SYS:${R} Awaiting orders..."

    # Main game loop
    while [[ $GAME_RUNNING -eq 1 ]]; do
        show_main_menu

        # Check for quit
        [[ $GAME_RUNNING -eq 0 ]] && break

        # Check death
        if [[ $PLAYER_HEALTH -le 0 ]]; then
            show_death
            break
        fi

        # Ambient heat decay (slow natural cooldown)
        if [[ $PLAYER_HEAT -gt 0 && $((CONTRACTS_COMPLETED % 3)) -eq 0 ]]; then
            PLAYER_HEAT=$(( PLAYER_HEAT - 1 ))
            [[ $PLAYER_HEAT -lt 0 ]] && PLAYER_HEAT=0
        fi
    done

    # Final goodbye screen
    if [[ $PLAYER_HEALTH -gt 0 ]]; then
        clear_screen
        move_to 10 25
        printf "%b" "${BOLD}${BCYAN}╔══════════════════════════════╗${R}"
        move_to 11 25
        printf "%b" "${BOLD}${BCYAN}║    JACKING OUT...            ║${R}"
        move_to 12 25
        printf "%b" "${BOLD}${BCYAN}╠══════════════════════════════╣${R}"
        move_to 13 25
        printf "%b" "${BOLD}${BCYAN}║  ${BYELLOW}Runner: %-20s${BCYAN}  ║${R}" "$PLAYER_NAME"
        move_to 14 25
        printf "%b" "${BOLD}${BCYAN}║  ${BGREEN}Level:  %-20s${BCYAN}  ║${R}" "$PLAYER_LEVEL"
        move_to 15 25
        printf "%b" "${BOLD}${BCYAN}║  ${BGREEN}Credits:¥%-19s${BCYAN}  ║${R}" "$PLAYER_CREDITS"
        move_to 16 25
        printf "%b" "${BOLD}${BCYAN}║  ${BWHITE}Runs:   %-20s${BCYAN}  ║${R}" "$CONTRACTS_COMPLETED"
        move_to 17 25
        printf "%b" "${BOLD}${BCYAN}╚══════════════════════════════╝${R}"
        sleep 2
    fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

main "$@"