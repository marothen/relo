#!/bin/sh

# --- 1. Config ---
REPO_URL="https://github.com/marothen/relo.git"
BRANCH_NAME="${1:-mai}"
REPO_NAME="relo"  # Git will create this directory automatically

# --- 2. Remove existing folder if it exists ---
echo "Removing existing '$REPO_NAME' folder if it exists..."
rm -rf "$REPO_NAME"

# --- 3. Clone the Git repository and branch ---
echo "Cloning branch '$BRANCH_NAME' from '$REPO_URL'..."
git clone --branch "$BRANCH_NAME" "$REPO_URL"

# --- 4. Make all .sh and .py files in the cloned folder executable ---
echo "Making .sh and .py files executable..."
find "$REPO_NAME" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

echo "Setup completed."

