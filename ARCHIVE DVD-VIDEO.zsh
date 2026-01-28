#!/bin/zsh
# Outputs blend-deinterlaced access files using bwdif=mode=send_frame
# Preserves original frame rate while deinterlacing

# Check for required dependencies
check_dependencies() {
  local missing_deps=()
  local required_deps=(ffmpeg ffprobe makemkvcon diskutil)
  local optional_deps=(jq drutil)

  for cmd in "${required_deps[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "ERROR: Missing required dependencies: ${missing_deps[*]}"
    echo "Please install them before running this script."
    exit 1
  fi

  # Warn about optional dependencies
  for cmd in "${optional_deps[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "WARNING: Optional dependency '$cmd' not found. Some features may be limited."
    fi
  done
}

# Check dependencies before starting
check_dependencies

LOGFILE="$PWD/archive_dvd_video_$(date +%Y%m%d_%H%M%S).log"
echo "Logging terminal output to $LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# Cleanup function for error handling
cleanup_on_error() {
  echo "ERROR: Script interrupted or failed."
  if [[ -n "$LOGFILE" && -f "$LOGFILE" ]]; then
    echo "Log file is at: $LOGFILE"
  fi
  exec >/dev/tty 2>&1
  exit 1
}

# Set up error trap
trap cleanup_on_error INT TERM

create_iso() {
  echo "Entered create_iso"

  # Check for ddrescue and sudo
  if ! command -v ddrescue >/dev/null 2>&1; then
    echo "ERROR: ddrescue is not installed. Install it with: brew install ddrescue"
    return 1
  fi

  echo "Listing external disk devices:"
  diskutil list external
  echo -n "Enter your DVD device identifier (e.g., disk3): "
  read dvd_dev

  # Validate device exists
  if ! diskutil info "$dvd_dev" >/dev/null 2>&1; then
    echo "ERROR: Device $dvd_dev not found or not accessible."
    return 1
  fi

  # If user typed "disk3", convert to raw device "rdisk3"
  dvd_raw_dev="${dvd_dev/disk/rdisk}"

  echo "Unmounting /dev/$dvd_dev ..."
  if ! diskutil unmountDisk "/dev/$dvd_dev"; then
    echo "ERROR: Failed to unmount /dev/$dvd_dev"
    return 1
  fi

  echo -n "Enter output ISO filename (e.g., CA0001234567): "
  read iso_file
  iso_file="${iso_file##*/}"
  iso_file="${iso_file%.iso}.iso"
  iso_path="$PWD/$iso_file"

  # Check if file already exists
  if [[ -f "$iso_path" ]]; then
    echo "WARNING: File $iso_path already exists."
    read -r "?Overwrite? (y/n): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      echo "Aborting."
      return 1
    fi
  fi

  # Get disk size in bytes (handles both 'Total Size' and 'Disk Size' formats)
  dvd_size_bytes=$(
    diskutil info "$dvd_dev" | grep -E "Total Size|Disk Size" | head -1 | cut -d "(" -f2 | awk '{print $1}'
  )

  if [[ -z "$dvd_size_bytes" || "$dvd_size_bytes" -le 0 ]]; then
    echo "ERROR: Could not determine DVD size. Please check the device."
    return 1
  fi

  echo "Detected DVD size: $dvd_size_bytes bytes"

  # Add 5% safety margin to prevent truncation if OS-reported size is slightly low
  dvd_size_with_margin=$(( dvd_size_bytes + (dvd_size_bytes / 20) ))
  echo "Using size with 5% safety margin: $dvd_size_with_margin bytes"
  echo "Copying DVD to $iso_path. This may take a while..."

  if ! sudo ddrescue -r3 -s "$dvd_size_with_margin" "/dev/$dvd_raw_dev" "$iso_path" "$iso_path.log"; then
    echo "ERROR: ddrescue failed. Check $iso_path.log for details."
    return 1
  fi

  echo "Done. Your ISO image is $iso_file"
  ISO_PATH="$iso_path"
}


generate_access_mp4() {
  local mkv_file="$1"
  local title_num="$2"
  local output_prefix="$3"
  local access_file="${output_prefix}-A${title_num}.mp4"

  if [[ ! -f "$mkv_file" ]]; then
    echo "ERROR: MKV file not found: $mkv_file"
    return 1
  fi

  echo "Creating access MP4 for $(basename "$mkv_file")..."

  # Get field order - use jq if available, otherwise fallback to grep/sed
  local field_order
  if command -v jq >/dev/null 2>&1; then
    # Use jq for proper JSON parsing
    field_order=$(ffprobe -v quiet -print_format json -show_streams "$mkv_file" 2>/dev/null | jq -r '.streams[0].field_order // empty')
  else
    # Fallback to grep/sed
    field_order=$(ffprobe -v quiet -print_format json -show_streams "$mkv_file" 2>/dev/null | grep -m1 '"field_order"' | sed 's/.*"field_order":\s*"\([^"]*\)".*/\1/')
  fi

  echo "Detected field_order: '$field_order'"

  # Map field_order to bwdif parity and determine if deinterlacing is needed
  local parity
  local needs_deinterlace=true

  case "$field_order" in
    "tt"|"tb")
      parity="tff"
      echo "Detected top-field-first, setting parity=tff"
      ;;
    "bb"|"bt")
      parity="bff"
      echo "Detected bottom-field-first, setting parity=bff"
      ;;
    "progressive")
      parity=""
      needs_deinterlace=false
      echo "Detected progressive scan"
      ;;
    "")
      parity="tff"
      echo "Empty field order, defaulting to parity=tff for safety"
      ;;
    *)
      parity="tff"
      echo "Unrecognized field order '$field_order', defaulting to parity=tff"
      ;;
  esac

  if [[ "$needs_deinterlace" == false ]]; then
    echo "Source is progressive, no deinterlacing needed."
    if ! ffmpeg -hide_banner -y -fflags +genpts -i "$mkv_file" \
      -map 0:v -map 0:a -map_chapters 0 -map -0:s \
      -c:v libx264 -b:v 3M -minrate 3M -maxrate 6M -bufsize 6M \
      -preset medium -profile:v high -level:v 3.1 -pix_fmt yuv420p \
      -c:a aac -b:a 192k -ac 2 -movflags +faststart \
      "$access_file"; then
      echo "ERROR: ffmpeg failed to create access file"
      return 1
    fi
  else
    echo "Source is interlaced, applying blend deinterlacing with bwdif (${parity})"
    if ! ffmpeg -hide_banner -y -fflags +genpts -i "$mkv_file" \
      -vf "bwdif=mode=send_frame:parity=${parity}:deint=all" \
      -map 0:v -map 0:a -map_chapters 0 -map -0:s \
      -c:v libx264 -b:v 3M -minrate 3M -maxrate 6M -bufsize 6M \
      -preset medium -profile:v high -level:v 3.1 -pix_fmt yuv420p \
      -c:a aac -b:a 192k -ac 2 -movflags +faststart \
      "$access_file"; then
      echo "ERROR: ffmpeg failed to create access file"
      return 1
    fi
  fi

  echo "Finished processing: $access_file"
}

create_files_from_iso() {
  echo "Entered create_files_from_iso with create_access_files=$1"
  local create_access_files="$1"
  setopt nullglob

  if [[ -n "$ISO_PATH" && -f "$ISO_PATH" ]]; then
    echo "An ISO was just created: $ISO_PATH"
    read -r "?Use this ISO? (y/n): " use_last_iso
    if [[ ! "$use_last_iso" =~ ^[Yy]$ ]]; then
      echo -n "Enter the path to the ISO file: "
      read ISO_PATH
      [[ ! -f "$ISO_PATH" ]] && { echo "ERROR: File not found: $ISO_PATH"; return 1; }
    fi
  else
    echo "Entered create_files_from_iso (create_access_files=$create_access_files)"
    echo "Available ISOs in $PWD:"
    find "$PWD" -maxdepth 2 -name "*.iso" 2>/dev/null
    echo -n "Enter the path to the ISO file: "
    read ISO_PATH
    [[ ! -f "$ISO_PATH" ]] && { echo "ERROR: File not found: $ISO_PATH"; return 1; }
  fi

  read -r "?Eject the physical DVD now? (y/n): " eject_choice
  if [[ "$eject_choice" =~ ^[Yy]$ ]]; then
    if command -v drutil >/dev/null 2>&1; then
      drutil tray eject
    elif command -v eject >/dev/null 2>&1; then
      eject
    else
      echo "No eject command found. Please eject the DVD manually."
    fi
  fi

  output_dir_name="${ISO_PATH:t:r}"
  out_dir="$PWD/$output_dir_name"

  if ! mkdir -p "$out_dir"; then
    echo "ERROR: Failed to create output directory: $out_dir"
    return 1
  fi

  echo "Extracting titles with MakeMKV..."
  if ! makemkvcon --minlength=15 mkv iso:"$ISO_PATH" all "$out_dir"; then
    echo "ERROR: MakeMKV failed to extract titles."
    return 1
  fi

  echo "MakeMKV extraction complete"
  sleep 2
  echo "Listing contents of $out_dir:"
  ls -1 "$out_dir"

  mkv_files=("$out_dir"/*.mkv)
  echo "Found ${#mkv_files[@]} MKV files:"
  for f in "${mkv_files[@]}"; do echo " - $(basename "$f")"; done

  if [[ ${#mkv_files[@]} -eq 0 ]]; then
    echo "ERROR: No MKV files were created in $out_dir."
    echo "MakeMKV reported success, but no .mkv files matched the expected pattern."
    return 1
  fi

  # Rename files from MakeMKV format to PM format
  renamed_files=()
  for mkv_file in "$out_dir"/*.mkv; do
    [[ -f "$mkv_file" ]] || continue
    filename=$(basename "$mkv_file")

    # Extract the number after _t
    orig_num=$(echo "$filename" | sed -nE 's/.*_t([0-9]{2}).*/\1/p')
    if [[ -z "$orig_num" ]]; then
      echo "WARNING: Could not extract title number from $filename. Skipping."
      continue
    fi

    # Increment by 1, preserving leading zeros
    new_num=$(printf "%02d" $((10#$orig_num + 1)))
    new_mkv="$out_dir/${output_dir_name}-PM${new_num}.mkv"

    echo "Renaming $mkv_file to $new_mkv"
    if ! mv "$mkv_file" "$new_mkv"; then
      echo "ERROR: Failed to rename $mkv_file"
      continue
    fi

    ls -1 "$new_mkv"
    renamed_files+=("$new_mkv")
  done

  # Process renamed files: optionally create access MP4s
  for mkv_file in "${renamed_files[@]}"; do
    [[ -f "$mkv_file" ]] || continue
    base_name=$(basename "$mkv_file" .mkv)
    title_num=$(echo "$base_name" | grep -oE 'PM[0-9]{2}' | sed 's/PM//')

    if [[ "$create_access_files" == "true" ]]; then
      output_prefix="$out_dir/${output_dir_name}"
      generate_access_mp4 "$mkv_file" "$title_num" "$output_prefix" || echo "WARNING: Failed to create access MP4 for $mkv_file"
    fi
  done

  echo "All titles processed."
}

create_access_files_only() {
    echo -n "Enter the path to the directory containing MKVs: "
    read rip_dir

    if [[ ! -d "$rip_dir" ]]; then
        echo "ERROR: Directory not found: $rip_dir"
        return 1
    fi

    # Set these for log moving at exit
    out_dir="$rip_dir"
    output_dir_name="${rip_dir:t}"

    local processed_count=0
    local failed_count=0

    for mkv_file in "$rip_dir"/*.mkv; do
        [[ -f "$mkv_file" ]] || continue

        base_name=$(basename "$mkv_file" .mkv)
        # Support PM (preservation master) and A (access) naming patterns
        title_num=$(echo "$base_name" | grep -oE '(PM|A)[0-9]{2}' | grep -oE '[0-9]{2}')
        [[ -z "$title_num" ]] && title_num="00"

        # Extract prefix (everything before the last hyphen and number)
        output_prefix="$rip_dir/${base_name%-*}"

        echo "Processing: $mkv_file"
        if generate_access_mp4 "$mkv_file" "$title_num" "$output_prefix"; then
            ((processed_count++))
        else
            ((failed_count++))
            echo "WARNING: Failed to process $mkv_file"
        fi
    done

    echo "Access file creation complete: $processed_count succeeded, $failed_count failed."
}

echo "Current working directory: $(pwd)"
echo -n "Is this the directory where you want to perform DVD operations? (y/n): "
read yn
case "$yn" in
    [Yy]* )
        echo "Proceeding with main menu..."
        ;;
    [Nn]* )
        echo ""
        echo "To use a different directory:"
        echo "1. Exit this script (Ctrl+C or select option 5 from the menu)"
        echo "2. Change to the desired directory using: cd /path/to/directory"
        echo "3. Rerun this script"
        echo ""
        echo "Continuing to menu anyway..."
        ;;
    * )
        echo "Please answer y or n."
        exit 1
        ;;
esac

# Function to handle exit and log cleanup
handle_exit() {
  if [[ -n "$out_dir" && -d "$out_dir" && -n "$LOGFILE" && -f "$LOGFILE" ]]; then
    log_basename="${output_dir_name:-trace}-RF.log"
    new_logfile="${out_dir}/${log_basename}"
    if mv "$LOGFILE" "$new_logfile" 2>/dev/null; then
      echo "Log file moved to: $new_logfile"
    else
      echo "Log file remains at: $LOGFILE"
    fi
  else
    echo "Log file not moved (output directory or log file missing)."
    [[ -n "$LOGFILE" && -f "$LOGFILE" ]] && echo "Log file is at: $LOGFILE"
  fi

  echo "Exiting."

  # Close and clean up the tee process safely
  exec >/dev/tty 2>&1
  exit 0
}

while true; do
  echo
  echo "Choose an option:"
  echo "1. Create a disk image from a DVD. (Only choose this if you have admin permissions)"
  echo "From a disk image"
  echo "2. Create archival MKV and access MP4 files"
  echo "3. Create archival MKVs only"
  echo "4. Create access files only"
  echo "5. Exit"
  read -r choice
  case "$choice" in
    1) create_iso ;;
    2) create_files_from_iso "true" ;;
    3) create_files_from_iso "false" ;;
    4) create_access_files_only ;;
    5) handle_exit ;;
    *) echo "Invalid choice. Please select 1, 2, 3, 4, or 5." ;;
  esac
done
