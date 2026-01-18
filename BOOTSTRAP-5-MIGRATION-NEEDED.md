# Bootstrap 5 & Bootstrap-Vue-Next Migration Issues

## Critical Fixes Needed

### 1. Navbar (DONE)
- ✅ Changed `type="dark" variant="dark"` to `variant="dark" v-b-color-mode="'dark'"`

### 2. BInputGroup Components (BREAKING)
- ❌ `BInputGroupPrepend` and `BInputGroupAppend` REMOVED
- Fix: Use default slot in BInputGroup
- Affects: SrgIdSearch component

### 3. BFormRow (REMOVED)
- ❌ Component doesn't exist
- Fix: Use BRow/BCol grid system instead
- Affects: Multiple forms

### 4. Icons (CRITICAL)
- ❌ b-icon component doesn't exist in Bootstrap-Vue-Next
- Fix: Use Bootstrap Icons directly: `<i class="bi bi-name"></i>`
- Affects: 30+ components

### 5. Modal v-model
- Old: `visible` prop
- New: `v-model` for show/hide
- Affects: All modals

### 6. Tooltips
- Old: `v-b-tooltip.hover.html`
- New: Need to check if directive changed
- Affects: Many components

## Next Steps

1. Fix BInputGroup in SrgIdSearch (navbar search won't work)
2. Convert all b-icon to <i class="bi..."> manually
3. Update modal visibility props
4. Test each component after fix

## Files Needing Manual Fixes

See `rg "b-icon" app/javascript/components` for list
