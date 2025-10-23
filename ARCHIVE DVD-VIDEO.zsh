#!/bin/zsh
# Outputs bob-deinterlaced access files using the line -vf "bwdif=mode=send_field:parity=${parity}:deint=all"
# If you need blend-deinterlaced, use bwdif=mode=send_frame

LOGFILE="$PWD/archive_dvd_video_$(date +%Y%m%d_%H%M%S).log"
echo "Logging terminal output to $LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

create_iso() {
  echo "Entered create_iso"
  echo "Listing external disk devices:"
  diskutil list external
  echo -n "Enter your DVD device identifier (e.g., disk2): "
  read dvd_dev
  echo "Unmounting /dev/$dvd_dev ..."
  diskutil unmount /dev/$dvd_dev
  echo -n "Enter output ISO filename (e.g., CA0001234567): "
  read iso_file
  iso_file="${iso_file##*/}"
  iso_file="${iso_file%.iso}.iso"
  iso_path="$PWD/$iso_file"
  mkdir -p "$PWD"
  echo "Copying DVD to $iso_path. This may take a while..."
  sudo dd if=/dev/$dvd_dev of="$iso_path" bs=2048 conv=sync,noerror status=progress
  echo "Done. Your ISO image is $iso_file"
  ISO_PATH="$iso_path"
}

generate_access_mp4() {
  local mkv_file="$1"
  local title_num="$2"
  local output_prefix="$3"
  local access_file="${output_prefix}-A${title_num}.mp4"

  echo "Creating access MP4 for $(basename "$mkv_file")..."

  # Get field order - use jq if available, otherwise fallback to grep/sed
  local field_order
  if command -v jq >/dev/null 2>&1; then
    # Use jq for proper JSON parsing
    field_order=$(ffprobe -v quiet -print_format json -show_streams "$mkv_file" | jq -r '.streams[0].field_order // empty')
  else
    # Fallback to grep/sed
    field_order=$(ffprobe -v quiet -print_format json -show_streams "$mkv_file" | grep -m1 '"field_order"' | sed 's/.*"field_order":\s*"\([^"]*\)".*/\1/')
  fi
  
  echo "Detected field_order: '$field_order'"

  # Map field_order to bwdif parity
  local parity
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
      echo "Detected progressive scan"
      ;;
    ""|\?)
      parity="tff"
      echo "Unknown or empty field order, defaulting to parity=tff"
      ;;
    *)
      parity="tff"
      echo "Unrecognized field order '$field_order', defaulting to parity=tff"
      ;;
  esac

  if [[ "$field_order" == "progressive" || -z "$field_order" ]]; then
    echo "Source is progressive, no deinterlacing needed."
    ffmpeg -hide_banner -y -fflags +genpts -i "$mkv_file" \
      -map 0:v -map 0:a -map_chapters 0 -map -0:s \
      -c:v libx264 -b:v 3M -minrate 3M -maxrate 6M -bufsize 6M \
      -preset medium -profile:v high -level:v 3.1 -pix_fmt yuv420p \
      -c:a aac -b:a 192k -ac 2 -movflags +faststart \
      "$access_file"
  else
    echo "Source is interlaced, applying bob deinterlacing with bwdif (${parity})"
    ffmpeg -hide_banner -y -fflags +genpts -i "$mkv_file" \
      -vf "bwdif=mode=send_field:parity=${parity}:deint=all" \
      -map 0:v -map 0:a -map_chapters 0 -map -0:s \
      -c:v libx264 -b:v 3M -minrate 3M -maxrate 6M -bufsize 6M \
      -preset medium -profile:v high -level:v 3.1 -pix_fmt yuv420p \
      -c:a aac -b:a 192k -ac 2 -movflags +faststart \
      "$access_file"
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
      [[ ! -f "$ISO_PATH" ]] && { echo "ERROR: File not found: $ISO_PATH"; exit 1; }
    fi
  else
    echo "Entered create_files_from_iso (create_access_files=$create_access_files)"
    echo "Available ISOs in $PWD:"
    find "$PWD" -maxdepth 2 -name "*.iso"
    echo -n "Enter the path to the ISO file: "
    read ISO_PATH
    [[ ! -f "$ISO_PATH" ]] && { echo "ERROR: File not found: $ISO_PATH"; exit 1; }
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
  mkdir -p "$out_dir"
  echo "Extracting titles with MakeMKV..."
  makemkvcon --minlength=15 mkv iso:"$ISO_PATH" all "$out_dir"
  if [[ $? -ne 0 ]]; then
    echo "ERROR: MakeMKV failed to extract titles."
    exit 1
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
    exit 1
  fi
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
  mv "$mkv_file" "$new_mkv"
  ls -1 "$new_mkv"
  renamed_files+=("$new_mkv")
done
  for mkv_file in "${renamed_files[@]}"; do
    [[ -f "$mkv_file" ]] || continue
    base_name=$(basename "$mkv_file" .mkv)
    title_num=$(echo "$base_name" | grep -oE 'PM[0-9]{2}' | sed 's/PM//')
    json_file="$out_dir/${base_name}.json"
    echo "Saving JSON metadata for $mkv_file"
    ffprobe -v quiet -print_format json -show_format -show_streams "$mkv_file" > "$json_file"
    if [[ "$create_access_files" == "true" ]]; then
      output_prefix="$out_dir/${output_dir_name}"
      generate_access_mp4 "$mkv_file" "$title_num" "$output_prefix"
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

    for mkv_file in "$rip_dir"/*.mkv; do
        [[ -f "$mkv_file" ]] || continue
        base_name=$(basename "$mkv_file" .mkv)
        title_num=$(echo "$base_name" | grep -oE '(PM|VTS)[0-9]{2}' | grep -oE '[0-9]{2}')
        [[ -z "$title_num" ]] && title_num="00"
        output_prefix="$rip_dir/${base_name%-*}"
        generate_access_mp4 "$mkv_file" "$title_num" "$output_prefix"
    done

    echo "All access files created."
}

echo "Current working directory: $(pwd)"
echo -n "Is this the directory where you want to perform DVD operations? (y/n): "
read yn
case "$yn" in
    [Yy]* )
        echo "Proceeding with main menu..."
        ;;
    [Nn]* )
        echo "- please exit (option 5)"
        echo "- change to the desired directory using cd"
        echo "- rerun this script."

        ;;
    * )
        echo "Please answer y or n."
        exit 1
        ;;
esac

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
    5)

# ---- Move the trace/log file to the output directory on exit ----
if [[ -n "$out_dir" && -d "$out_dir" && -n "$LOGFILE" && -f "$LOGFILE" ]]; then
    log_basename="${output_dir_name:-trace}-RF.log"
    new_logfile="${out_dir}/${log_basename}"
    mv "$LOGFILE" "$new_logfile"
    echo "Log file moved to: $new_logfile"
else
    echo "Log file not moved (output directory or log file missing)."
fi

echo "Exiting."

# Close and clean up the tee process safely
exec >/dev/tty 2>&1
exit 0
;;
*) echo "Invalid choice. Please select 1, 2, 3, 4, or 5." ;;
  esac
done
