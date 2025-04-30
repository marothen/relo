#!/bin/bash

BASE_DIR="./locations"
mkdir -p "$BASE_DIR"

choose_or_create_subfolder() {
echo ""
echo "Available subfolders:"
subfolders=($(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))

for i in "${!subfolders[@]}"; do
echo "$((i+1))) ${subfolders[$i]}"
done
echo "$(( ${#subfolders[@]} + 1 ))) Create new subfolder"
read -rp "Choose a subfolder number: " subchoice

if [ "$subchoice" -eq $(( ${#subfolders[@]} + 1 )) ]; then
read -rp "Enter name for new subfolder: " newfolder
SUBFOLDER="$BASE_DIR/$newfolder"
mkdir -p "$SUBFOLDER"
echo "Created and using subfolder: $newfolder"
elif [[ "$subchoice" =~ ^[0-9]+$ ]] && [ "$subchoice" -le "${#subfolders[@]}" ] && [ "$subchoice" -ge 1 ]; then
SUBFOLDER="$BASE_DIR/${subfolders[$((subchoice-1))]}"
echo "Using subfolder: ${subfolders[$((subchoice-1))]}"
else
echo "Invalid selection."
exit 1
fi
}

delete_subfolder_or_file() {
echo "Delete what?"
echo "1) Subfolder"
echo "2) File"
read -rp "Enter number (1 or 2): " delete_choice

if [ "$delete_choice" = "1" ]; then
echo "Available subfolders:"
subfolders=($(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
for i in "${!subfolders[@]}"; do
echo "$((i+1))) ${subfolders[$i]}"
done
read -rp "Choose a subfolder number to delete: " subfolder_choice
if [[ "$subfolder_choice" =~ ^[0-9]+$ ]] && [ "$subfolder_choice" -le "${#subfolders[@]}" ] && [ "$subfolder_choice" -ge 1 ]; then
subfolder_to_delete="$BASE_DIR/${subfolders[$((subfolder_choice-1))]}"
read -rp "Are you sure you want to delete the subfolder $subfolder_to_delete? (y/): " confirm_delete
if [ "$confirm_delete" = "y" ]; then
rm -r "$subfolder_to_delete"
echo "Subfolder deleted."
else
echo "Deletion canceled."
fi
else
echo "Invalid subfolder choice."
exit 1
fi

elif [ "$delete_choice" = "2" ]; then
choose_or_create_subfolder
echo "Files in $SUBFOLDER:"
files=("$SUBFOLDER"/*)
count=${#files[@]}

if [ "$count" -eq 0 ]; then
echo "No files found in $SUBFOLDER"
exit 1
fi

for i in "${!files[@]}"; do
filename=$(basename "${files[$i]}")
echo "$((i+1))) $filename"
done
read -rp "Choose a file number to delete: " file_choice

if ! [[ "$file_choice" =~ ^[0-9]+$ ]] || [ "$file_choice" -lt 1 ] || [ "$file_choice" -gt "$count" ]; then
echo "Invalid file selection."
exit 1
fi

file_to_delete="${files[$((file_choice-1))]}"
read -rp "Are you sure you want to delete the file $file_to_delete? (y/n): " confirm_delete
if [ "$confirm_delete" = "y" ]; then
rm "$file_to_delete"
echo "File deleted."
else
echo "Deletion canceled."
fi

else
echo "Invalid delete choice."
exit 1
fi
}

echo "What do you want to do?"
echo "1) Spoof location"
echo "2) Delete subfolder or file"
read -rp "Enter number (1 or 2): " main_choice

if [ "$main_choice" = "2" ]; then
delete_subfolder_or_file
exit 0
fi

choose_or_create_subfolder

if [ "$main_choice" = "1" ]; then
echo ""
echo "Choose mode:"
echo "1) file"
echo "2) input"
read -rp "Enter number (1 or 2): " mode

if [ "$mode" = "1" ]; then
echo ""
echo "Files in subfolder:"
files=("$SUBFOLDER"/*)
count=${#files[@]}

if [ "$count" -eq 0 ]; then
echo "No files found in $SUBFOLDER"
exit 1
fi

for i in "${!files[@]}"; do
filename=$(basename "${files[$i]}")
echo "$((i+1))) $filename"
done

read -rp "Choose a file number: " filenum

if ! [[ "$filenum" =~ ^[0-9]+$ ]] || [ "$filenum" -lt 1 ] || [ "$filenum" -gt "$count" ]; then
echo "Invalid selection."
exit 1
fi

selected_file="${files[$((filenum-1))]}"
echo "You selected: $(basename "$selected_file")"

line=$(grep -Eo '\([^)]+\)' "$selected_file" | shuf -n 1)
clean_line=$(echo "$line" | tr -d '()')
IFS=',' read -r lat lon <<< "$clean_line"
lat=$(echo "$lat" | xargs)
lon=$(echo "$lon" | xargs)

echo "Coordinates: $lat, $lon"
read -rp "Do you really want to spoof this location? (y/n): " confirm
if [ "$confirm" = "y" ]; then
echo "Starting locsim with coordinates: $lat, $lon"
locsim start "$lat" "$lon"
else
echo "Location spoofing canceled."
fi

elif [ "$mode" = "2" ]; then
read -rp "Enter coordinates like (48.1234, 11.5678): " coords
coords_clean=$(echo "$coords" | tr -d '()')
IFS=',' read -r lat lon <<< "$coords_clean"
lat=$(echo "$lat" | xargs)
lon=$(echo "$lon" | xargs)

echo ""
echo "What would you like to do with the coordinates?"
echo "1) Create new file"
echo "2) Add to existing file"
echo "3) Do not save"
read -rp "Enter number (1–3): " save_choice

case "$save_choice" in
1)
read -rp "Enter new filename (without path): " newfile
filepath="$SUBFOLDER/$newfile"
if [ -e "$filepath" ]; then
echo "Error: File already exists."
exit 1
fi
echo "($lat, $lon)" > "$filepath"
echo "Coordinates saved to $filepath"
;;
2)
echo "Available files in subfolder:"
files=("$SUBFOLDER"/*)
for i in "${!files[@]}"; do
filename=$(basename "${files[$i]}")
echo "$((i+1))) $filename"
done
read -rp "Choose a file number to append to: " fileappend
if ! [[ "$fileappend" =~ ^[0-9]+$ ]] || [ "$fileappend" -lt 1 ] || [ "$fileappend" -gt "${#files[@]}" ]; then
echo "Invalid file selection."
exit 1
fi
appendfile="${files[$((fileappend-1))]}"
echo "($lat, $lon)" >> "$appendfile"
echo "Appended to $(basename "$appendfile")"
;;
3)
echo "Coordinates not saved."
;;
*)
echo "Invalid selection."
exit 1
;;
esac

echo "Coordinates: $lat, $lon"
read -rp "Do you really want to spoof this location? (y/n): " confirm
if [ "$confirm" = "y" ]; then
echo "Starting locsim with coordinates: $lat, $lon"
locsim start "$lat" "$lon"
else
echo "Location spoofing canceled."
fi

else
echo "Invalid mode selected."
exit 1
fi
else
echo "Invalid main choice."
exit 1
fi