#!/bin/bash

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

# ===== Main =====
# Example output
main() {
    tui_init
    options=("Start" "Settings" "About" "Exit")
    draw_menu selection "Title" "Use ↑/↓ to move, Enter to select, q to quit." "${options[@]}" 
    tui_cleanup
}
# ================

# Run guard
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
