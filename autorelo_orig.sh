#!/bin/bash

BASE_DIR="./locations"
mkdir -p "$BASE_DIR"

# Flag ob im Batch-Modus (Config) gelaufen wird
is_batch=false

if [[ -f "$1" ]]; then
  source "$1"
  if [[ -z "$execution_mode" ]]; then
    echo "Error: 'execution_mode' not set in config." >&2
    exit 1
  fi
  is_batch=true
  # Ausgaben unterdrücken im Batch-Modus
  exec 1>/dev/null 2>&1
elif [[ -n "$1" ]]; then
  echo "Error: Config file '$1' not found." >&2
  exit 1
fi

safe_locsim_start() {
  if ! command -v locsim >/dev/null 2>&1; then
    [[ $is_batch == false ]] && echo "Error: 'locsim' is not installed or not in your PATH."
    return 1
  fi
  locsim start "$@"
}

choose_or_create_subfolder() {
  [[ $is_batch == true ]] && return 0  # keine Eingabe im Batch-Modus

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
    [[ $is_batch == false ]] && echo "Created and using subfolder: $newfolder"
  elif [[ "$subchoice" =~ ^[0-9]+$ ]] && [ "$subchoice" -le "${#subfolders[@]}" ] && [ "$subchoice" -ge 1 ]; then
    SUBFOLDER="$BASE_DIR/${subfolders[$((subchoice-1))]}"
    [[ $is_batch == false ]] && echo "Using subfolder: ${subfolders[$((subchoice-1))]}"
  else
    [[ $is_batch == false ]] && echo "Invalid selection."
    exit 1
  fi
}

select_random_location_from_file() {
  line=$(grep -Eo '\([^)]+\)' "$selected_file" | shuf -n 1)
  clean_line=$(echo "$line" | tr -d '()')
  IFS=',' read -r lat lon <<< "$clean_line"
  lat=$(echo "$lat" | xargs)
  lon=$(echo "$lon" | xargs)
  current_location="($lat, $lon)"
}

run_spoof_cycle() {
  if [[ "$execution_mode" == "file" ]]; then
    select_random_location_from_file
  fi
  IFS=',' read -r lat lon <<< "${current_location//[()]/}"

  [[ $is_batch == false ]] && echo "Coordinates: $lat, $lon"

  if [ -n "$move_meters" ]; then
    angle=$(awk -v seed=$RANDOM 'BEGIN { srand(seed); print rand() * 2 * 3.14159265359 }')
    random_radius=$(od -An -N2 -tu2 < /dev/urandom | awk -v max="$move_meters" '{print $1 % (max + 1)}')
    [[ $is_batch == false ]] && echo "Random radius: $random_radius meters"
    delta_lat=$(awk -v d="$random_radius" -v a="$angle" 'BEGIN { printf "%.10f", (d * cos(a)) / 111320 }')
    delta_lon=$(awk -v d="$random_radius" -v a="$angle" -v lat="$lat" 'BEGIN { printf "%.10f", (d * sin(a)) / (111320 * cos(lat * 3.14159265359 / 180)) }')
    lat=$(awk -v l="$lat" -v d="$delta_lat" 'BEGIN { printf "%.10f", l + d }')
    lon=$(awk -v l="$lon" -v d="$delta_lon" 'BEGIN { printf "%.10f", l + d }')
    [[ $is_batch == false ]] && echo "New randomized coordinates: $lat, $lon"
  fi

  [[ $is_batch == false ]] && echo "Starting locsim with coordinates: $lat, $lon"
  safe_locsim_start "$lat" "$lon"
}

# --- Main logic starts here ---

if [[ $is_batch == true ]]; then
  # Batch-Modus: keine Eingaben, kein Loop, direkt einmal ausführen
  if [[ $execution_mode == "file" ]]; then
    # Subfolder in Config angegeben?
    if [[ -z "$subfolder" ]]; then
      echo "Error: 'subfolder' not defined in config."
      exit 1
    fi
    SUBFOLDER="$BASE_DIR/$subfolder"
    if [[ ! -d "$SUBFOLDER" ]]; then
      echo "Error: Subfolder '$SUBFOLDER' does not exist."
      exit 1
    fi
    shopt -s nullglob
    files=("$SUBFOLDER"/*)
    shopt -u nullglob

    if [ "${#files[@]}" -eq 0 ]; then
      echo "Error: No files found in $SUBFOLDER"
      exit 1
    fi

   # file_name aus Config erwartet
    if [[ -z "$file_name" ]]; then
    echo "Error: 'file_name' not defined in config."
    exit 1
    fi

    selected_file="$SUBFOLDER/$file_name"
    if [[ ! -f "$selected_file" ]]; then
    echo "Error: File '$file_name' not found in subfolder '$SUBFOLDER'."
    exit 1
    fi


  elif [[ "$execution_mode" == "manual" ]]; then
    # current_location wird erwartet als "(lat, lon)"
    if [[ -z "$current_location" ]]; then
      echo "Error: 'current_location' not defined in config."
      exit 1
    fi
  else
    echo "Error: Unknown execution_mode '$execution_mode' in config."
    exit 1
  fi

  # move_meters kann leer sein, ist optional
  while true; do
    run_spoof_cycle
    sleep "$((auto_wait_time * 60))"
  done
  exit 0
fi

# --- Interaktiver Modus ---

while true; do
  echo "What would you like to do?"
  echo "s) Spoof location"
  echo "d) Delete subfolder or file"
  read -rp "Enter your choice (s or d): " main_choice

  case "$main_choice" in
    s*)
      echo "Choose mode:"
      echo "c) Choose coordinates from a file"
      echo "e) Enter coordinates manually"
      read -rp "Enter mode (c or e): " mode

      case "$mode" in
        c*)
          choose_or_create_subfolder
          shopt -s nullglob
          files=("$SUBFOLDER"/*)
          shopt -u nullglob

          if [ "${#files[@]}" -eq 0 ]; then
            echo "No files found in $SUBFOLDER"
            exit 1
          fi

          echo "Files in subfolder:"
          for i in "${!files[@]}"; do
            echo "$((i+1))) $(basename "${files[$i]}")"
          done
          read -rp "Choose a file number: " filenum
          if ! [[ "$filenum" =~ ^[0-9]+$ ]] || [ "$filenum" -lt 1 ] || [ "$filenum" -gt "${#files[@]}" ]; then
            echo "Invalid selection."
            exit 1
          fi
          selected_file="${files[$((filenum-1))]}"
          echo "You selected: $(basename "$selected_file")"
          ;;
        e*)
          read -rp "Enter coordinates like (48.1234, 11.5678): " coords
          coords_clean=$(echo "$coords" | tr -d '()')
          IFS=',' read -r lat lon <<< "$coords_clean"
          lat=$(echo "$lat" | xargs)
          lon=$(echo "$lon" | xargs)
          current_location="($lat, $lon)"
          ;;
        *)
          echo "Invalid mode selected."
          exit 1
          ;;
      esac

      read -rp "Do you want to move the spoofing location randomly? (y/n): " move_choice
      if [[ "$move_choice" =~ ^[yY]$ ]]; then
        read -rp "Enter max move distance in meters: " move_meters
        if ! [[ "$move_meters" =~ ^[0-9]+$ ]] || [ "$move_meters" -le 0 ]; then
          echo "Invalid distance input. Must be a positive number."
          continue
        fi
      else
        move_meters=""
      fi

      read -rp "Do you want to loop the action? (y/n): " loop_choice
      if [[ "$loop_choice" =~ ^[yY]$ ]]; then
        read -rp "Enter wait time in minutes between loops: " wait_time_minutes
        if ! [[ "$wait_time_minutes" =~ ^[0-9]+$ ]]; then
          echo "Invalid time input."
          exit 1
        fi
        while true; do
          run_spoof_cycle
          echo "Waiting $wait_time_minutes minutes before next spoof..."
          sleep $((wait_time_minutes * 60))
        done
      else
        run_spoof_cycle
      fi
      ;;
    d*)
      echo "Delete what?"
      echo "s) Subfolder"
      echo "f) File"
      read -rp "Enter choice (s or f): " delete_choice

      case "$delete_choice" in
        s*)
          choose_or_create_subfolder
          rm -ri "$SUBFOLDER"
          ;;
        f*)
          choose_or_create_subfolder
          files=("$SUBFOLDER"/*)
          if [ "${#files[@]}" -eq 0 ]; then
            echo "No files found in $SUBFOLDER"
            exit 1
          fi
          echo "Files in $SUBFOLDER:"
          for i in "${!files[@]}"; do
            echo "$((i+1))) $(basename "${files[$i]}")"
          done
          read -rp "Choose a file number to delete: " file_choice
          if ! [[ "$file_choice" =~ ^[0-9]+$ ]] || [ "$file_choice" -lt 1 ] || [ "$file_choice" -gt "${#files[@]}" ]; then
            echo "Invalid selection."
            exit 1
          fi
          rm -i "${files[$((file_choice-1))]}"
          ;;
        *)
          echo "Invalid delete choice."
          ;;
      esac
      ;;
    *)
      echo "Invalid main choice."
      ;;
  esac

  read -rp "Do you want to perform another action? (y/n): " continue_choice
  [[ "$continue_choice" =~ ^[nN]$ ]] && echo "Exiting." && break
done
