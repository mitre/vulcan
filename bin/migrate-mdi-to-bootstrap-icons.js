#!/usr/bin/env node

/**
 * Script to assist with migrating from Material Design Icons to Bootstrap Icons
 * 
 * This script will:
 * 1. Create a mapping between common MDI icons and their Bootstrap Icons equivalents
 * 2. Log all files that use MDI icons
 * 3. Provide the replacement code for each MDI icon usage
 * 
 * Usage: node bin/migrate-mdi-to-bootstrap-icons.js
 */

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

// Map of MDI icon names to Bootstrap icon names
const iconMap = {
  // Original mappings
  'home': 'house',
  'radar': 'broadcast',
  'account': 'person',
  'cog': 'gear',
  'folder': 'folder',
  'shield': 'shield',
  'file-document': 'file-text',
  'book': 'book',
  'alert': 'exclamation-triangle',
  'check': 'check',
  'close': 'x',
  'plus': 'plus',
  'minus': 'dash',
  'pencil': 'pencil',
  'trash-can': 'trash',
  'magnify': 'search',
  'format-list-bulleted': 'list-ul',
  'arrow-left': 'arrow-left',
  'arrow-right': 'arrow-right',
  'arrow-up': 'arrow-up',
  'arrow-down': 'arrow-down',
  'refresh': 'arrow-repeat',
  'clock': 'clock',
  'calendar': 'calendar',
  'eye': 'eye',
  'eye-off': 'eye-slash',
  'lock': 'lock',
  'lock-open': 'unlock',
  'filter': 'funnel',
  'star': 'star',
  'heart': 'heart',
  'information': 'info',
  'bell': 'bell',
  'delete': 'trash',
  'content-save': 'save',
  'cloud-upload': 'cloud-upload',
  'cloud-download': 'cloud-download',
  'tag': 'tag',
  'link': 'link',
  'image': 'image',
  'comment': 'chat',
  'send': 'send',
  'settings': 'gear',
  'download': 'download',
  'upload': 'upload',
  'printer': 'printer',
  'logout': 'box-arrow-right',
  'login': 'box-arrow-in-right',
  
  // Additional mappings based on our scan
  'menu-down': 'chevron-down',
  'menu-up': 'chevron-up',
  'file-find': 'file-earmark-search',
  'delta': 'triangle',
  'content-copy': 'clipboard',
  'cancel': 'x-circle',
  'stamper': 'stamp',
  'file-upload-outline': 'file-earmark-arrow-up',
  'source-fork': 'diagram-3',
  'bell-outline': 'bell',
  'account-circle': 'person-circle',
  'wrench': 'wrench',
  'account-arrow-right': 'person-arrow-right',
  'file-document-edit-outline': 'file-earmark-text',
  'open-in-new': 'box-arrow-up-right',
  'arrow-down-drop-circle': 'arrow-down-circle',
  'arrow-up-drop-circle': 'arrow-up-circle',
  'close-thick': 'x-lg',
  'collapse-all': 'arrows-collapse',
  'clipboard-text': 'clipboard-check',
  'chevron-right': 'chevron-right'
};

// Find all files using MDI icons
console.log('Searching for files using MDI icons...');
exec('grep -r "mdi mdi-" --include="*.vue" app/javascript', (error, stdout, stderr) => {
  if (error) {
    console.error(`Error: ${error.message}`);
    return;
  }
  if (stderr) {
    console.error(`Error: ${stderr}`);
    return;
  }

  // Process results
  const lines = stdout.split('\n').filter(line => line.trim() !== '');
  const uniqueFiles = new Set();
  const iconUsage = new Map();
  
  // Parse out files and icon usages
  lines.forEach(line => {
    const filePath = line.split(':')[0];
    uniqueFiles.add(filePath);
    
    // Extract MDI icon names
    const matches = line.match(/mdi-([a-z0-9-]+)/g);
    if (matches) {
      matches.forEach(match => {
        const iconName = match.replace('mdi-', '');
        if (!iconUsage.has(iconName)) {
          iconUsage.set(iconName, 0);
        }
        iconUsage.set(iconName, iconUsage.get(iconName) + 1);
      });
    }
  });

  // Output summary
  console.log(`\nFound ${uniqueFiles.size} files using MDI icons:\n`);
  uniqueFiles.forEach(file => console.log(`- ${file}`));
  
  console.log(`\nFound ${iconUsage.size} unique MDI icons used:\n`);
  const iconUsageArray = Array.from(iconUsage.entries()).sort((a, b) => b[1] - a[1]);
  iconUsageArray.forEach(([icon, count]) => {
    const bsIcon = iconMap[icon] || '???';
    console.log(`- mdi-${icon} (${count} uses) → Bootstrap Icon: ${bsIcon}`);
  });
  
  // Output mapping guide
  console.log('\nReplacement guide:');
  console.log('For HTML elements like: <i class="mdi mdi-home"></i>');
  console.log('Replace with: <b-icon icon="house"></b-icon>');
  
  console.log('\nFor button with icon like:');
  console.log('<button><i class="mdi mdi-plus"></i> Add</button>');
  console.log('Replace with: <b-button><b-icon icon="plus"></b-icon> Add</b-button>');
  
  // Output icons that need mapping
  const missingIcons = iconUsageArray.filter(([icon]) => !iconMap[icon]).map(([icon]) => icon);
  if (missingIcons.length > 0) {
    console.log('\nWarning: The following MDI icons do not have a mapping yet:');
    missingIcons.forEach(icon => console.log(`- mdi-${icon}`));
    console.log('\nPlease add mappings for these icons to the iconMap in this script.');
    console.log('You can find Bootstrap Icons at: https://icons.getbootstrap.com/');
  }
  
  console.log('\nTo replace icons in a file:');
  console.log('1. Update the component to use IconsPlugin if not already');
  console.log('2. Find all occurrences of "mdi mdi-" in the file');
  console.log('3. Replace with the corresponding Bootstrap Icon using <b-icon>');
  console.log('4. Use the mapping above to find the equivalent icon names');
});