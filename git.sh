#!/bin/bash

# Function to display current Git branch and status
display_git_status() {
  local branch=$(git branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    echo "Current branch: $branch"
    git status --short
  else
    echo "Not currently on any branch."
  fi
}

# Function to handle branch management
branch_management() {
  while true; do
    display_git_status
    
    PS3="Select branch action: "
    options=("Switch Branch" "Create New Branch" "Skip")
    select opt in "${options[@]}"
    do
      case $REPLY in
        1)
          read -p "Enter the branch name to switch to: " branch_name
          if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
            echo "Invalid branch name. Please try again."
          else
            git checkout "$branch_name"
            break 2
          fi
          ;;
        2)
          read -p "Enter the new branch name: " branch_name
          if [ -z "$branch_name" ]; then
            echo "Branch name cannot be empty. Please try again."
          else
            git checkout -b "$branch_name"
            break 2
          fi
          ;;
        3)
          echo "No branch changes."
          break 2
          ;;
        *)
          echo "Invalid option. Please select a valid option."
          break
          ;;
      esac
    done
  done
}

# Function to fetch the latest changes from the remote
fetch_latest() {
  git fetch
  echo "Fetched the latest changes from the remote."
}

# Function to log operations
log_operation() {
  echo "$(date): $1" >> git-auto.log
}

# Function to add and commit changes
add_commit_changes() {
  if (echo -e "Do you want to add all changes? (y/n, default is y): \c" && read -r && [[ "$REPLY" == [Yy] ]] || [[ -z "$REPLY" ]]); then
    git add .
  else
    select_files
    if [ ${#selected_files[@]} -eq 0 ]; then
      echo "No valid files selected. Exiting."
      exit 1
    fi
    git add "${selected_files[@]}"
  fi

  read -p "Enter commit message (leave empty to open editor): " commit_message
  if [ -z "$commit_message" ]; then
    git commit
  else
    git commit -m "$commit_message"
  fi
  log_operation "Changes committed with message: $commit_message"
}

# Function to push changes
push_changes() {
  read -p "Enter the remote to push to (default is 'origin'): " remote
  remote=${remote:-origin}

  read -p "Enter the branch to push to (default is current branch): " branch
  branch=${branch:-$(git branch --show-current)}

  git push "$remote" "$branch"
  log_operation "Changes pushed to $remote/$branch"
}

# Function to handle shorthand command line arguments
handle_arguments() {
  case $1 in
    1)
      add_commit_changes
      ;;
    2)
      push_changes
      ;;
    3)
      branch_management
      ;;
    4)
      fetch_latest
      ;;
    *)
      echo "Invalid argument. Please specify a valid operation."
      exit 1
      ;;
  esac
}

# Main menu function
main_menu() {
  while true; do
    display_git_status
    
    PS3="Select an operation: "
    options=("Add and Commit Changes" "Push Changes" "Branch Management" "Fetch Latest Changes" "Exit")
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
          echo "Exiting..."
          exit 0
          ;;
        *)
          echo "Invalid choice, please select a valid option."
          ;;
      esac
    done
  done
}

# Main script logic
if [ $# -eq 0 ]; then
  main_menu
else
  handle_arguments "$@"
fi
