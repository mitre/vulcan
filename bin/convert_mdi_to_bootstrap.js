#!/usr/bin/env node

/**
 * Script to convert Material Design Icons to Bootstrap Icons in Vue components
 * 
 * This script scans for Vue components using MDI icons and converts them to use Bootstrap Icons
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const COMPONENTS_DIR = path.resolve(__dirname, '../app/javascript/components');
const BACKUP_DIR = path.resolve(__dirname, `../icon-conversion-backups-${new Date().toISOString().replace(/:/g, '-')}`);

// Create backup directory
fs.mkdirSync(BACKUP_DIR, { recursive: true });
console.log(`Backup directory created: ${BACKUP_DIR}`);

// Icon mapping from MDI to Bootstrap Icons
const iconMap = {
  'mdi-information': 'info',
  'mdi-menu-down': 'chevron-down',
  'mdi-menu-up': 'chevron-up',
  'mdi-magnify': 'search',
  'mdi-trash-can': 'trash',
  'mdi-lock': 'lock',
  'mdi-plus': 'plus',
  'mdi-close': 'x',
  'mdi-file-find': 'file-earmark-search',
  'mdi-delta': 'triangle',
  'mdi-content-copy': 'clipboard',
  'mdi-cancel': 'x-circle',
  'mdi-stamper': 'stamp',
  'mdi-file-upload-outline': 'file-earmark-arrow-up',
  'mdi-source-fork': 'diagram-3',
  'mdi-radar': 'broadcast',
  'mdi-bell-outline': 'bell',
  'mdi-account-circle': 'person-circle',
  'mdi-wrench': 'wrench',
  'mdi-account-arrow-right': 'person-arrow-right',
  'mdi-file-document-edit-outline': 'file-earmark-text',
  'mdi-open-in-new': 'box-arrow-up-right',
  'mdi-delete': 'trash',
  'mdi-download': 'download',
  'mdi-check': 'check',
  'mdi-arrow-down-drop-circle': 'arrow-down-circle',
  'mdi-arrow-up-drop-circle': 'arrow-up-circle',
  'mdi-close-thick': 'x-lg',
  'mdi-collapse-all': 'arrows-collapse',
  'mdi-clipboard-text': 'clipboard-check',
  'mdi-chevron-right': 'chevron-right'
};

// Find all Vue files with MDI icons
console.log('Searching for Vue files with MDI icons...');
const output = execSync('grep -l "class=\\"mdi mdi-" --include="*.vue" -r ' + COMPONENTS_DIR).toString();
const filesToProcess = output.trim().split('\n').filter(file => file);

console.log(`Found ${filesToProcess.length} files to process.`);

// Process each file
filesToProcess.forEach(file => {
  console.log(`Processing: ${file}`);
  
  // Create backup
  const fileName = path.basename(file);
  const backupPath = path.join(BACKUP_DIR, fileName);
  fs.copyFileSync(file, backupPath);
  
  // Read file content
  let content = fs.readFileSync(file, 'utf8');
  let modificationsCount = 0;
  
  // Find all MDI icon usages
  const mdiRegex = /<i\s+class="mdi\s+mdi-([a-z0-9-]+)"[^>]*>\s*<\/i>|<i\s+class="mdi\s+mdi-([a-z0-9-]+)"[^>]*\/>/g;
  let match;
  
  // For each match
  while ((match = mdiRegex.exec(content)) !== null) {
    const fullMatch = match[0];
    const iconName = match[1] || match[2]; // Get the captured icon name
    const mdiIcon = 'mdi-' + iconName;
    
    // Check if we have a mapping for this icon
    if (iconMap[mdiIcon]) {
      const bootstrapIcon = iconMap[mdiIcon];
      const replacement = `<b-icon icon="${bootstrapIcon}"></b-icon>`;
      
      // Replace in content
      content = content.replace(fullMatch, replacement);
      modificationsCount++;
    } else {
      console.warn(`WARNING: Unknown icon 'mdi-${iconName}' in file ${file}`);
    }
  }
  
  // Save modified content
  fs.writeFileSync(file, content, 'utf8');
  
  console.log(`✅ Modified ${modificationsCount} icon occurrences in ${file}`);
});

console.log(`\nConversion complete! 
- Processed ${filesToProcess.length} files
- Backups stored in ${BACKUP_DIR}
- Please check the conversion results before committing.`);