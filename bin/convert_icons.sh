#!/bin/bash

# Script to convert Material Design Icons to Bootstrap Icons in Vue components
# Created: $(date)

# Set the base directory for Vue components
COMPONENTS_DIR="/Users/alippold/github/mitre/vulcan/app/javascript/components"
BACKUP_DIR="/Users/alippold/github/mitre/vulcan/icon-conversion-backups-$(date +%Y%m%d%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Backup directory created: $BACKUP_DIR"

# Function to convert MDI icon to Bootstrap icon
convert_icon() {
  local file=$1
  local backup_file="$BACKUP_DIR/$(basename "$file")"
  
  # Create backup
  cp "$file" "$backup_file"
  
  # Map of MDI icons to Bootstrap icons
  declare -A icon_map
  icon_map["mdi-information"]="info"
  icon_map["mdi-menu-down"]="chevron-down"
  icon_map["mdi-menu-up"]="chevron-up"
  icon_map["mdi-magnify"]="search"
  icon_map["mdi-trash-can"]="trash"
  icon_map["mdi-lock"]="lock"
  icon_map["mdi-plus"]="plus"
  icon_map["mdi-close"]="x"
  icon_map["mdi-file-find"]="file-earmark-search"
  icon_map["mdi-delta"]="triangle"
  icon_map["mdi-content-copy"]="clipboard"
  icon_map["mdi-cancel"]="x-circle"
  icon_map["mdi-stamper"]="stamp"
  icon_map["mdi-file-upload-outline"]="file-earmark-arrow-up"
  icon_map["mdi-source-fork"]="diagram-3"
  icon_map["mdi-radar"]="broadcast"
  icon_map["mdi-bell-outline"]="bell"
  icon_map["mdi-account-circle"]="person-circle"
  icon_map["mdi-wrench"]="wrench"
  icon_map["mdi-account-arrow-right"]="person-arrow-right"
  icon_map["mdi-file-document-edit-outline"]="file-earmark-text"
  icon_map["mdi-open-in-new"]="box-arrow-up-right"
  icon_map["mdi-delete"]="trash"
  icon_map["mdi-download"]="download"
  icon_map["mdi-check"]="check"
  icon_map["mdi-arrow-down-drop-circle"]="arrow-down-circle"
  icon_map["mdi-arrow-up-drop-circle"]="arrow-up-circle"
  icon_map["mdi-close-thick"]="x-lg"
  icon_map["mdi-collapse-all"]="arrows-collapse"
  icon_map["mdi-clipboard-text"]="clipboard-check"
  icon_map["mdi-chevron-right"]="chevron-right"
  
  # Temporary file for processing
  local temp_file=$(mktemp)
  
  # Read each line of the file
  while IFS= read -r line; do
    # Check if line contains an MDI icon
    if [[ $line == *"class=\"mdi mdi-"* ]]; then
      # Extract the MDI icon name
      mdi_icon=$(echo "$line" | grep -o 'mdi-[a-z0-9-]*' | head -1)
      
      # Check if we have a mapping for this icon
      if [[ -n "${icon_map[$mdi_icon]}" ]]; then
        bootstrap_icon="${icon_map[$mdi_icon]}"
        
        # Replace the MDI icon tag with Bootstrap icon tag
        # Handle both self-closing and regular tags
        if [[ $line == *"/>"* ]]; then
          # Self-closing tag
          modified_line=$(echo "$line" | sed -E "s|<i class=\"mdi $mdi_icon[^>]*/>|<b-icon icon=\"$bootstrap_icon\"></b-icon>|g")
        else
          # Regular tag
          modified_line=$(echo "$line" | sed -E "s|<i class=\"mdi $mdi_icon[^>]*>.*?</i>|<b-icon icon=\"$bootstrap_icon\"></b-icon>|g")
        fi
        
        echo "$modified_line" >> "$temp_file"
      else
        # Log unknown icon
        echo "WARNING: Unknown icon '$mdi_icon' in file $file" >&2
        echo "$line" >> "$temp_file"
      fi
    else
      # Line doesn't contain an MDI icon, write it unchanged
      echo "$line" >> "$temp_file"
    fi
  done < "$file"
  
  # Replace original file with modified content
  mv "$temp_file" "$file"
  
  # Validate the file (basic syntax check)
  if grep -q "<template" "$file" && grep -q "</template>" "$file"; then
    echo "✅ Successfully converted: $file"
  else
    echo "❌ Error: Template tags missing after conversion in $file. Restoring from backup."
    cp "$backup_file" "$file"
  fi
}

# Find all Vue files containing MDI icons
echo "Searching for Vue files with MDI icons..."
FILES=$(grep -l "class=\"mdi mdi-" --include="*.vue" -r "$COMPONENTS_DIR")

# Check if any files were found
if [ -z "$FILES" ]; then
  echo "No files containing MDI icons were found."
  exit 0
fi

# Convert icons in each file
echo "Converting icons in $(echo "$FILES" | wc -l | tr -d ' ') files..."
echo "$FILES" | while read -r file; do
  echo "Processing: $file"
  convert_icon "$file"
done

echo "Conversion complete. Backups stored in $BACKUP_DIR"
echo "Please check the conversion results before committing."