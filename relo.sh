#!/bin/bash

BASE_DIR="./locations"
mkdir -p "$BASE_DIR"

# Function to safely call locsim
safe_locsim_start() {
  if ! command -v locsim >/dev/null 2>&1; then
    echo "Error: 'locsim' is not installed or not in your PATH."
    return 1
  fi

  locsim start "$@"
}

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

      if ! [[ "$file_choice" =~ ^[0-9]+$ ]] || [ "$file_choice" -lt 1 ] || [ "$file_choice" -gt "${#files[@]}" ]; then
        echo "Invalid selection."
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


current_location=""
main_choice=""
mode=""
SUBFOLDER=""
filenum=""
move_choice=""
move_meters=""
confirm=""
loop_choice=""
wait_time_minutes=""
confirm=""
continue_choice=""

while true; do

  if [ -z "$main_choice" ]; then
    echo "What would you like to do?"
    echo "s) Spoof location"
    echo "d) Delete subfolder or file"
    read -rp "Enter your choice (s or d): " main_choice
  fi

  case "$main_choice" in
    s*)
      if [ -z "$mode" ]; then
        if [ -z "$current_location" ]; then
            echo "Current location is not set."
            echo "Choose mode:"
            echo "c) Choose coordinates from a file"
            echo "e) Enter coordinates manually"
            read -rp "Enter mode (c or e): " mode
        else
            echo "Current location: $current_location"
            echo "Choose mode:"
            echo "c) Choose coordinates from a file"
            echo "e) Enter coordinates manually"
            echo "u) Use current location"
            read -rp "Enter mode (c, e, or u): " mode
        fi
      fi

      case "$mode" in
        c*)
          if [ -z "$SUBFOLDER" ]; then
            choose_or_create_subfolder
          fi

          shopt -s nullglob
          files=("$SUBFOLDER"/*)
          shopt -u nullglob
          count=${#files[@]}

          if [ -z "$filenum" ]; then

            echo ""
            echo "Files in subfolder:"

            if [ "$count" -eq 0 ]; then
                echo "No files found in $SUBFOLDER"
                exit 1
            fi

            for i in "${!files[@]}"; do
                filename=$(basename "${files[$i]}")
                echo "$((i+1))) $filename"
            done

            read -rp "Choose a file number: " filenum
        fi

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
          current_location="($lat, $lon)"
          ;;
        e*)
          read -rp "Enter coordinates like (48.1234, 11.5678): " coords
          coords_clean=$(echo "$coords" | tr -d '()')
          IFS=',' read -r lat lon <<< "$coords_clean"
          lat=$(echo "$lat" | xargs)
          lon=$(echo "$lon" | xargs)
          current_location="($lat, $lon)"
          ;;
        u*)
          IFS=',' read -r lat lon <<< "${current_location//[()]/}"
          ;;
        *)
          echo "Invalid mode selected."
          exit 1
          ;;
      esac

      echo "Coordinates: $lat, $lon"
      if [ -z "$move_choice" ]; then
        read -rp "Do you want to move the spoofing location randomly? (y/n): " move_choice
        if [[ "$move_choice" =~ ^[yY]$ ]]; then
            read -rp "Enter distance to move in meters (positive number): " move_meters

            if ! [[ "$move_meters" =~ ^[0-9]+$ ]] || [ "$move_meters" -le 0 ]; then
            echo "Invalid distance input. Must be a positive number."
            continue
            fi
        fi
      fi

      if [ -n "$move_meters" ]; then
        angle=$(awk -v seed=$RANDOM 'BEGIN { srand(seed); print rand() * 2 * 3.14159265359 }')

        delta_lat=$(awk -v d="$move_meters" -v a="$angle" 'BEGIN { printf "%.10f", (d * cos(a)) / 111320 }')
        delta_lon=$(awk -v d="$move_meters" -v a="$angle" -v lat="$lat" 'BEGIN { printf "%.10f", (d * sin(a)) / (111320 * cos(lat * 3.14159265359 / 180)) }')

        lat=$(awk -v l="$lat" -v d="$delta_lat" 'BEGIN { printf "%.10f", l + d }')
        lon=$(awk -v l="$lon" -v d="$delta_lon" 'BEGIN { printf "%.10f", l + d }')

        echo "New randomized coordinates: $lat, $lon"
      fi

      
      if [ -z "$confirm" ]; then
        read -rp "Do you really want to spoof this location? (y/n): " confirm
      fi
      if [ "$confirm" = "y" ]; then
        echo "Starting locsim with coordinates: $lat, $lon"
        safe_locsim_start "$lat" "$lon"
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

  if [ -z "$continue_choice" ]; then
    read -rp "Do you want to perform another action? (y/n): " continue_choice
    if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
        echo "Exiting."
        break
    fi
  fi

  if [ -z "$loop_choice" ]; then
    read -rp "Do you want to loop the same action? (y/n): " loop_choice
  fi

  if [[ "$loop_choice" == "y" || "$loop_choice" == "Y" ]]; then
    if [ -z "$wait_time_minutes" ]; then
        read -rp "How many minutes would you like to wait before the next loop starts? " wait_time_minutes
    fi

    # Sleep for the set amount of time before continuing to the next loop
    if [ "$wait_time_minutes" -gt 0 ]; then
        echo "Waiting for $wait_time_minutes minutes..."
        sleep $((wait_time_minutes * 60))
    fi
  else
    current_location=""
    main_choice=""
    mode=""
    SUBFOLDER=""
    filenum=""
    move_choice=""
    move_meters=""
    confirm=""
    loop_choice=""
    wait_time_minutes=""
    confirm=""
    continue_choice=""
  fi
done
