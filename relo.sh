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
  echo "s) Subfolder"
  echo "f) File"
  read -rp "Enter choice (s or f): " delete_choice

  case "$delete_choice" in
    s*)
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
      ;;
    f*)
      choose_or_create_subfolder

      shopt -s nullglob
      files=("$SUBFOLDER"/*)
      shopt -u nullglob

      if [ "${#files[@]}" -eq 0 ]; then
        echo "No files found in $SUBFOLDER"
       exit 1
      fi

      echo "Files in $SUBFOLDER:"
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
      ;;
    *)
      echo "Invalid delete choice."
      exit 1
      ;;
  esac
}

echo "What would you like to do?"
echo "s) Spoof location"
echo "d) Delete subfolder or file"
read -rp "Enter your choice (s or d): " main_choice

case "$main_choice" in
  s*)
    choose_or_create_subfolder
    echo ""
    echo "Choose mode:"
    echo "c) Choose coordinates from a file"
    echo "e) Enter coordinates manually"
    read -rp "Enter mode (c or e): " mode

    case "$mode" in
      c*)
        echo ""
        echo "Files in subfolder:"
        shopt -s nullglob
        files=("$SUBFOLDER"/*)
        shopt -u nullglob
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
        ;;
      e*)
        read -rp "Enter coordinates like (48.1234, 11.5678): " coords
        coords_clean=$(echo "$coords" | tr -d '()')
        IFS=',' read -r lat lon <<< "$coords_clean"
        lat=$(echo "$lat" | xargs)
        lon=$(echo "$lon" | xargs)

        echo ""
        echo "Where would you like to save the coordinates?"
        echo "c) Create new file"
        echo "a) Add to existing file"
        echo "d) Dont save"
        read -rp "Enter choice (c,a or d): " save_choice

        case "$save_choice" in
          c*)
            read -rp "Enter new filename (without path): " newfile
            filepath="$SUBFOLDER/$newfile"
            if [ -e "$filepath" ]; then
              echo "Error: File already exists."
              exit 1
            fi
            echo "($lat, $lon)" > "$filepath"
            echo "Coordinates saved to $filepath"
            ;;
          a*)
            echo "Available files in subfolder:"
            shopt -s nullglob
            files=("$SUBFOLDER"/*)
            shopt -u nullglob
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
          d*)
            echo "Coordinates not saved."
            ;;
          *)
            echo "Invalid selection."
            exit 1
            ;;
        esac
        ;;
      *)
        echo "Invalid mode selected."
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
    ;;
  d*)
    delete_subfolder_or_file
    ;;
  *)
    echo "Invalid main choice."
    exit 1
    ;;
esac
