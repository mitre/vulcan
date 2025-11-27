// Shared Bootstrap-Vue-Next component imports
// Import all commonly used components to avoid repetition
import {
  // Layout
  BContainer,
  BRow,
  BCol,
  
  // Navigation
  BNavbar,
  BNavbarBrand,
  BNavbarToggle,
  BNavbarNav,
  BNavItem,
  BNavItemDropdown,
  
  // Buttons & Links
  BButton,
  BButtonGroup,
  BLink,
  BCloseButton,
  
  // Dropdowns
  BDropdown,
  BDropdownItem,
  BDropdownDivider,
  BDropdownHeader,
  
  // Forms
  BForm,
  BFormGroup,
  BFormInput,
  BFormTextarea,
  BFormSelect,
  BFormSelectOption,
  BFormCheckbox,
  BFormCheckboxGroup,
  BFormRadio,
  BFormRadioGroup,
  BFormFile,
  BFormInvalidFeedback,
  BFormValidFeedback,
  BInputGroup,
  BInputGroupText,
  
  // Cards & Content
  BCard,
  BCardHeader,
  BCardBody,
  BCardFooter,
  BCardTitle,
  BCardText,
  
  // Tables
  BTable,
  BPagination,
  
  // Alerts & Badges
  BAlert,
  BBadge,
  
  // Modals & Overlays
  BModal,
  BOverlay,
  BPopover,
  BTooltip,
  
  // Tabs
  BTabs,
  BTab,
  
  // Lists
  BListGroup,
  BListGroupItem,
  
  // Other
  BCollapse,
  BProgress,
  BProgressBar,
  BBreadcrumb,
  BBreadcrumbItem,
  
  // Directives
  vBTooltip,
  vBPopover,
  vBToggle
} from 'bootstrap-vue-next';

export function registerComponents(app) {
  // Layout
  app.component('BContainer', BContainer);
  app.component('BRow', BRow);
  app.component('BCol', BCol);
  
  // Navigation
  app.component('BNavbar', BNavbar);
  app.component('BNavbarBrand', BNavbarBrand);
  app.component('BNavbarToggle', BNavbarToggle);
  app.component('BNavbarNav', BNavbarNav);
  app.component('BNavItem', BNavItem);
  app.component('BNavItemDropdown', BNavItemDropdown);
  
  // Buttons & Links
  app.component('BButton', BButton);
  app.component('BButtonGroup', BButtonGroup);
  app.component('BLink', BLink);
  app.component('BCloseButton', BCloseButton);
  
  // Dropdowns
  app.component('BDropdown', BDropdown);
  app.component('BDropdownItem', BDropdownItem);
  app.component('BDropdownDivider', BDropdownDivider);
  app.component('BDropdownHeader', BDropdownHeader);
  
  // Forms
  app.component('BForm', BForm);
  app.component('BFormGroup', BFormGroup);
  app.component('BFormInput', BFormInput);
  app.component('BFormTextarea', BFormTextarea);
  app.component('BFormSelect', BFormSelect);
  app.component('BFormSelectOption', BFormSelectOption);
  app.component('BFormCheckbox', BFormCheckbox);
  app.component('BFormCheckboxGroup', BFormCheckboxGroup);
  app.component('BFormRadio', BFormRadio);
  app.component('BFormRadioGroup', BFormRadioGroup);
  app.component('BFormFile', BFormFile);
  app.component('BFormInvalidFeedback', BFormInvalidFeedback);
  app.component('BFormValidFeedback', BFormValidFeedback);
  app.component('BInputGroup', BInputGroup);
  app.component('BInputGroupText', BInputGroupText);
  
  // Cards & Content
  app.component('BCard', BCard);
  app.component('BCardHeader', BCardHeader);
  app.component('BCardBody', BCardBody);
  app.component('BCardFooter', BCardFooter);
  app.component('BCardTitle', BCardTitle);
  app.component('BCardText', BCardText);
  
  // Tables
  app.component('BTable', BTable);
  app.component('BPagination', BPagination);
  
  // Alerts & Badges
  app.component('BAlert', BAlert);
  app.component('BBadge', BBadge);
  
  // Modals & Overlays
  app.component('BModal', BModal);
  app.component('BOverlay', BOverlay);
  app.component('BPopover', BPopover);
  app.component('BTooltip', BTooltip);
  
  // Tabs
  app.component('BTabs', BTabs);
  app.component('BTab', BTab);
  
  // Lists
  app.component('BListGroup', BListGroup);
  app.component('BListGroupItem', BListGroupItem);
  
  // Other
  app.component('BCollapse', BCollapse);
  app.component('BProgress', BProgress);
  app.component('BProgressBar', BProgressBar);
  app.component('BBreadcrumb', BBreadcrumb);
  app.component('BBreadcrumbItem', BBreadcrumbItem);
  
  // Directives
  app.directive('BTooltip', vBTooltip);
  app.directive('BPopover', vBPopover);
  app.directive('BToggle', vBToggle);
}
