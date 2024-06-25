#!/bin/bash

# ANSI escape codes for colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m' # No Color

# Function to display a menu with arrow key navigation
display_menu() {
    local options=("$@")
    local selected=0
    local key

    while true; do
        clear
        echo -e "${GREEN}Use arrow keys to navigate, Enter to select:${RESET}"
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e " ${CYAN}▶${RESET} ${options[$i]}"
            else
                echo "   ${options[$i]}"
            fi
        done

        read -rsn3 key
        case "$key" in
            $'\x1b[A') # Up arrow
                ((selected--))
                [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
                ;;
            $'\x1b[B') # Down arrow
                ((selected++))
                [ $selected -ge ${#options[@]} ] && selected=0
                ;;
            '') # Enter key
                return $selected
                ;;
        esac
    done
}

# Function to select files with modern navigation
select_files() {
    local files=($(git status --short | awk '{print $2}'))
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${RED}No files to select.${RESET}"
        return 1
    fi

    local selected_files=()
    local selected=0
    local key

    while true; do
        clear
        echo -e "${GREEN}Select files to add (Press ${YELLOW}Enter${GREEN} to confirm, ${YELLOW}Space${GREEN} to toggle):${RESET}"
        for i in "${!files[@]}"; do
            if [[ " ${selected_files[@]} " =~ " ${files[$i]} " ]]; then
                prefix="${CYAN}[x]${RESET}"
            else
                prefix="[ ]"
            fi
            if [ $i -eq $selected ]; then
                echo -e " ${CYAN}▶${RESET} $prefix ${files[$i]}"
            else
                echo "   $prefix ${files[$i]}"
            fi
        done

        read -rsn1 key
        case "$key" in
            $'\x1b') # Detect escape sequence
                read -rsn2 -t 0.1 key # Read remaining two characters
                case "$key" in
                    '[A') # Up arrow
                        ((selected--))
                        [ $selected -lt 0 ] && selected=$((${#files[@]} - 1))
                        ;;
                    '[B') # Down arrow
                        ((selected++))
                        [ $selected -ge ${#files[@]} ] && selected=0
                        ;;
                esac
                ;;
            '') # Enter key
                break
                ;;
            ' ') # Space key
                if [[ " ${selected_files[@]} " =~ " ${files[$selected]} " ]]; then
                    selected_files=(${selected_files[@]/${files[$selected]}})
                else
                    selected_files+=("${files[$selected]}")
                fi
                ;;
        esac
    done

    echo "${selected_files[@]}"
}

# Function to handle branch management with improved navigation
branch_management() {
    while true; do
        clear
        echo -e "${GREEN}Current branch:${RESET} $(git branch --show-current)"
        
        options=("Switch Branch" "Create New Branch" "Skip")
        display_menu "${options[@]}"
        choice=$?

        case $choice in
            0) # Switch Branch
                echo -e "${GREEN}Available branches:${RESET}"
                branches=($(git branch -a | awk '!/HEAD|->|remotes\/origin/ {gsub(/^\*/, "", $0); print $0}'))
                display_menu "${branches[@]}"
                branch_number=$?
                branch_name=${branches[$branch_number]}
                if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
                    echo -e "${RED}Invalid branch name. Please try again.${RESET}"
                else
                    git checkout "$branch_name"
                    break
                fi
                ;;
            1) # Create New Branch
                read -p "$(echo -e "${GREEN}Enter the new branch name:${RESET} ")" branch_name
                if [ -z "$branch_name" ]; then
                    echo -e "${RED}Branch name cannot be empty. Please try again.${RESET}"
                else
                    if ! git checkout -b "$branch_name" 2>/dev/null; then
                        echo -e "${RED}fatal: '$branch_name' is not a valid branch name${RESET}"
                    else
                        break
                    fi
                fi
                ;;
            2) # Skip
                echo -e "${YELLOW}No branch changes.${RESET}"
                break
                ;;
        esac
    done
}

# Function to fetch the latest changes from the remote
fetch_latest() {
    git fetch
    echo -e "${GREEN}Fetched the latest changes from the remote.${RESET}"
}

# Function to log operations
log_operation() {
    echo "$(date): $1" >> git-auto.log
}

# Function to add and commit changes
add_commit_changes() {
    if (echo -e "${YELLOW}Do you want to add all changes? (y/n, default is y):${RESET} \c" && read -r && [[ "$REPLY" == [Yy] ]] || [[ -z "$REPLY" ]]); then
        git add .
    else
        select_files
        if [ ${#selected_files[@]} -eq 0 ]; then
            echo -e "${RED}No valid files selected. Exiting.${RESET}"
            return 1
        fi
        git add "${selected_files[@]}"
    fi

    echo -e "${GREEN}Enter commit message (leave empty to skip commit or use -m/-F to supply the message directly):${RESET}"
    read -r commit_message

    if [ -z "$commit_message" ]; then
        echo -e "${YELLOW}Skipping commit.${RESET}"
        return
    else
        git commit -m "$commit_message" || {
            echo -e "${RED}Error: Unable to commit. Please supply the message using either -m or -F option.${RESET}"
            return 1
        }
    fi

    log_operation "Changes committed with message: $commit_message"
}

# Function to push changes
push_changes() {
    remote=${1:-origin}  # Default to 'origin' if no argument provided
    branch=$(git branch --show-current)

    git push "$remote" "$branch"
    log_operation "Changes pushed to $remote/$branch"
}

# Function to interact with a specific commit
interact_with_commit() {
    commit_hash=$1
    while true; do
        clear
        echo -e "${GREEN}Commit details:${RESET}"
        git show "$commit_hash"
        options=("Revert Commit" "Delete Commit" "Back to Commit List")
        display_menu "${options[@]}"
        choice=$?

        case $choice in
            0)
                git revert "$commit_hash"
                echo -e "${GREEN}Commit reverted.${RESET}"
                log_operation "Reverted commit: $commit_hash"
                return
                ;;
            1)
                git reset --hard "$commit_hash^"
                echo -e "${GREEN}Commit deleted.${RESET}"
                log_operation "Deleted commit: $commit_hash"
                return
                ;;
            2)
                return
                ;;
        esac
    done
}

# Function to view and interact with recent commits
view_commits() {
    local commits=()
    local commit_count=10  # Number of commits to display initially
    local offset=0         # Offset to fetch additional commits
    local view_all_commits=false  # Flag to track current view state (false = show recent commits)

    while true; do
        if ! $view_all_commits; then
            mapfile -t commits < <(git log --skip="$offset" --pretty=format:"%h %an %s" -n "$commit_count")
        else
            mapfile -t commits < <(git log --pretty=format:"%h %an %s")
            offset=0
        fi

        if [ ${#commits[@]} -eq 0 ]; then
            echo -e "${RED}No commits to display.${RESET}"
            return
        fi

        clear
        echo -e "${GREEN}Recent commits:${RESET}"
        for i in "${!commits[@]}"; do
            echo "$i) ${commits[$i]}"
        done

        # Prompt for commit number or options
        if ! $view_all_commits; then
            echo -e "${GREEN}extra:${RESET} x) View newer commits  y) View older commits  z) View all commits"
        else
            echo -e "${GREEN}extra:${RESET} x) View newer commits  y) View older commits  z) View recent commits"
        fi
        echo -ne "${GREEN}Enter the commit number to view details, or extra (x, y, z), or press Enter to go back:${RESET} "
        read -r input

        if [ -z "$input" ]; then
            return
        fi

        case "$input" in
            x)
                view_all_commits=false
                continue
                ;;
            y)
                view_all_commits=true
                continue
                ;;
            z)
                view_all_commits=!$view_all_commits
                continue
                ;;
            [0-9]*)
                if [ "$input" -ge ${#commits[@]} ]; then
                    echo -e "${RED}Commit number out of range. Please try again.${RESET}"
                    continue
                fi
                commit_info="${commits[$input]}"
                commit_hash=$(echo "$commit_info" | awk '{print $1}')
                interact_with_commit "$commit_hash"
                ;;
            *)
                echo -e "${RED}Invalid input. Please enter a valid commit number or option.${RESET}"
                continue
                ;;
        esac
    done
}

handle_error() {
    echo -e "${RED}An error occurred. Please check the details above.${RESET}"
    exit 1
}

stash_changes() {
    git stash
    echo -e "${GREEN}Changes stashed.${RESET}"
    log_operation "Changes stashed"
}

pull_latest() {
    git pull
    echo -e "${GREEN}Pulled the latest changes from the remote.${RESET}"
    log_operation "Pulled latest changes"
}

merge_branches() {
    echo -e "${GREEN}Available branches:${RESET}"
    branches=($(git branch -a | awk '!/HEAD|->|remotes\/origin/ {gsub(/^\*/, "", $0); print $0}'))
    display_menu "${branches[@]}"
    branch_number=$?
    branch_name=${branches[$branch_number]}
    
    if ! git merge "$branch_name"; then
        while true; do
            echo -e "${RED}Merge conflict detected or an error occurred. Please select an option to proceed:${RESET}"
            options=("Stash changes and retry merge" "Abort merge" "Manual conflict resolution" "Return to main menu")
            display_menu "${options[@]}"
            choice=$?

            case $choice in
                0)
                    git stash
                    echo -e "${GREEN}Changes stashed. Retrying merge...${RESET}"
                    if git merge "$branch_name"; then
                        echo -e "${GREEN}Merge successful.${RESET}"
                        log_operation "Merged branch $branch_name after stashing changes"
                        return
                    else
                        echo -e "${RED}Merge conflict detected again.${RESET}"
                    fi
                    ;;
                1)
                    git merge --abort
                    echo -e "${YELLOW}Merge aborted.${RESET}"
                    return
                    ;;
                2)
                    echo -e "${YELLOW}Please resolve conflicts manually and commit the changes.${RESET}"
                    return
                    ;;
                3)
                    echo -e "${YELLOW}Returning to main menu...${RESET}"
                    return
                    ;;
            esac
        done
    else
        echo -e "${GREEN}Merged branch ${branch_name} into $(git branch --show-current).${RESET}"
        log_operation "Merged branch $branch_name"
    fi
}

rebase_branch() {
    echo -e "${GREEN}Available branches:${RESET}"
    branches=($(git branch -a | awk '!/HEAD|->|remotes\/origin/ {gsub(/^\*/, "", $0); print $0}'))
    display_menu "${branches[@]}"
    branch_number=$?
    branch_name=${branches[$branch_number]}
    
    if ! git rebase "$branch_name"; then
        echo -e "${RED}Rebase conflict detected. Please resolve conflicts and continue rebase manually.${RESET}"
    else
        echo -e "${GREEN}Rebased current branch onto ${branch_name}.${RESET}"
        log_operation "Rebased onto $branch_name"
    fi
}

# Function to display Git configuration
display_git_config() {
    clear
    echo -e "${GREEN}Current Git Configuration:${RESET}"
    git config --list

    echo -e "${YELLOW}\nPress any key to return to menu.${RESET}"
    read -rsn1
}

# Function to display help message
display_help() {
    echo -e "${GREEN}Usage: ${0} [option] [arguments]${RESET}"
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  ${BLUE}1${RESET}                    Add and commit changes"
    echo -e "  ${BLUE}2 <remote>${RESET}           Push changes (default: origin)"
    echo -e "  ${BLUE}3${RESET}                    Branch management"
    echo -e "  ${BLUE}4${RESET}                    Fetch latest changes"
    echo -e "  ${BLUE}5${RESET}                    View recent commits"
    echo -e "  ${BLUE}6${RESET}                    Pull latest changes"
    echo -e "  ${BLUE}7 <branch>${RESET}           Merge branch into current branch"
    echo -e "  ${BLUE}8 <branch>${RESET}           Rebase current branch onto specified branch"
    echo -e "  ${BLUE}9${RESET}                    Stash changes"
    echo -e "  ${BLUE}10${RESET}                   Display Git config"
    echo -e "  ${BLUE}11 <commit>${RESET}          Interact with a specific commit"
    echo -e "  ${BLUE}12${RESET}                   Display this help message"
    echo -e "  ${BLUE}13${RESET}                   Exit"
}

# Function to validate branch name
validate_branch() {
    if ! git rev-parse --verify "$1" >/dev/null 2>&1; then
        echo -e "${RED}Invalid branch name: $1${RESET}"
        exit 1
    fi
}

# Function to validate commit hash
validate_commit() {
    if ! git cat-file -e "$1" 2>/dev/null; then
        echo -e "${RED}Invalid commit hash: $1${RESET}"
        exit 1
    fi
}

# Function to validate options and arguments
validate_arguments() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: No option provided.${RESET}"
        display_help
        exit 1
    fi
}

# Function to execute a command and handle errors
# Function to execute a command and handle errors
execute_command() {
    if ! "$@"; then
        echo -e "${RED}Error: Command failed: $*${RESET}"
        exit 1
    fi
}

# Function to handle shorthand command line arguments
handle_arguments() {
    validate_arguments "$1"
    case $1 in
        1)
            add_commit_changes
            ;;
        2)
            shift
            remote="${1:-origin}"
            execute_command push_changes "$remote"
            ;;
        3)
            branch_management
            ;;
        4)
            fetch_latest
            ;;
        5)
            view_commits
            ;;
        6)
            pull_latest
            ;;
        7)
            shift
            if [ -z "$1" ]; then
                echo -e "${RED}Error: No branch specified for merging.${RESET}"
                exit 1
            fi
            validate_branch "$1"
            execute_command merge_branches "$1"
            ;;
        8)
            shift
            if [ -z "$1" ]; then
                echo -e "${RED}Error: No branch specified for rebasing.${RESET}"
                exit 1
            fi
            validate_branch "$1"
            execute_command rebase_branch "$1"
            ;;
        9)
            stash_changes
            ;;
        10)
            display_git_config
            ;;
        11)
            shift
            if [ -z "$1" ]; then
                echo -e "${RED}Error: No commit hash specified.${RESET}"
                exit 1
            fi
            validate_commit "$1"
            execute_command interact_with_commit "$1"
            ;;
        12)
            display_help
            ;;
        13)
            echo -e "${YELLOW}Exiting...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid argument: $1${RESET}"
            display_help
            exit 1
            ;;
    esac
}

main_menu() {
    while true; do
        clear
        current_branch=$(git branch --show-current)
        echo -e "${GREEN}Current branch:${RESET} $current_branch"

        options=(
            "Add and Commit Changes"
            "Push Changes"
            "Branch Management"
            "Fetch Latest Changes"
            "Pull Latest Changes"
            "View Recent Commits"
            "Merge Branches"
            "Rebase Branch"
            "Stash Changes"
            "Display Git Config"
            "Exit"
        )
        display_menu "${options[@]}"
        choice=$?

        case $choice in
            0) add_commit_changes ;;
            1) push_changes ;;
            2) branch_management ;;
            3) fetch_latest ;;
            4) pull_latest ;;
            5) view_commits ;;
            6) merge_branches ;;
            7) rebase_branch ;;
            8) stash_changes ;;
            9) display_git_config ;;
            10) echo -e "${YELLOW}Exiting...${RESET}"; exit 0 ;;
        esac
    done
}

# Main script
if [ $# -eq 0 ]; then
    main_menu
else
    handle_arguments "$@"
fi
