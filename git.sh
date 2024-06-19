#!/bin/bash

# Function to display files and get user selection
select_files() {
  files=($(git status --short | awk '{print $2}'))
  echo "Select files to add (space-separated numbers, e.g., 1 2 3):"
  for i in "${!files[@]}"; do
    echo "$((i+1)). ${files[$i]}"
  done

  read -a selections

  for index in "${selections[@]}"; do
    if [[ $index -gt 0 && $index -le ${#files[@]} ]]; then
      selected_files+=("${files[$((index-1))]}")
    else
      echo "Invalid selection: $index"
    fi
  done
}

# Function to handle branch management
branch_management() {
  current_branch=$(git branch --show-current)
  echo "Current branch: $current_branch"
  echo "Do you want to switch branches or create a new branch? (n to skip, b to switch, c to create):"
  read branch_action

  case $branch_action in
    b|B)
      echo "Enter the branch name to switch to:"
      read branch_name
      git checkout "$branch_name"
      ;;
    c|C)
      echo "Enter the new branch name:"
      read branch_name
      git checkout -b "$branch_name"
      ;;
    n|N)
      echo "No branch changes."
      ;;
    *)
      echo "Invalid option. No branch changes."
      ;;
  esac
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

# Function to display the main menu
main_menu() {
  echo "Select an operation:"
  echo "1. Add and Commit Changes"
  echo "2. Push Changes"
  echo "3. Branch Management"
  echo "4. Fetch Latest Changes"
  echo "5. Show Git Status"
  echo "6. Exit"
}

# Main script
while true; do
  main_menu
  read -p "Enter your choice (1-6): " choice

  case $choice in
    1)
      echo "Adding and Committing Changes..."
      echo "Do you want to add all changes? (y/n, default is y):"
      read add_all

      selected_files=()

      if [[ "$add_all" == "n" || "$add_all" == "N" ]]; then
        select_files
        if [ ${#selected_files[@]} -eq 0 ]; then
          echo "No valid files selected. Exiting."
          exit 1
        fi
        git add "${selected_files[@]}"
      else
        git add .
      fi

      echo "Enter commit message (leave empty to open editor):"
      read commit_message

      if [ -z "$commit_message" ]; then
        git commit
      else
        git commit -m "$commit_message"
      fi
      log_operation "Changes committed with message: $commit_message"
      ;;
    2)
      echo "Pushing Changes..."
      echo "Enter the remote to push to (default is 'origin'):"
      read remote
      remote=${remote:-origin}

      echo "Enter the branch to push to (default is current branch):"
      read branch
      branch=${branch:-$(git branch --show-current)}

      git push "$remote" "$branch"
      log_operation "Changes pushed to $remote/$branch"
      ;;
    3)
      echo "Branch Management..."
      branch_management
      ;;
    4)
      echo "Fetching Latest Changes..."
      fetch_latest
      ;;
    5)
      echo "Current git status:"
      git status
      ;;
    6)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid choice, please select a valid option."
      ;;
  esac
done
