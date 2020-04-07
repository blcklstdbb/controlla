#!/bin/bash
# On Catalina you'll want to use !/bin/zsh


usage() {
    echo "usage: ./package_extraction.sh file destination_directory"
    exit 1
}


is_file_dir(){
  # $arg1 and $arg2 are local variables
	local arg1="$1"
  local arg2="$2"
  if [[ $(file --mime-type -b "$arg1") == inode/directory ]]; then
    arg1_basename=$(basename "$1")
    arg1_extension="${arg1_basename##*.}"
    if [[ $arg1_extension == "app" ]]; then
      file=$1
    else
      dest_directory=$1
    fi
  elif [[ -f "$arg1" ]]; then
    file=$1
  else
    echo "$arg1 is not a valid file or directory."
    exit 1
  fi
  if [[ $(file --mime-type -b "$arg2") == inode/directory ]]; then
    arg2_basename=$(basename "$2")
    arg2_extension="${arg2_basename##*.}"
    if [[ $arg2_extension == "app" ]]; then
      file=$2
    else
      dest_directory=$2
    fi
  else
    echo "$arg2 is not a valid file or directory."
    exit 1
  fi
}


check_file_type() {
  if [[ $(file --mime-type -b "$file") == application/x-xar ]]; then
    echo "Extracting pkg file: $file"
    extract_pkg "$file"
    extract_payloads
  elif [[ $(file --mime-type -b "$file") == inode/directory ]]; then
    sample_basename=$(basename "$file")
    sample_extension="${sample_basename##*.}"
    if [[ $sample_extension == "app" ]]; then
      copy_app "$file"
    else
      parse_folder "$file"
    fi
  else
    echo "Mounting dmg file: $file"
    mount_dmg
  fi
}


mount_dmg() {
  # Mount the disk image, but don't show it on the desktop & extract the name of the mounted volume
  volume=$(hdiutil attach -nobrowse "$file" | awk 'END {print substr($0, index($0,$3))}'; exit ${PIPESTATUS[0]})
  # volume=$(hdiutil attach -nobrowse "$file" | awk 'END {print $3}'; exit ${PIPESTATUS[0]})
  for dmg_item in "$volume"/*
  do
    # Copies the folder (.app or a folder masquerading as a .pkg file), not just the folders inside the .app file
    if [[ $(file --mime-type -b "$folder_item") == inode/directory ]]; then
      cp -pR "$dmg_item" "$dest_directory"
    else
      cp -pR "$dmg_item" "$dest_directory"
    fi
  done
  # quitely unmount the disk image
  hdiutil detach -quiet "$volume"
  echo "Successfully unmounted: $volume"
}


parse_folder() {
  for folder_item in "$1"/*
  do
      # Check if file is an .pkg file
    if [[ $(file --mime-type -b "$folder_item") == application/x-xar ]]; then
      extract_pkg "$folder_item"
    # This will check if the file (.app or .pkg) is actually a folder
    elif [[ $(file --mime-type -b "$folder_item") == inode/directory ]]; then
      if [[ "$folder_item" == "*.app" ]]; then
        # Copy the contents of the .app
        copy_app "$folder_item"
      else
        # Copy the Payload and Script files to the destiation folder
        echo "echo"
        extract_folder_payload "$folder_item"
      fi
    else
      mkdir -p "$dest_directory/$pkg_filename/contents"
      cp -np "$1" "$dest_directory/$pkg_filename/contents"
    fi
  done
}


extract_folder_payload() {
  # Copy the Payload and Script files to the destiation folder

  # Make the following folders if they don't alrady exist
  mkdir -p "$dest_directory/$pkg_filename/contents"
  mkdir -p "$dest_directory/$pkg_filename/payloads"
  for folder_payload_item in "$1"/*
  do
    # Check if file is a property list (plist) file
    if [[ $(file --mime-type -b "$folder_payload_item") == text/xml ]]; then
      # Copy the plist file if it doesn't already exist in the destination folder
      cp -np "$folder_payload_item" "$dest_directory/$pkg_filename/contents"
    # Copy the Bill of Materials info if it already doesn't in the destination folder
    elif [[ $(file --mime-type -b "$folder_payload_item") == application/octet-stream ]]; then
      lsbom "$folder_payload_item" > bom.txt
      cp -np bom.txt "$dest_directory/$pkg_filename/contents"
    # If not a Bom then it's probably a Payload or Script file that
    # will be copied and later expanded using cpio
    else
      # copy the Scripts or Payload file if it doesn't already exist in the destination folder
      cp -np "$folder_payload_item" "$dest_directory/$pkg_filename/payloads"
      # extract_payloads "$folder_payload_item" "$dest_directory/$pkg_filename/payloads"
      extract_payloads
    fi
  done
}


extract_pkg() {
  pkg_basename=$(basename "$1")
  pkg_filename="${pkg_basename%.*}"
  # Make the following folders if they don't alrady exist
  mkdir -p "$dest_directory/$pkg_filename/contents"
  mkdir -p "$dest_directory/$pkg_filename/payloads"
  mv "$1" "$dest_directory/$pkg_filename"
  xar -xf "$dest_directory/$pkg_filename/$pkg_basename" -C "$dest_directory/$pkg_filename/contents"
  # Check for nested pkg files
  for extracted_item in "$dest_directory/$pkg_filename/contents"/*
    do
      if [[ $(file --mime-type -b "$extracted_item") == application/x-xar ]]; then
      etracted_pkg_basename=$(basename "$extracted_item")
      etracted_pkg_filename="${e_pkg_basename%.*}"
      mkdir -p "$dest_directory/$pkg_filename/additional_packages/$etracted_pkg_filename"
      xar -xf "$1" -C "$dest_directory/$pkg_filename/additional_packages/$etracted_pkg_filename"
    elif [[ $(file --mime-type -b "$extracted_item") == application/octet-stream ]]; then
      lsbom "$extracted_item" > "$dest_directory/$pkg_filename/bom.txt"
    # We need this next elif statement in order to copy the payloads to a directory for the extract_payloads() function
    elif [[ $(file --mime-type -b "$extracted_item") == application/x-gzip ]]; then
      # copy the Scripts or Payload file if it doesn't already exist in the destination folder
      cp -np "$extracted_item" "$dest_directory/$pkg_filename/payloads"
    fi
  done
}


extract_payloads() {
  cd "$dest_directory/$pkg_filename/payloads"
  cpio -i < Scripts
  cpio -i < Payload
  for payload_item in "$(pwd)/Applications"/*
  do
    cp -ap "$payload_item"/ "$(pwd)/Applications"/
  done
}


copy_app() {
  app_basename=$(basename "$1")
  app_filename="${app_basename%.*}"
  # Make the following folder if it doesn't alrady exist
  mkdir -p "$dest_directory/$app_filename"
  cp -pR "$1" "$dest_directory/$app_filename"
}


##### Main
if [ $# -eq 2 ]; then
  is_file_dir "$1" "$2"
  check_file_type
  for item in "$dest_directory"/*
  do
    # Check if file is an .pkg file
    if [[ $(file --mime-type -b "$item") == application/x-xar ]]; then
      extract_pkg "$item"
      extract_payloads
    # This will check if the file (.app or .pkg) is actually a folder
    elif [[ $(file --mime-type -b "$item") == inode/directory ]]; then
      if [[ "$item" == "*.pkg" ]]; then
        # Copy the Payload and Script files to the destiation folder
        parse_folder "$item"
      elif [[ "$item" == "*.app" ]]; then
        app_basename=$(basename "$1")
        app_filename="${app_basename%.*}"
        # Make the following folder if it doesn't alrady exist
        mkdir -p "$dest_directory/$app_filename"
        cp -ap "$item"/ "$dest_directory/$app_filename"
      fi
    fi
  done
else
    usage
fi
