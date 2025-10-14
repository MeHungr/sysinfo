#!/bin/bash

# ===== ANSI Colors =====
green=$'\e[32m'
yellow=$'\e[33m'
red=$'\e[31m'
reset=$'\e[0m'
bold=$'\e[1m'
underline=$'\e[4m'
# =======================

# ===== Helpers =====
draw_banner() {
    local title=$1
    local total_width=$((COLUMNS / 3))
    local spaces=$(printf "%*s" $total_width "")
    local stars=$(echo "${spaces// /*}")
    local padding=$(((total_width - ${#title} - 2) / 2)) # Subtract 2 for space on either side of text
    local left=$(printf "%*s" "$padding" "" | tr ' ' '*')
    local right=$(printf "%*s" "$padding" "" | tr ' ' '*')
    # If the text is odd width, add another * to the right side
    # I know the logic looks really stupid
    [ $(( (total_width - ${#title} - 2) % 2 )) -ne 0 ] && right="${right}*"
    cat <<EOF
${spaces}${stars}
$(printf "%*s%s " $(((COLUMNS - total_width) / 2)) "" "$left")${green}${title}${reset} ${right}
${spaces}${stars}
EOF
}

# Default help text
default_help="Use ↑/↓ to move, Enter to select, q to quit."
# ===================

# ===== Core functions =====
# Gets the size of the terminal
get_term_size() {
    read -r LINES COLUMNS < <(stty size)
}

# Hides the terminal cursor
hide_cursor() {
    printf '\e[?25l'
}

# Shows the terminal cursor
show_cursor() {
    printf '\e[?25h'
}

# Moves the cursor to 0 0
zero_cursor() {
    printf '\e[H'
}

# Moves the cursor to <row> <col>
move_cursor() {
    if [ $# -ne 2 ]; then
        return 1
    fi
    local row="$1" col="$2"
    printf '\e[%s;%sH' "$1" "$2"
}

# Moves the cursor to the bottom of the terminal
floor_cursor() {
    printf '\e[%sH' "$LINES"
}

# Moves the cursor up by the first argument lines or 1 by default
cursor_up() {
    if [ $# -eq 0 ]; then
        printf '\e[A'
    elif [ $# -eq 1 ]; then
        printf '\e[%sA' "$1"
    else
        return 1
    fi
}

# Moves the cursor right by the first argument lines or 1 by default
cursor_right() {
    if [ $# -eq 0 ]; then
        printf '\e[C'
    elif [ $# -eq 1 ]; then
        printf '\e[%sC' "$1"
    else
        return 1
    fi
}

# Moves the cursor down by the first argument lines or 1 by default
cursor_down() {
    if [ $# -eq 0 ]; then
        printf '\e[B'
    elif [ $# -eq 1 ]; then
        printf '\e[%sB' "$1"
    else
        return 1
    fi
}

# Moves the cursor left by the first argument lines or 1 by default
cursor_left() {
    if [ $# -eq 0 ]; then
        printf '\e[D'
    elif [ $# -eq 1 ]; then
        printf '\e[%sD' "$1"
    else
        return 1
    fi
}

# Clears the screen
clear_screen() {
    printf '\e[2J'
}

# Limits the terminal scrolling space from line $1 to $2
limit_scroll() {
    if [ $# -eq 2 ]; then
        printf '\e[%s;%sr' "$1" "$2"
    else
        return 1
    fi
}

# Resets the terminal scrolling space
reset_scroll() {
    printf '\e[;r'
}

# Saves the user's terminal screen
save_terminal() {
    printf '\e[?1049h'
}

# Restore the user's terminal screen
restore_terminal() {
    printf '\e[?1049l'
}

# Initialize the tui
tui_init() {
    save_terminal
    hide_cursor
    clear_screen
    get_term_size
    trap 'tui_cleanup' EXIT
    trap 'get_term_size' WINCH
}

# Reads a single key of input
read_key() {
    local key
    IFS= read -rsn1 key
    printf "%s" "$key"
}

# Clean up and restore the terminal
tui_cleanup() {
    reset_scroll
    show_cursor
    restore_terminal
}

inverse_printf() {
    if [ $# -eq 1 ]; then
        printf '\e[7m%s\e[0m\n' "$1"
    else
        return 1
    fi
}

draw_menu() {
    local resultvar=$1; shift
    local title=$1; shift
    local help=$1; shift
    local options=("$@") # All args
    local selected=0 # Default to first arg
    local key # keypress var
    
    while true; do
        clear_screen
        zero_cursor

        echo "$title"
        echo # Newline
        
        # Draw options
        for index in "${!options[@]}"; do
            if [ "$index" -eq "$selected" ]; then
                inverse_printf "${options[$index]}"
            else
                printf "%s\n" "${options[$index]}"
            fi
        done

        echo # Newline
        echo "$help"

        # Read key
        key=$(read_key)
        case "$key" in
            $'\x1b') # Escape sequence for arrow keys
                read -rsn2 key # Read the next 2 chars for arrow keys
                case "$key" in
                    "[A") ((selected--)) ;; # Move up
                    "[B") ((selected++)) ;; # Move down
                esac
                ;;
            "") # Enter
                clear_screen
                # Write output to resultvar
                printf -v "$resultvar" "%s" "${options[$selected]}"
                return
                ;;
            q)
                printf -v "$resultvar" "%s" "q"
                break
                ;;
        esac

        # Wrap around
        ((selected < 0)) && selected=$((${#options[@]} - 1))
        ((selected >= ${#options[@]})) && selected=0
    done
                
}

# ==========================

# ===== Handlers =====
# Generates a symlink for a file
handle_create() {
    zero_cursor
    printf "Please enter the filename to create a shortcut to: "
    read -r filename
    if [ "$EUID" -ne 0 ]; then
        results=$(sudo find / -name "$filename" 2>/dev/null)
    else
        results=$(find / -name "$filename" 2>/dev/null)
    fi
    if [ -z "$results" ]; then
        printf "Sorry, couldn't find %s%s%s%s!\n" "$bold" "$green" "$filename" "$reset"
        sleep 2
    else
        mapfile -t files <<< "$results"
        if [ ${#files[@]} -eq 1 ]; then
            draw_menu \
                selection \
                "$(printf "Found %s%s%s%s. Create symlink?" "$bold" "$green" "${files[0]}" "$reset")" \
                "$(sed 's/quit/return to main menu/g' <<< $default_help)" \
                "Yes" "No"
            zero_cursor
            case "$selection" in
                "Yes")
                    ln -sf "${files[0]}" "${HOME}/Desktop/$(basename "${files[0]}")"
                    echo "Shortcut created. Returning to Main Menu."
                    sleep 1
                    break
                    ;;
                "No")
                    ;;
                q)
                    break
                    ;;
            esac
        else
            draw_menu \
                selection \
                "$(printf "Multiple files with the name \"%s%s%s%s\" were found. Select the file you would like to create a shortcut for:" "$bold" "$green" "$filename" "$reset")" \
                "$(sed 's/quit/return to main menu/g' <<< $default_help)" \
                "${files[@]}"
            zero_cursor
            case "$selection" in
                q)
                    break
                    ;;
                *)
                    ln -sf "$selection" "${HOME}/Desktop/$(basename "$selection")"
                    echo "Shortcut created. Returning to Main Menu."
                    sleep 1
                    break
                    ;;
            esac
        fi
    fi
}

# Deletes a symlink for the user
handle_delete() {
    zero_cursor
    printf "Please enter the shortcut/link to remove: "
    read -r filename
    results=$(find "${HOME}/Desktop" -type l -name "$filename" 2>/dev/null)
    if [ -z "$results" ]; then
        printf "Sorry, couldn't find %s%s%s%s!\n" "$bold" "$red" "$filename" "$reset"
        sleep 2
    else
        draw_menu \
            selection \
            "$(printf "Are you sure you want to remove %s%s%s%s?" \
            "$bold" "$green" "$filename" "$reset")" \
            "$default_help" \
            "Yes" "No"
        zero_cursor
        case "$selection" in
            "Yes")
                unlink "${HOME}/Desktop/$(basename "$filename")"
                echo "Link removed, returning to Main Menu."
                sleep 1
                ;;
            "No")
                ;;
        esac
    fi
}

# Generates a report of symlinks for the user
generate_report() {
    mapfile -t report_options < <(find "${HOME}/Desktop" -type l 2>/dev/null)
    local menu_items=()
    for path in "${report_options[@]}"; do
        name=$(basename "$path")
        menu_items+=("$(printf "%-20s%s" "$name" "$(readlink -f "$path")")")
    done

    # Info header (no color codes inside printf width fields)
    local header
    local col1="Symbolic Link"
    local col2="Target Path"
    local title="Shortcut Report"
    header=$(
        cat <<EOF
$(draw_banner "$title")

Your current directory is ${yellow}$(pwd)${reset}.


The number of links is ${yellow}${#menu_items[@]}${reset}.

${underline}${yellow}${col1}${reset}$(printf "%*s" $((20 - ${#col1})) "")${underline}${yellow}Target Path${reset}
EOF
    )
    draw_menu selection "$header" "Use ↑/↓ to move, Enter to delete a symlink, q to return to main menu." "${menu_items[@]}"
    local filename="$(awk '{ print $1 }' <<< "$selection")"
    case "$selection" in
        q)
            return
            ;;
        *)
            draw_menu \
                selection \
                "$(printf "Are you sure you want to remove %s%s%s%s?" \
                "$bold" "$green" "$filename" "$reset")" \
                "$default_help" \
                "Yes" "No"
            zero_cursor
            case "$selection" in
                "Yes")
                    unlink "${HOME}/Desktop/$(basename "$filename")"
                    echo "Link removed, returning to Main Menu."
                    sleep 1
                    ;;
                "No")
                    ;;
            esac
    esac
}
# ====================

# ===== Main =====
main() {
    tui_init
    options=( \
        "Create a shortcut in your home directory" \
        "Remove a shortcut from your home directory" \
        "Run shortcut report" \
    )
    while true; do
        draw_menu selection "$(draw_banner "Shortcut Creator")" "$default_help" "${options[@]}"
        case "$selection" in
            "Create a shortcut in your home directory") 
                handle_create
                ;;
            "Remove a shortcut from your home directory")
                handle_delete
                ;;
            "Run shortcut report")
                generate_report
                ;;
            q)
                break
                ;;
        esac
    done
    tui_cleanup
}
# ================

main
