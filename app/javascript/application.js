// Entry point for the build script in your package.json
import '@rails/ujs'
import 'turbolinks'
import '@rails/activestorage'
import './channels'

// Vue setup
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import BootstrapVue from 'bootstrap-vue'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)

// Import main components
// We'll gradually migrate components from their individual packs
