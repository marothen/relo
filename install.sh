#!/bin/sh

# --- 1. Config ---
REPO_URL="https://github.com/marothen/relo.git"
BRANCH_NAME="test"
TARGET_DIR="relo"

# --- 2. Remove existing folder if it exists ---
echo "Removing existing '$TARGET_DIR' folder if it exists..."
rm -rf "$TARGET_DIR"

# --- 3. Clone the Git repository and branch ---
echo "Cloning branch '$BRANCH_NAME' from '$REPO_URL'..."
git clone --branch "$BRANCH_NAME" "$REPO_URL"

# --- 4. Make all .sh and .py files in the target folder executable ---
echo "Making .sh and .py files executable..."
find "$TARGET_DIR" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;

echo "Setup completed."
