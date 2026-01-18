<script setup lang="ts">
/**
 * NewComponentModal.vue
 * Modal for creating new components, duplicating, or importing from files
 * Vue 3 Composition API + Bootstrap 5
 */
import { computed, ref } from 'vue'
import { useAppToast } from '@/composables'
import { http } from '@/services/http.service'

// Types
interface SRG {
  id: number
  title: string
  version: string
  displayed?: string
}

interface Project {
  id: number
  name: string
  components?: ComponentItem[]
  users?: User[]
}

interface ComponentItem {
  id: number
  name: string
  version?: string
  release?: string
  prefix: string
  title?: string
  description?: string
  security_requirements_guide_id: number
  based_on_title?: string
  displayed?: string
}

interface User {
  id: number
  name: string
  email: string
}

// Props
const props = withDefaults(defineProps<{
  spreadsheet_import?: boolean
  copy_component?: boolean
  component_to_duplicate?: number
  project_id: number
  project?: Project
  predetermined_prefix?: string
  predetermined_security_requirements_guide_id?: number | null
}>(), {
  spreadsheet_import: false,
  copy_component: false,
  predetermined_prefix: '',
  predetermined_security_requirements_guide_id: null,
})

// Emits
const emit = defineEmits<{
  projectUpdated: []
}>()

// Toast for notifications
const toast = useAppToast()

// State
const showModal = ref(false)
const loading = ref(false)
const selectedProjectId = ref(props.project_id)
const selectedComponentId = ref<number | null>(null)
const securityRequirementsGuideId = ref<number | null>(
  !props.copy_component && props.predetermined_security_requirements_guide_id
    ? props.predetermined_security_requirements_guide_id
    : null,
)
const securityRequirementsGuideDisplayed = ref('')
const name = ref('')
const version = ref('')
const release = ref('')
const title = ref('')
const description = ref('')
const prefix = ref(props.predetermined_prefix)
const slackChannelId = ref('')
const projects = ref<Project[]>([])
const components = ref<ComponentItem[]>([])
const srgs = ref<SRG[]>([])
const displayedSrgs = ref<SRG[]>([])
const file = ref<File | null>(null)
const adminName = ref('')
const adminEmail = ref('')
const potentialPocs = ref<User[]>(props.project?.users || [])

// Search inputs for autocomplete
const projectSearchQuery = ref(props.project?.name || '')
const componentSearchQuery = ref('')
const srgSearchQuery = ref('')
const pocSearchQuery = ref('')

// Computed
const newComponent = computed(() => !props.component_to_duplicate)

const buttonText = computed(() => {
  if (props.spreadsheet_import) return 'Import Component from File'
  if (props.copy_component) return 'Copy Component'
  if (newComponent.value) return 'Create a New Component'
  return 'Duplicate Component'
})

const submitText = computed(() => {
  if (props.spreadsheet_import) return 'Import Component'
  if (props.copy_component) return 'Copy Component'
  if (newComponent.value) return 'Create Component'
  return 'Duplicate Component'
})

const filteredProjects = computed(() => {
  const query = projectSearchQuery.value.toLowerCase()
  if (!query) return projects.value
  return projects.value.filter(p => p.name.toLowerCase().includes(query))
})

const filteredComponents = computed(() => {
  const query = componentSearchQuery.value.toLowerCase()
  if (!query) return components.value
  return components.value.filter(c => c.displayed?.toLowerCase().includes(query))
})

const filteredSrgs = computed(() => {
  const query = srgSearchQuery.value.toLowerCase()
  const srgList = props.copy_component ? displayedSrgs.value : srgs.value
  if (!query) return srgList
  return srgList.filter(s => s.displayed?.toLowerCase().includes(query))
})

const filteredPocs = computed(() => {
  const query = pocSearchQuery.value.toLowerCase()
  if (!query) return potentialPocs.value
  return potentialPocs.value.filter(u =>
    u.name.toLowerCase().includes(query) || u.email.toLowerCase().includes(query),
  )
})

// Utility function (replaces mixin)
function addDisplayNameToComponents(comps: ComponentItem[]): ComponentItem[] {
  return comps.map((component) => {
    const versionRelease = [
      component.version ? `Version ${component.version}` : '',
      component.release ? `Release ${component.release}` : '',
    ].filter(Boolean).join(', ')

    component.displayed = versionRelease
      ? `${component.name} (${versionRelease})`
      : component.name
    return component
  })
}

// Methods
function openModal() {
  // Reset form
  selectedProjectId.value = props.project_id
  selectedComponentId.value = null
  securityRequirementsGuideId.value = !props.copy_component && props.predetermined_security_requirements_guide_id
    ? props.predetermined_security_requirements_guide_id
    : null
  securityRequirementsGuideDisplayed.value = ''
  name.value = ''
  version.value = ''
  release.value = ''
  title.value = ''
  description.value = ''
  prefix.value = props.predetermined_prefix
  slackChannelId.value = ''
  file.value = null
  adminName.value = ''
  adminEmail.value = ''
  projectSearchQuery.value = props.project?.name || ''
  componentSearchQuery.value = ''
  srgSearchQuery.value = ''
  pocSearchQuery.value = ''

  // Set components if copying
  if (props.copy_component && props.project?.components) {
    components.value = addDisplayNameToComponents([...props.project.components])
  }
  else {
    components.value = []
  }

  displayedSrgs.value = []
  showModal.value = true
  fetchData()
}

function closeModal() {
  showModal.value = false
}

async function fetchData() {
  try {
    const [srgsResponse, projectsResponse] = await Promise.all([
      http.get('/srgs'),
      http.get('/projects'),
    ])

    srgs.value = srgsResponse.data.map((srg: SRG) => ({
      ...srg,
      displayed: `${srg.title} (${srg.version})`,
    }))
    projects.value = projectsResponse.data
  }
  catch (err) {
    toast.fromError(err)
  }
}

function selectProject(project: Project) {
  if (!selectedProjectId.value || selectedProjectId.value !== project.id) {
    selectedComponentId.value = null
    securityRequirementsGuideId.value = null
    securityRequirementsGuideDisplayed.value = ''
    srgSearchQuery.value = ''

    http.get(`/projects/${project.id}`)
      .then((response) => {
        components.value = addDisplayNameToComponents(response.data.components || [])
      })
      .catch(toast.fromError)
  }
  selectedProjectId.value = project.id
  projectSearchQuery.value = project.name
}

function selectComponent(component: ComponentItem) {
  selectedComponentId.value = component.id
  componentSearchQuery.value = component.displayed || component.name

  // Set SRG based on selected component
  securityRequirementsGuideId.value = component.security_requirements_guide_id
  const foundSrg = srgs.value.find(s => s.id === component.security_requirements_guide_id)
  securityRequirementsGuideDisplayed.value = foundSrg?.displayed || ''
  srgSearchQuery.value = foundSrg?.displayed || ''

  // Populate form fields
  name.value = component.name
  version.value = component.version || ''
  release.value = component.release || ''
  prefix.value = component.prefix
  title.value = component.title || ''
  description.value = component.description || ''

  // Filter SRGs to only show those matching the component's SRG title
  if (component.based_on_title) {
    displayedSrgs.value = srgs.value.filter(s => s.title === component.based_on_title)
  }
}

function selectSrg(srg: SRG) {
  securityRequirementsGuideId.value = srg.id
  srgSearchQuery.value = srg.displayed || ''
}

function selectPoc(user: User) {
  adminEmail.value = user.email
  adminName.value = user.name
  pocSearchQuery.value = user.name
}

function handleFileChange(event: Event) {
  const target = event.target as HTMLInputElement
  file.value = target.files?.[0] || null
}

async function createComponent() {
  // Validation
  if (!prefix.value && !props.spreadsheet_import) {
    toast.error('Please enter a prefix')
    return
  }
  if (!file.value && props.spreadsheet_import) {
    toast.error('Please select a spreadsheet to import')
    return
  }
  if (!securityRequirementsGuideId.value) {
    toast.error('Please select an SRG')
    return
  }
  if (!name.value) {
    toast.error('Please enter a name')
    return
  }

  loading.value = true

  const formData = new FormData()
  formData.append('component[security_requirements_guide_id]', String(securityRequirementsGuideId.value))
  formData.append('component[name]', name.value)

  if (!newComponent.value && props.component_to_duplicate) {
    formData.append('component[duplicate]', 'true')
    formData.append('component[id]', String(props.component_to_duplicate))
  }

  if (props.copy_component && selectedComponentId.value) {
    formData.append('component[copy_component]', 'true')
    formData.append('component[project_id]', String(props.project_id))
    formData.append('component[id]', String(selectedComponentId.value))
  }

  if (version.value) formData.append('component[version]', version.value)
  if (release.value) formData.append('component[release]', release.value)

  if (file.value) {
    formData.append('component[file]', file.value)
  }
  else {
    formData.append('component[prefix]', prefix.value)
  }

  if (title.value) formData.append('component[title]', title.value)
  if (description.value) formData.append('component[description]', description.value)
  if (adminName.value) formData.append('component[admin_name]', adminName.value)
  if (adminEmail.value) formData.append('component[admin_email]', adminEmail.value)
  if (slackChannelId.value) formData.append('component[slack_channel_id]', slackChannelId.value)

  try {
    const response = await http.post(`/projects/${props.project_id}/components`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    toast.fromResponse(response)
    closeModal()
    emit('projectUpdated')
  }
  catch (err) {
    toast.fromError(err)
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <span>
    <!-- Modal trigger button (slot) -->
    <span @click="openModal">
      <slot name="opener">
        <button class="btn btn-primary px-2 m-2">
          {{ buttonText }}
        </button>
      </slot>
    </span>

    <!-- Modal -->
    <Teleport to="body">
      <div
        v-if="showModal"
        class="modal fade show d-block"
        tabindex="-1"
        style="background-color: rgba(0,0,0,0.5);"
        @click.self="closeModal"
      >
        <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">{{ submitText }}</h5>
              <button
                type="button"
                class="btn-close"
                aria-label="Close"
                @click="closeModal"
              />
            </div>
            <div class="modal-body">
              <form @submit.prevent="createComponent">
                <!-- Select Project (for copy_component) -->
                <div v-if="copy_component" class="mb-3">
                  <label class="form-label">Select an existing Project to copy from</label>
                  <input
                    v-model="projectSearchQuery"
                    type="text"
                    class="form-control"
                    list="projectList"
                    placeholder="Search for an existing Project..."
                    @change="() => {
                      const found = projects.find(p => p.name === projectSearchQuery)
                      if (found) selectProject(found)
                    }"
                  >
                  <datalist id="projectList">
                    <option v-for="proj in filteredProjects" :key="proj.id" :value="proj.name" />
                  </datalist>
                </div>

                <!-- Select Component (for copy_component) -->
                <div v-if="copy_component" class="mb-3">
                  <label class="form-label">Select an existing Component to copy from</label>
                  <input
                    v-model="componentSearchQuery"
                    type="text"
                    class="form-control"
                    list="componentList"
                    placeholder="Search for an existing Component..."
                    :disabled="!selectedProjectId"
                    @change="() => {
                      const found = components.find(c => c.displayed === componentSearchQuery)
                      if (found) selectComponent(found)
                    }"
                  >
                  <datalist id="componentList">
                    <option v-for="comp in filteredComponents" :key="comp.id" :value="comp.displayed" />
                  </datalist>
                </div>

                <!-- Select SRG -->
                <div v-if="predetermined_security_requirements_guide_id == null" class="mb-3">
                  <label class="form-label">Select a Security Requirements Guide</label>
                  <input
                    v-model="srgSearchQuery"
                    type="text"
                    class="form-control"
                    list="srgList"
                    placeholder="Search for an SRG..."
                    @change="() => {
                      const found = srgs.find(s => s.displayed === srgSearchQuery)
                      if (found) selectSrg(found)
                    }"
                  >
                  <datalist id="srgList">
                    <option v-for="srg in filteredSrgs" :key="srg.id" :value="srg.displayed" />
                  </datalist>
                </div>

                <!-- Name -->
                <div class="mb-3">
                  <label class="form-label">Name</label>
                  <input
                    v-model="name"
                    type="text"
                    class="form-control"
                    placeholder="Component Name"
                    required
                    autocomplete="off"
                  >
                </div>

                <!-- Version and Release -->
                <div class="row mb-3">
                  <div class="col">
                    <label class="form-label">Version</label>
                    <input
                      v-model="version"
                      type="text"
                      class="form-control"
                      autocomplete="off"
                    >
                  </div>
                  <div class="col">
                    <label class="form-label">Release</label>
                    <input
                      v-model="release"
                      type="text"
                      class="form-control"
                      autocomplete="off"
                    >
                  </div>
                </div>

                <!-- File Import -->
                <div v-if="spreadsheet_import" class="mb-3">
                  <label class="form-label">Import Component from File</label>
                  <input
                    type="file"
                    class="form-control"
                    accept=".xlsx,.xls,.csv,.ods,.xml"
                    @change="handleFileChange"
                  >
                  <div class="form-text">
                    Import from SRG Spreadsheet (.xlsx, .xls, .csv, .ods) or XCCDF/STIG XML (.xml)
                  </div>
                </div>

                <!-- STIG ID Prefix -->
                <div v-else class="mb-3">
                  <label class="form-label">STIG ID Prefix</label>
                  <input
                    v-model="prefix"
                    type="text"
                    class="form-control"
                    placeholder="Example... ABCD-EF, ABCD-00"
                    required
                    autocomplete="off"
                  >
                  <div class="form-text">
                    STIG IDs for each control will be automatically generated based on this prefix value
                  </div>
                </div>

                <!-- Title -->
                <div class="mb-3">
                  <label class="form-label">Title</label>
                  <input
                    v-model="title"
                    type="text"
                    class="form-control"
                    placeholder="Component Title"
                    autocomplete="off"
                  >
                </div>

                <!-- Description -->
                <div class="mb-3">
                  <label class="form-label">Description</label>
                  <textarea
                    v-model="description"
                    class="form-control"
                    rows="3"
                    placeholder=""
                  />
                </div>

                <!-- Select PoC -->
                <div v-if="project" class="mb-3">
                  <label class="form-label">Select the Point of Contact</label>
                  <input
                    v-model="pocSearchQuery"
                    type="text"
                    class="form-control"
                    list="pocList"
                    placeholder="Search for eligible PoC..."
                    @change="() => {
                      const found = potentialPocs.find(u => u.name === pocSearchQuery)
                      if (found) selectPoc(found)
                    }"
                  >
                  <datalist id="pocList">
                    <option v-for="user in filteredPocs" :key="user.id" :value="user.name">
                      {{ user.email }}
                    </option>
                  </datalist>
                  <div class="form-text">
                    If no user selected, the PoC will be set to the user creating the component
                  </div>
                </div>

                <!-- Slack Channel ID -->
                <div class="mb-3">
                  <label class="form-label">Slack Channel ID</label>
                  <input
                    v-model="slackChannelId"
                    type="text"
                    class="form-control"
                    placeholder="Example... C123456, #general"
                    autocomplete="off"
                  >
                  <div class="form-text">
                    Provide a slack channel ID for slack notification about activities on this component
                  </div>
                </div>
              </form>
            </div>
            <div class="modal-footer">
              <button
                type="button"
                class="btn btn-secondary"
                @click="closeModal"
              >
                Cancel
              </button>
              <button
                type="button"
                class="btn btn-primary"
                :disabled="loading || !(securityRequirementsGuideId || component_to_duplicate) || (spreadsheet_import && !file)"
                @click="createComponent"
              >
                {{ loading ? 'Loading...' : submitText }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </span>
</template>
