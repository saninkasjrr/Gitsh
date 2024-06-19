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

# Function to display files and get user selection using ANSI sequences
select_files() {
  files=($(git status --short | awk '{print $2}'))
  if [ ${#files[@]} -eq 0 ]; then
    echo "No files to select."
    exit 1
  fi

  selected_files=()
  selected_indices=()

  while true; do
    clear
    echo -e "${GREEN}Select files to add (Press ${YELLOW}Enter${GREEN} to confirm):${RESET}"
    for i in "${!files[@]}"; do
      if [[ "${selected_indices[@]}" =~ $i ]]; then
        echo -e " ${GREEN}▶${RESET} ${files[$i]}"
      else
        echo -e "   ${files[$i]}"
      fi
    done

    read -rsn1 key
    case "$key" in
      '[A') # Up arrow
        if [ ${#selected_indices[@]} -eq 0 ]; then
          selected_indices=("${!files[@]}")
        elif [ ${selected_indices[0]} -gt 0 ]; then
          selected_indices=($(( ${selected_indices[@]/%/ - 1} )))
        fi
        ;;
      '[B') # Down arrow
        if [ ${#selected_indices[@]} -eq 0 ]; then
          selected_indices=("${!files[@]}")
        elif [ ${selected_indices[-1]} -lt $(( ${#files[@]} - 1 )) ]; then
          selected_indices=($(( ${selected_indices[@]/%/ + 1} )))
        fi
        ;;
      '') # Enter key
        for index in "${selected_indices[@]}"; do
          selected_files+=("${files[$index]}")
        done
        return
        ;;
      *)
        ;;
    esac
  done
}

# Function to handle branch management
branch_management() {
  current_branch=$(git branch --show-current)
  echo -e "${GREEN}Current branch:${RESET} $current_branch"
  
  PS3="${GREEN}Select branch action:${RESET} "
  options=("Switch Branch" "Create New Branch" "Skip")
  select opt in "${options[@]}"
  do
    case $REPLY in
      1)
        read -p "${GREEN}Enter the branch name to switch to:${RESET} " branch_name
        git checkout "$branch_name"
        break
        ;;
      2)
        read -p "${GREEN}Enter the new branch name:${RESET} " branch_name
        git checkout -b "$branch_name"
        break
        ;;
      3)
        echo "${YELLOW}No branch changes.${RESET}"
        break
        ;;
      *)
        echo "${RED}Invalid option. No branch changes.${RESET}"
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

# Function to display the main menu using ANSI sequences
main_menu() {
  clear
  while true; do
    echo -e "${CYAN}Git Operations Menu:${RESET}"
    PS3="${GREEN}Select an operation:${RESET} "
    options=("Add and Commit Changes" "Push Changes" "Branch Management" "Fetch Latest Changes" "Show Git Status" "Exit")
    select opt in "${options[@]}"
    do
      case $REPLY in
        1)
          echo -e "${GREEN}Adding and Committing Changes...${RESET}"
          if (echo -e "${YELLOW}Do you want to add all changes? (y/n, default is y):${RESET} \c" && read -r && [[ "$REPLY" == [Yy] ]] || [[ -z "$REPLY" ]]); then
            git add .
          else
            select_files
            if [ ${#selected_files[@]} -eq 0 ]; then
              echo -e "${RED}No valid files selected. Exiting.${RESET}"
              exit 1
            fi
            git add "${selected_files[@]}"
          fi

          read -p "${GREEN}Enter commit message (leave empty to open editor):${RESET} " commit_message
          if [ -z "$commit_message" ]; then
            git commit
          else
            git commit -m "$commit_message"
          fi
          log_operation "Changes committed with message: $commit_message"
          break 2
          ;;
        2)
          echo -e "${GREEN}Pushing Changes...${RESET}"
          read -p "${GREEN}Enter the remote to push to (default is 'origin'):${RESET} " remote
          remote=${remote:-origin}

          read -p "${GREEN}Enter the branch to push to (default is current branch):${RESET} " branch
          branch=${branch:-$(git branch --show-current)}

          git push "$remote" "$branch"
          log_operation "Changes pushed to $remote/$branch"
          break 2
          ;;
        3)
          echo -e "${GREEN}Branch Management...${RESET}"
          branch_management
          break 2
          ;;
        4)
          echo -e "${GREEN}Fetching Latest Changes...${RESET}"
          fetch_latest
          break 2
          ;;
        5)
          echo -e "${GREEN}Current git status:${RESET}"
          git status
          break 2
          ;;
        6)
          echo -e "${YELLOW}Exiting...${RESET}"
          exit 0
          ;;
        *)
          echo -e "${RED}Invalid choice, please select a valid option.${RESET}"
          ;;
      esac
    done
  done
}

# Main script
main_menu
