<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <div class="px-3">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <div>
          <h1 class="h3 mb-1">Component Settings</h1>
          <p class="text-muted mb-0">
            <strong>{{ component.name }}</strong>
            <span v-if="component.version || component.release" class="ml-1">
              v{{ component.version }}r{{ component.release }}
            </span>
            <span class="ml-2">— {{ project.name }}</span>
          </p>
        </div>
        <div>
          <b-button :href="`/components/${component.id}`" variant="outline-secondary" size="sm">
            <b-icon icon="arrow-left" /> Back to Component Editor
          </b-button>
        </div>
      </div>

      <b-form @submit.prevent="save">
        <!-- ───── Public Comment Period ──────────────────────────── -->
        <!-- Promoted to top section: this is the active workflow lifecycle
             admins return to manage repeatedly, vs. Identity / PoC which
             are usually set once at component creation. Page header above
             already shows component name + version, so demoting Identity
             does not lose orientation. -->
        <b-card no-body class="mb-3">
          <b-card-header class="bg-light">
            <h2 class="h5 mb-0">Public Comment Period</h2>
            <small class="text-muted"
              >Lifecycle of the public-comment window. The banner at the top of the component page
              reflects this state.</small
            >
          </b-card-header>
          <b-card-body>
            <b-form-group label="Phase" label-for="settings-comment-phase">
              <b-form-radio-group
                id="settings-comment-phase"
                v-model="form.comment_phase"
                :options="phaseOptions"
                stacked
                aria-label="Comment phase"
              />
            </b-form-group>
            <b-form-row>
              <b-col>
                <b-form-group label="Start date" label-for="settings-comment-start">
                  <b-form-input
                    id="settings-comment-start"
                    v-model="form.comment_period_starts_at"
                    type="date"
                  />
                </b-form-group>
              </b-col>
              <b-col>
                <b-form-group label="End date" label-for="settings-comment-end">
                  <b-form-input
                    id="settings-comment-end"
                    v-model="form.comment_period_ends_at"
                    type="date"
                  />
                </b-form-group>
              </b-col>
            </b-form-row>
            <b-alert show variant="info" class="mb-0 small">
              <ul class="mb-0 pl-3">
                <li>
                  <strong>Draft</strong>: component is being authored — no public comments are
                  accepted.
                </li>
                <li>
                  <strong>Open for comment</strong>: viewers can post comments and authors/admins
                  triage them.
                </li>
                <li>
                  <strong>Adjudication</strong>: window is closed — no new public comments, but
                  triage continues.
                </li>
                <li>
                  <strong>Final</strong>: disposition published — the component is frozen for
                  writes.
                </li>
              </ul>
            </b-alert>
          </b-card-body>
        </b-card>

        <!-- ───── Identity ────────────────────────────────────────── -->
        <b-card no-body class="mb-3">
          <b-card-header class="bg-light">
            <h2 class="h5 mb-0">Identity</h2>
            <small class="text-muted">Component name, version, and STIG ID prefix.</small>
          </b-card-header>
          <b-card-body>
            <b-form-group label="Name" label-for="settings-name">
              <b-form-input
                id="settings-name"
                v-model="form.name"
                placeholder="Component Name"
                required
                autocomplete="off"
              />
            </b-form-group>
            <b-form-row>
              <b-col>
                <b-form-group label="Version" label-for="settings-version">
                  <b-form-input id="settings-version" v-model="form.version" autocomplete="off" />
                </b-form-group>
              </b-col>
              <b-col>
                <b-form-group label="Release" label-for="settings-release">
                  <b-form-input id="settings-release" v-model="form.release" autocomplete="off" />
                </b-form-group>
              </b-col>
            </b-form-row>
            <b-form-group
              label="STIG ID Prefix"
              label-for="settings-prefix"
              description="Each rule's STIG ID is generated from this prefix."
            >
              <b-form-input
                id="settings-prefix"
                v-model="form.prefix"
                placeholder="Example... ABCD-EF, ABCD-00"
                required
                autocomplete="off"
              />
            </b-form-group>
            <b-form-group label="Title" label-for="settings-title">
              <b-form-input
                id="settings-title"
                v-model="form.title"
                placeholder="Component Title"
                required
                autocomplete="off"
              />
            </b-form-group>
            <b-form-group label="Description" label-for="settings-description">
              <b-form-textarea id="settings-description" v-model="form.description" rows="3" />
            </b-form-group>
          </b-card-body>
        </b-card>

        <!-- ───── Point of Contact ───────────────────────────────── -->
        <b-card no-body class="mb-3">
          <b-card-header class="bg-light">
            <h2 class="h5 mb-0">Point of Contact</h2>
            <small class="text-muted"
              >Who DISA stakeholders should contact about this component.</small
            >
          </b-card-header>
          <b-card-body>
            <b-form-group label="Search project members">
              <vue-multiselect
                :key="`pocKey-${component.id}`"
                v-model="selectedPoc"
                :options="potentialPocs"
                label="name"
                track-by="id"
                :searchable="true"
                :internal-search="false"
                :loading="isPocSearching"
                :allow-empty="true"
                placeholder="Search for eligible PoC..."
                @search-change="onPocSearch"
                @input="setPoc($event)"
              >
                <template #option="{ option }">{{ option.name }} ({{ option.email }})</template>
                <template #noResult>No users found</template>
              </vue-multiselect>
            </b-form-group>
            <b-form-row>
              <b-col>
                <b-form-group label="PoC Name" label-for="settings-admin-name">
                  <b-form-input
                    id="settings-admin-name"
                    v-model="form.admin_name"
                    autocomplete="off"
                  />
                </b-form-group>
              </b-col>
              <b-col>
                <b-form-group label="PoC Email" label-for="settings-admin-email">
                  <b-form-input
                    id="settings-admin-email"
                    v-model="form.admin_email"
                    type="email"
                    autocomplete="off"
                  />
                </b-form-group>
              </b-col>
            </b-form-row>
          </b-card-body>
        </b-card>

        <div class="d-flex justify-content-end mb-4">
          <b-button :href="`/components/${component.id}`" variant="outline-secondary" class="mr-2">
            Cancel
          </b-button>
          <b-button type="submit" variant="primary" :disabled="saving">
            <b-icon icon="check2" /> {{ saving ? "Saving..." : "Save Settings" }}
          </b-button>
        </div>
      </b-form>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import debounce from "lodash/debounce";
import VueMultiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { COMMENT_PHASE_LABELS } from "../../constants/triageVocabulary";

const PAYLOAD_KEYS = [
  "name",
  "version",
  "release",
  "title",
  "description",
  "prefix",
  "admin_name",
  "admin_email",
  "comment_phase",
  "comment_period_starts_at",
  "comment_period_ends_at",
];

// Trim ISO datetime strings to YYYY-MM-DD so the <input type="date">
// shows them correctly. Backend stores as datetime; we don't expose
// time-of-day in this UI.
function isoToDate(value) {
  if (!value) return null;
  return String(value).slice(0, 10);
}

export default {
  name: "ComponentSettingsPage",
  components: { VueMultiselect },
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    initialComponentState: { type: Object, required: true },
    project: { type: Object, required: true },
    effectivePermissions: { type: String, default: null },
    currentUserId: { type: Number, required: true },
  },
  data() {
    return {
      component: this.initialComponentState,
      form: this.buildForm(this.initialComponentState),
      potentialPocs: [],
      isPocSearching: false,
      selectedPoc: null,
      saving: false,
    };
  },
  computed: {
    breadcrumbs() {
      return [
        { text: "Projects", href: "/projects" },
        { text: this.project.name, href: `/projects/${this.project.id}` },
        { text: this.component.name, href: `/components/${this.component.id}` },
        { text: "Settings", active: true },
      ];
    },
    phaseOptions() {
      return Object.entries(COMMENT_PHASE_LABELS).map(([value, text]) => ({ value, text }));
    },
  },
  methods: {
    buildForm(component) {
      return {
        name: component.name,
        version: component.version,
        release: component.release,
        title: component.title,
        description: component.description,
        prefix: component.prefix,
        admin_name: component.admin_name,
        admin_email: component.admin_email,
        comment_phase: component.comment_phase || "draft",
        comment_period_starts_at: isoToDate(component.comment_period_starts_at),
        comment_period_ends_at: isoToDate(component.comment_period_ends_at),
      };
    },
    onPocSearch: debounce(async function (query) {
      if (!query || query.length < 2) {
        this.potentialPocs = [];
        return;
      }
      this.isPocSearching = true;
      try {
        const { data } = await axios.get("/api/users/search", {
          params: {
            q: query,
            membership_type: "Component",
            membership_id: this.component.id,
            scope: "members",
          },
        });
        this.potentialPocs = data.users;
      } catch {
        this.potentialPocs = [];
      } finally {
        this.isPocSearching = false;
      }
    }, 300),
    setPoc(user) {
      if (user) {
        this.form.admin_email = user.email;
        this.form.admin_name = user.name;
      }
    },
    save() {
      this.saving = true;
      const payload = { component: {} };
      PAYLOAD_KEYS.forEach((key) => {
        payload.component[key] = this.form[key];
      });
      axios
        .put(`/components/${this.component.id}`, payload)
        .then((response) => {
          this.alertOrNotifyResponse(response);
        })
        .catch((error) => {
          this.alertOrNotifyResponse(error);
        })
        .then(() => {
          this.saving = false;
        });
    },
  },
};
</script>
