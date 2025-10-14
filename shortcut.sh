#!/bin/bash

# Source the tui script
source bash_tui.sh

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
