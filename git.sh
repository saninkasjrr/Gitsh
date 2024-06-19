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
  while true; do
    echo -e "${GREEN}Current branch:${RESET} $(git branch --show-current)"
    
    PS3="Select branch action: "
    options=("Switch Branch" "Create New Branch" "Skip")
    select opt in "${options[@]}"
    do
      case $REPLY in
        1)
          echo -e "${GREEN}Available branches:${RESET}"
          branches=($(git branch -a | sed 's/\*//g' | awk '{print $1}'))
          for i in "${!branches[@]}"; do
            echo "$i) ${branches[$i]}"
          done
          read -p "${GREEN}Enter the branch number to switch to:${RESET} " branch_number
          branch_name=${branches[$branch_number]}
          if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
            echo "${RED}Invalid branch name. Please try again.${RESET}"
          else
            git checkout "$branch_name"
            break 2
          fi
          ;;
        2)
          read -p "${GREEN}Enter the new branch name:${RESET} " branch_name
          if [ -z "$branch_name" ]; then
            echo "${RED}Branch name cannot be empty. Please try again.${RESET}"
          else
            git checkout -b "$branch_name"
            break 2
          fi
          ;;
        3)
          echo "${YELLOW}No branch changes.${RESET}"
          break 2
          ;;
        *)
          echo "${RED}Invalid option. Please select a valid option.${RESET}"
          break
          ;;
      esac
    done
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
    echo -e "${GREEN}Commit details:${RESET}"
    git show "$commit_hash"
    echo -e "${GREEN}Choose an action:${RESET}"
    PS3="Select commit action: "
    options=("Revert Commit" "Delete Commit" "Back to Commit List")
    select opt in "${options[@]}"
    do
      case $REPLY in
        1)
          git revert "$commit_hash"
          echo -e "${GREEN}Commit reverted.${RESET}"
          log_operation "Reverted commit: $commit_hash"
          return
          ;;
        2)
          git reset --hard "$commit_hash^"
          echo -e "${GREEN}Commit deleted.${RESET}"
          log_operation "Deleted commit: $commit_hash"
          return
          ;;
        3)
          return
          ;;
        *)
          echo -e "${RED}Invalid option. Please select a valid option.${RESET}"
          ;;
      esac
    done
  done
}

# Function to view and interact with recent commits
view_commits() {
  commits=($(git log --pretty=format:"%h" -n 10))
  if [ ${#commits[@]} -eq 0 ]; then
    echo -e "${RED}No commits to display.${RESET}"
    return
  fi

  while true; do
    echo -e "${GREEN}Recent commits:${RESET}"
    for i in "${!commits[@]}"; do
      echo "$i) ${commits[$i]}"
    done
    read -p "Enter the commit number to view details or press Enter to go back: " commit_number
    if [ -z "$commit_number" ]; then
      return
    fi
    if ! [[ "$commit_number" =~ ^[0-9]+$ ]] || [ "$commit_number" -ge ${#commits[@]} ]; then
      echo -e "${RED}Invalid commit number. Please try again.${RESET}"
      continue
    fi
    interact_with_commit "${commits[$commit_number]}"
  done
}

# Function to handle shorthand command line arguments
handle_arguments() {
  case $1 in
    1)
      add_commit_changes
      ;;
    2)
      shift  # Remove the first argument (operation number)
      push_changes "$@"
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
    *)
      echo -e "${RED}Invalid argument. Please specify a valid operation.${RESET}"
      exit 1
      ;;
  esac
}

# Main menu function
main_menu() {
  clear
  while true; do
    current_branch=$(git branch --show-current)
    echo -e "${GREEN}Current branch:${RESET} $current_branch"

    PS3="Select an operation: "
    options=("Add and Commit Changes" "Push Changes" "Branch Management" "Fetch Latest Changes" "View Recent Commits" "Exit")
    select opt in "${options[@]}"
    do
      case $REPLY in
        1)
          add_commit_changes
          break
          ;;
        2)
          push_changes
          break
          ;;
        3)
          branch_management
          break
          ;;
        4)
          fetch_latest
          break
          ;;
        5)
          view_commits
          break
          ;;
        6)
          echo -e "${YELLOW}Exiting...${RESET}"
          exit 0
          ;;
        *)
          echo -e "${RED}Invalid choice. Please select a valid option.${RESET}"
          ;;
      esac
    done
  done
}

# Main script
if [ $# -eq 0 ]; then
  main_menu
else
  handle_arguments "$@"
fi
