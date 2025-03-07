// Login page entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

console.log('Login.js initialized')

Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Create a diagnostic component
const DiagnosticComponent = {
  template: `
    <div class="diagnostic-container" style="padding: 20px; border: 1px solid #ccc; margin: 20px 0; background-color: #f8f9fa;">
      <h3>Vue Diagnostic Information</h3>
      <p style="color: green;">If you can see this, Vue is rendering correctly!</p>
      <div>
        <strong>Vue Version:</strong> {{ vueVersion }}
      </div>
      <div>
        <strong>Bootstrap Vue Components Registered:</strong> {{ registeredComponents.join(', ') }}
      </div>
      <div>
        <strong>DOM Structure:</strong>
        <pre style="background: #eee; padding: 10px; margin-top: 10px;">{{ domStructure }}</pre>
      </div>
      <div>
        <strong>CSS Verification:</strong>
        <button class="btn btn-primary" @click="testClick">Test Button (Click me!)</button>
      </div>
    </div>
  `,
  data() {
    return {
      vueVersion: Vue.version,
      registeredComponents: Object.keys(Vue.options.components),
      domStructure: 'Loading...',
      clickCount: 0
    }
  },
  methods: {
    testClick() {
      this.clickCount++
      alert(`Button clicked ${this.clickCount} times! Vue events are working.`)
    },
    getDomStructure() {
      const body = document.body
      let structure = ''
      
      function processNode(node, depth) {
        if (node.nodeType === 1) { // Element node
          const id = node.id ? `#${node.id}` : ''
          const classes = node.className ? `.${node.className.split(' ').join('.')}` : ''
          structure += '  '.repeat(depth) + `<${node.tagName.toLowerCase()}${id}${classes}>\n`
          
          if (depth < 3) { // Limit depth to avoid too much output
            for (let i = 0; i < node.children.length; i++) {
              processNode(node.children[i], depth + 1)
            }
          }
        }
      }
      
      processNode(body, 0)
      this.domStructure = structure
    }
  },
  mounted() {
    console.log('DiagnosticComponent mounted')
    this.$nextTick(() => {
      this.getDomStructure()
    })
  }
}

// Register the components globally
Vue.component("VueDiagnostic", DiagnosticComponent)

console.log('Login components registered')

document.addEventListener("turbolinks:load", () => {
  console.log('Turbolinks load event triggered for Login')
  
  // Mount login component
  const loginEl = document.getElementById("login")
  console.log('Login component element found:', !!loginEl)
  if (loginEl) {
    try {
      const loginApp = new Vue({
        el: "#login",
        mounted() {
          console.log('Login Vue instance mounted')
        }
      })
      console.log('Login Vue instance created successfully')
    } catch (error) {
      console.error('Error creating Login Vue instance:', error)
    }
  }
  
  // Create and mount diagnostic component
  console.log('Creating diagnostic element')
  let diagnosticEl = document.getElementById("vue-diagnostic")
  if (!diagnosticEl) {
    diagnosticEl = document.createElement('div')
    diagnosticEl.id = 'vue-diagnostic'
    diagnosticEl.innerHTML = '<vue-diagnostic></vue-diagnostic>'
    document.body.appendChild(diagnosticEl)
  }
  
  try {
    const diagnosticApp = new Vue({
      el: "#vue-diagnostic",
      mounted() {
        console.log('Diagnostic Vue instance mounted')
      }
    })
    console.log('Diagnostic Vue instance created successfully')
  } catch (error) {
    console.error('Error creating Diagnostic Vue instance:', error)
  }
})