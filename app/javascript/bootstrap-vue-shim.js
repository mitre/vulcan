// This is a simplified shim for BootstrapVue that provides basic components
// without importing the full library
import Vue from 'vue';

console.log('Bootstrap Vue shim loading');

// Debug log for component mounting
const logMount = (componentName) => {
  console.log(`[DEBUG] ${componentName} component mounted`);
};

// Define basic components that match BootstrapVue naming
const BCard = {
  name: 'BCard',
  functional: false,
  props: {
    title: String,
    noBody: Boolean
  },
  template: `
    <div class="card">
      <div v-if="title" class="card-header">{{ title }}</div>
      <template v-if="noBody">
        <slot></slot>
      </template>
      <div v-else class="card-body">
        <slot></slot>
      </div>
    </div>
  `,
  mounted() {
    logMount('BCard');
  }
};


const BTabs = {
  name: 'BTabs',
  functional: false,
  props: {
    card: Boolean,
    fill: Boolean,
    pills: Boolean
  },
  data() {
    return {
      activeTab: 0,
      tabs: []
    };
  },
  mounted() {
    logMount('BTabs');
    // Find all tab components
    this.tabs = this.$children.filter(child => child.$options.name === 'BTab');
    console.log('Found tabs:', this.tabs.length);
    
    // Set initial active tab
    const activeTabIndex = this.tabs.findIndex(tab => tab.active);
    if (activeTabIndex >= 0) {
      this.activeTab = activeTabIndex;
    }
  },
  template: `
    <div class="tabs-container">
      <ul class="nav" :class="{'nav-tabs': !pills, 'nav-pills': pills, 'nav-fill': fill}">
        <li v-for="(tab, index) in tabs" :key="index" class="nav-item">
          <a class="nav-link" :class="{active: activeTab === index}" href="#" @click.prevent="activeTab = index">
            {{ tab.title || 'Tab ' + (index + 1) }}
          </a>
        </li>
      </ul>
      <div class="tab-content" :class="{'card-body': card}">
        <slot></slot>
      </div>
    </div>
  `
};

const BTab = {
  name: 'BTab',
  functional: false,
  props: {
    title: String,
    active: Boolean
  },
  mounted() {
    logMount(`BTab (${this.title || 'untitled'})`);
  },
  template: `
    <div class="tab-pane">
      <slot></slot>
    </div>
  `
};

const BInputGroup = {
  name: 'BInputGroup',
  functional: false,
  template: `
    <div class="input-group">
      <slot></slot>
    </div>
  `
};

const BInputGroupPrepend = {
  name: 'BInputGroupPrepend',
  functional: false,
  template: `
    <div class="input-group-prepend">
      <slot></slot>
    </div>
  `
};

const BInputGroupText = {
  name: 'BInputGroupText',
  functional: false,
  template: `
    <span class="input-group-text">
      <slot></slot>
    </span>
  `
};

const BFormInput = {
  name: 'BFormInput',
  functional: false,
  props: {
    id: String,
    type: {
      type: String,
      default: 'text'
    },
    placeholder: String,
    value: [String, Number]
  },
  template: `
    <input :id="id" :type="type" class="form-control" :placeholder="placeholder" :value="value" @input="$emit('input', $event.target.value)">
  `
};

// New component: BFormCheckbox
const BFormCheckbox = {
  name: 'BFormCheckbox',
  functional: false,
  props: {
    id: String,
    value: Boolean,
    disabled: Boolean,
    size: String,
    switch: Boolean,
    checked: Boolean
  },
  model: {
    prop: 'value',
    event: 'input'
  },
  data() {
    return {
      localChecked: this.value || this.checked
    };
  },
  watch: {
    value(newVal) {
      this.localChecked = newVal;
    }
  },
  methods: {
    handleChange(event) {
      this.localChecked = event.target.checked;
      this.$emit('input', this.localChecked);
      this.$emit('change', this.localChecked);
    }
  },
  mounted() {
    logMount('BFormCheckbox');
  },
  template: `
    <div class="custom-control" :class="[
      switch ? 'custom-switch' : 'custom-checkbox',
      size === 'lg' ? 'custom-control-lg' : ''
    ]">
      <input 
        type="checkbox" 
        class="custom-control-input" 
        :id="id || 'checkbox-' + this._uid" 
        :disabled="disabled"
        :checked="localChecked"
        @change="handleChange"
      >
      <label class="custom-control-label" :for="id || 'checkbox-' + this._uid">
        <slot></slot>
      </label>
    </div>
  `
};

// New component: BLink
const BLink = {
  name: 'BLink',
  functional: false,
  props: {
    href: String,
    to: String,
    target: String,
    rel: String,
    activeClass: String
  },
  template: `
    <a 
      :href="href" 
      :target="target" 
      :rel="rel"
      @click="$emit('click', $event)"
    >
      <slot></slot>
    </a>
  `,
  mounted() {
    logMount('BLink');
  }
};

// New component: BTable
const BTable = {
  name: 'BTable',
  functional: false,
  props: {
    items: {
      type: Array,
      default: () => []
    },
    fields: {
      type: Array,
      default: () => []
    },
    perPage: {
      type: Number,
      default: 10
    },
    currentPage: {
      type: Number,
      default: 1
    },
    sortIconLeft: Boolean,
    hover: Boolean,
    responsive: {
      type: [Boolean, String],
      default: false
    },
    id: String
  },
  data() {
    return {
      sortBy: null,
      sortDesc: false
    };
  },
  computed: {
    tableClasses() {
      return [
        'table', 
        this.hover ? 'table-hover' : '',
        this.responsive === true ? 'table-responsive' : '',
        typeof this.responsive === 'string' ? `table-responsive-${this.responsive}` : ''
      ];
    },
    displayedItems() {
      // Calculate displayed items based on pagination
      const start = (this.currentPage - 1) * this.perPage;
      const end = start + this.perPage;
      return this.items.slice(start, end);
    }
  },
  mounted() {
    logMount('BTable');
  },
  template: `
    <div>
      <table :id="id" class="table" :class="tableClasses">
        <thead>
          <tr>
            <th v-for="field in fields" :key="field.key">
              {{ field.label || field.key }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, index) in displayedItems" :key="index">
            <td v-for="field in fields" :key="field.key">
              <slot :name="'cell(' + field.key + ')'" :item="item" :index="index" :field="field">
                {{ item[field.key] }}
              </slot>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  `
};

// New component: BPagination
const BPagination = {
  name: 'BPagination',
  functional: false,
  props: {
    totalRows: {
      type: Number,
      default: 0
    },
    perPage: {
      type: Number,
      default: 10
    },
    value: {
      type: Number,
      default: 1
    },
    ariaControls: String
  },
  computed: {
    pageCount() {
      return Math.ceil(this.totalRows / this.perPage);
    },
    pages() {
      const pages = [];
      const maxPages = Math.min(5, this.pageCount);
      let startPage = Math.max(1, this.currentPage - 2);
      const endPage = Math.min(this.pageCount, startPage + maxPages - 1);
      
      // Adjust start page if end page is maximum page count
      startPage = Math.max(1, endPage - maxPages + 1);
      
      for (let i = startPage; i <= endPage; i++) {
        pages.push(i);
      }
      
      return pages;
    },
    currentPage: {
      get() {
        return this.value;
      },
      set(value) {
        this.$emit('input', value);
      }
    }
  },
  methods: {
    setPage(page) {
      if (page >= 1 && page <= this.pageCount) {
        this.currentPage = page;
      }
    }
  },
  mounted() {
    logMount('BPagination');
  },
  template: `
    <ul class="pagination" :aria-controls="ariaControls">
      <li class="page-item" :class="{ disabled: currentPage <= 1 }">
        <a class="page-link" href="#" @click.prevent="setPage(currentPage - 1)">&laquo;</a>
      </li>
      <li v-for="page in pages" :key="page" class="page-item" :class="{ active: page === currentPage }">
        <a class="page-link" href="#" @click.prevent="setPage(page)">{{ page }}</a>
      </li>
      <li class="page-item" :class="{ disabled: currentPage >= pageCount }">
        <a class="page-link" href="#" @click.prevent="setPage(currentPage + 1)">&raquo;</a>
      </li>
    </ul>
  `
};

// New component: BTooltip directive
Vue.directive('b-tooltip', {
  bind(el, binding) {
    // Store tooltip information on the element
    el.tooltipTitle = binding.value || '';
    el.tooltipPlacement = binding.modifiers.top ? 'top' :
                         binding.modifiers.bottom ? 'bottom' :
                         binding.modifiers.left ? 'left' : 'right';
    
    // For hover trigger
    if (binding.modifiers.hover) {
      el.addEventListener('mouseenter', () => {
        // Simple implementation - in real Bootstrap Vue this would create tooltips
        el.title = el.tooltipTitle;
      });
      
      el.addEventListener('mouseleave', () => {
        el.title = '';
      });
    }
  }
});

// Additional components needed
const BCardBody = {
  name: 'BCardBody',
  functional: false,
  template: `
    <div class="card-body">
      <slot></slot>
    </div>
  `
};

const BCardText = {
  name: 'BCardText',
  functional: false,
  template: `
    <div class="card-text">
      <slot></slot>
    </div>
  `
};

const BButton = {
  name: 'BButton',
  functional: false,
  props: {
    variant: String,
    size: String,
    disabled: Boolean,
    block: Boolean,
    href: String,
    to: String,
    type: String
  },
  template: `
    <button 
      class="btn" 
      :class="[
        variant ? 'btn-' + variant : '',
        size ? 'btn-' + size : '',
        block ? 'btn-block' : ''
      ]"
      :disabled="disabled"
      :href="href"
      :type="type || 'button'"
      @click="$emit('click', $event)"
    >
      <slot></slot>
    </button>
  `
};

const BBadge = {
  name: 'BBadge',
  functional: false,
  props: {
    variant: String,
    pill: Boolean
  },
  template: `
    <span 
      class="badge" 
      :class="[
        variant ? 'badge-' + variant : '',
        pill ? 'badge-pill' : ''
      ]"
    >
      <slot></slot>
    </span>
  `
};

// Quick diagnostic component
const BDiagnostic = {
  name: 'BDiagnostic',
  functional: false,
  template: `
    <div class="bs-diagnostic p-3 mb-3 border rounded bg-light">
      <h5>Bootstrap-Vue Shim Diagnostic</h5>
      <p class="mb-2">If you can see this component, the Bootstrap-Vue shim is working!</p>
      <div class="btn-toolbar">
        <button class="btn btn-primary mr-2">Primary Button</button>
        <button class="btn btn-secondary">Secondary Button</button>
      </div>
    </div>
  `,
  mounted() {
    logMount('BDiagnostic');
  }
};

// Register components directly with Vue to avoid vue-loader issues
Vue.component('b-card', BCard);
Vue.component('b-card-text', BCardText);
Vue.component('b-card-body', BCardBody);
Vue.component('b-tabs', BTabs);
Vue.component('b-tab', BTab);
Vue.component('b-input-group', BInputGroup);
Vue.component('b-input-group-prepend', BInputGroupPrepend);
Vue.component('b-input-group-text', BInputGroupText);
Vue.component('b-form-input', BFormInput);
Vue.component('b-form-checkbox', BFormCheckbox);
Vue.component('b-button', BButton);
Vue.component('b-badge', BBadge);
Vue.component('b-diagnostic', BDiagnostic);
Vue.component('b-link', BLink);
Vue.component('b-table', BTable);
Vue.component('b-pagination', BPagination);

console.log('Bootstrap Vue shim components registered directly');

// Define proper plugin structure
const BootstrapVueShim = {
  install(Vue) {
    console.log('Installing Bootstrap Vue shim components');
    Vue.component('b-card', BCard);
    Vue.component('b-card-text', BCardText);
    Vue.component('b-card-body', BCardBody);
    Vue.component('b-tabs', BTabs);
    Vue.component('b-tab', BTab);
    Vue.component('b-input-group', BInputGroup);
    Vue.component('b-input-group-prepend', BInputGroupPrepend);
    Vue.component('b-input-group-text', BInputGroupText);
    Vue.component('b-form-input', BFormInput);
    Vue.component('b-form-checkbox', BFormCheckbox);
    Vue.component('b-button', BButton);
    Vue.component('b-badge', BBadge);
    Vue.component('b-diagnostic', BDiagnostic);
    Vue.component('b-link', BLink);
    Vue.component('b-table', BTable);
    Vue.component('b-pagination', BPagination);
    console.log('Bootstrap Vue shim components installed via plugin');
  }
};

export default BootstrapVueShim;