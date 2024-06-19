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

# Prompt the user to add all changes or select specific files
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

# Prompt for a commit message
echo "Enter commit message:"
read commit_message

# Commit the changes with the provided message
git commit -m "$commit_message"

# Push the changes to the remote repository
git push
