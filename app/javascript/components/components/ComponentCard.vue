<template>
  <b-overlay :show="showDeleteConfirmation" class="m-3" :opacity="0.95">
    <!-- Overlay content -->
    <template #overlay>
      <div class="text-center">
        <p>Are you sure you want to remove this component from the project?</p>
        <b-button variant="outline-secondary" @click="showDeleteConfirmation = false">
          Cancel
        </b-button>
        <b-button variant="danger" @click="$emit('deleteComponent', component.id)">Remove</b-button>
      </div>
    </template>

    <!-- Card -->
    <b-card class="shadow">
      <b-card-title>
        {{ component.name }}
        <span v-if="component.version || component.release">
          &nbsp;-
          <span v-if="component.version"> &nbsp;Version {{ component.version }} </span>
          <span v-if="component.release"> &nbsp;Release {{ component.release }} </span>
        </span>
        <i v-if="component.released" class="mdi mdi-stamper h5" aria-hidden="true" />
        <!-- Rules count info -->
        <span class="float-right h6">
          {{ component.rules_count }} {{ component.component_id ? "Overlaid" : "" }} Controls
        </span>
      </b-card-title>
      <b-card-sub-title class="mb-2">
        Based on {{ component.based_on_title }} {{ component.based_on_version }}
      </b-card-sub-title>
      <b-card-sub-title v-if="component.description" class="my-2">
        {{ component.description }}
      </b-card-sub-title>
      <p class="mt-4">
        <span v-if="component.admin_name">
          PoC: {{ component.admin_name }}
          {{ component.admin_email ? `(${component.admin_email})` : "" }}
        </span>
        <em v-else>No Component Admin</em>
      </p>
      <!-- Component actions -->
      <p>
        <!-- Open component -->
        <a :href="`/components/${component.id}`" target="_blank" class="text-body">
          <i
            v-b-tooltip.hover
            class="mdi mdi-open-in-new float-right h5 clickable"
            aria-hidden="true"
            title="Open Component"
          />
        </a>

        <!-- Remove component -->
        <i
          v-if="actionable && component.id && effectivePermissions == 'admin'"
          v-b-tooltip.hover
          class="mdi mdi-delete float-right h5 clickable mr-2"
          aria-hidden="true"
          title="Remove Component"
          @click="showDeleteConfirmation = !showDeleteConfirmation"
        />

        <!-- Duplicate component -->
        <span v-if="actionable && effectivePermissions == 'admin'" class="float-right mr-2">
          <NewComponentModal
            :component_to_duplicate="component.id"
            :project_id="component.project_id"
            :predetermined_prefix="component.prefix"
            :predetermined_security_requirements_guide_id="component.security_requirements_guide_id"
            @projectUpdated="$emit('projectUpdated')"
          >
            <template #opener>
              <i
                v-if="component.id"
                v-b-tooltip.hover
                class="mdi mdi-content-copy h5 clickable"
                aria-hidden="true"
                title="Duplicate component and create a new version"
              />
            </template>
          </NewComponentModal>
        </span>

        <!-- Release component -->
        <span
          v-if="actionable && component.id && effectivePermissions == 'admin'"
          class="float-right mr-2"
        >
          <span v-b-tooltip.hover :title="releaseComponentTooltip">
            <i
              :class="releaseComponentClasses"
              aria-hidden="true"
              @click="confirmComponentRelease"
            />
          </span>
        </span>

        <!-- Export CSV component -->
        <i
          v-b-tooltip.hover
          class="mdi mdi-download h5 float-right mr-2 clickable"
          aria-hidden="true"
          title="Export Component as CSV"
          @click="downloadExport('csv')"
        />

        <!-- Export XCCDF component -->
        <i
          v-b-tooltip.hover
          class="xccdf-icon h5 float-right mr-2 clickable"
          aria-hidden="true"
          title="Export Component as XCCDF"
          @click="downloadExport('xccdf')"
        />

        <!-- Download InSpec Profile -->
        <i
          v-b-tooltip.hover
          class="inspec-icon h5 float-right mr-2 clickable"
          aria-hidden="true"
          title="Download InSpec Profile"
          @click="downloadExport('inspec')"
        />

        <!-- Lock all controls in component -->
        <span
          v-if="actionable && role_gte_to(effectivePermissions, 'reviewer')"
          class="float-right mr-2"
        >
          <LockControlsModal :component_id="component.id" @projectUpdated="$emit('projectUpdated')">
            <template #opener>
              <i
                v-if="component.id"
                v-b-tooltip.hover
                class="mdi mdi-lock h5 clickable"
                aria-hidden="true"
                title="Lock component controls"
              />
            </template>
          </LockControlsModal>
        </span>
      </p>
    </b-card>
  </b-overlay>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import ConfirmComponentReleaseMixin from "../../mixins/ConfirmComponentReleaseMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import LockControlsModal from "../components/LockControlsModal.vue";
import NewComponentModal from "../components/NewComponentModal.vue";

export default {
  name: "ComponentCard",
  components: {
    LockControlsModal,
    NewComponentModal,
  },
  mixins: [AlertMixinVue, FormMixinVue, ConfirmComponentReleaseMixin, RoleComparisonMixin],
  props: {
    // Indicate if the card is for "read-only" or can take actions against it
    actionable: {
      type: Boolean,
      default: true,
    },
    effectivePermissions: {
      type: String,
      required: false,
    },
    component: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      showDeleteConfirmation: false,
    };
  },
  computed: {
    releaseComponentClasses: function () {
      let classes = ["mdi", "mdi-stamper", "h5", "clickable"];
      if (!this.component.releasable) {
        classes.push("text-muted");
      }
      return classes;
    },
    releaseComponentTooltip: function () {
      if (this.component.released) {
        return "Component has already been released";
      }

      if (this.component.releasable) {
        return "Release Component";
      }

      return "All rules must be locked to release a component";
    },
  },
  methods: {
    downloadExport: function (type) {
      axios
        .get(`/components/${this.component.id}/export/${type}`)
        .then((_res) => {
          // Once it is validated that there is content to download, prompt
          // the user to save the file
          window.open(`/components/${this.component.id}/export/${type}`);
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped>
.inspec-icon {
  background: url("data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPHN2ZyB3aWR0aD0iMzJweCIgaGVpZ2h0PSIzMnB4IiB2aWV3Qm94PSIwIDAgMzIgMzIiIHZlcnNpb249IjEuMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8dGl0bGU+QXJ0Ym9hcmQ8L3RpdGxlPgogIDxkZXNjPkNyZWF0ZWQgd2l0aCBTa2V0Y2guPC9kZXNjPgogIDxnIGlkPSJBcnRib2FyZCIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjEiIGZpbGw9Im5vbmUiIGZpbGwtcnVsZT0iZXZlbm9kZCI+CiAgICA8ZyBpZD0iR3JvdXAtMyIgZmlsbD0iIzQ0OUJCQiI+CiAgICAgIDxwYXRoIGQ9Ik02LjQ5MjkyNzkzLDI4Ljg3MDQ0OTUgTDExLjg5MTQzODcsMjQuMDA5NjA4NyBDMTMuMTIzMTM2NSwyNC42NDI2ODU4IDE0LjUxOTg0MDcsMjUgMTYsMjUgQzIwLjk3MDU2MjcsMjUgMjUsMjAuOTcwNTYyNyAyNSwxNiBDMjUsMTEuMDI5NDM3MyAyMC45NzA1NjI3LDcgMTYsNyBDMTEuMDI5NDM3Myw3IDcsMTEuMDI5NDM3MyA3LDE2IEM3LDE3LjY2Njg0NzYgNy40NTMxMzIzMiwxOS4yMjc4NjA0IDguMjQyOTMyODYsMjAuNTY2NTc0NCBMMi45ODE2NDIzNywyNS4zMDM4NjE2IEMxLjEwNDcxMzgzLDIyLjY4MjI2MDIgMCwxOS40NzAxNCAwLDE2IEMwLDcuMTYzNDQ0IDcuMTYzNDQ0LDAgMTYsMCBDMjQuODM2NTU2LDAgMzIsNy4xNjM0NDQgMzIsMTYgQzMyLDI0LjgzNjU1NiAyNC44MzY1NTYsMzIgMTYsMzIgQzEyLjQzOTY2ODEsMzIgOS4xNTA5NDI1NCwzMC44MzcxMTUgNi40OTI5Mjc5MywyOC44NzA0NDk1IFoiIGlkPSJDb21iaW5lZC1TaGFwZSIgc3R5bGU9ImZpbGw6IHJnYmEoMCwgMCwgMCwgMC44KTsiLz4KICAgICAgPGNpcmNsZSBpZD0iT3ZhbCIgY3g9IjE2IiBjeT0iMTYiIHI9IjUuMjUiIHN0eWxlPSJmaWxsOiByZ2JhKDAsIDAsIDAsIDAuOCk7Ii8+CiAgICA8L2c+CiAgPC9nPgo8L3N2Zz4=");
  background-size: 100%;
  height: 1rem;
  width: 1rem;
  margin: 0.1875rem 0;
  display: block;
}

.xccdf-icon {
  background: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAOEAAADhCAMAAAAJbSJIAAAAe1BMVEX///8AAADk5ORbW1vIyMiXl5fU1NTh4eFJSUlRUVHX19f19fXBwcG3t7dFRUVVVVXw8PCkpKQhISGOjo40NDSGhoatra3s7OydnZ15eXkoKCgKCgp8fHxmZmbj4+NsbGwcHBwVFRUvLy87OzvExMQ5OTkYGBggICBgYGD3eryIAAAJUElEQVR4nO2d60LiOhSFqQIiiAqiKM4MonN7/yc8hyJkrZ2dEqW51Mn6B72kX9NkX5KmvZ6HpuvVcxVPoyufi2pR/deIdDvdRwV8iM73vwYRAfspAKvqIR5hzAaI6scCnCUCrKpxJMLLZITzZRTA25dkhNUiCuHZvrjfoygixFFUwvMYpfUmXItPEYpMSxjDLCYmjGAWUxNWP0MXmZywughcZHrCTWCzmJ6wWkyCFpkBYXUTtMgcCMOaxSwIq7uAReZBGNIsZkIYMFrMhbD6EarIbAirUGYxH8K3QGYxH8JQZjEjwmodpMicCMOYxawIg5jFvAhDmMXMCANEi7kRth8t5kbYvlnMjrC6bLnI/AjbNosZErZsFnMkbNcsZknYahI1T8I2xxYzJWzRLGZK2OLYYq6E7Y0tZkvYmlnMl7Ats5gxYUtmMWfCqpXpb1kTtmIW8yasbk8vMnPC1enRYuaELSRRcyc83SxmT3iyWcyf8NRQqgOEJ3qoHSDcnGYyIhP2PkFYnZ1UYmzCz0zY7Rbh+MsTfubVgI4R9nrDqZeurjtL6KvzQuinQphQhdBThTChCqGnCmFCFUJPFcKEKoSeKoQJVQg9VQgTqhB6ark/zd+Wrqs9/d1f2udmDy2vZoOt7venWTwO8tLjYn9p9/Xv2dUHSCeP/OZ/VzR69BwSfviT+lI/rbnXDJRvqS/zJH07Dvg99TWeqO/HAO9SX+HJOjLs/Zmxn9zUPI/o+vgJstd1E+Aw9dW1omED4f3xwzugppb4lvriWlHDY3o7T31xrWjunp1xdvzoTsgdbVzIXUeXpIV9stcb3OEGHNq3S6GbjX4913LHa/dmv2bkfkvRIhQ+0K19MrESwJPZYvdoT/bhW1n7cY9O5u1n24TSelp9rfCR8NrsYvTLs1cuaSC8ap1QzN+0Gqq4Axh12Y1BeQQqbbY2O1aBCWX54kETs+amuE0JSLUZT892x/cjKuGK91jyVvFuNW1TCLWlUJVYgOs6NGE1413WuO2Nt1FcohklcX9qTe3dJrSiaHDCauLeha+OG6m6gJWyzqSWXaHdwhOKNX0hQl44t1SOia129Km+uEyuVXhCsT90dJwUEXPu1ASrHbsoD2mvR0szRyAUfcEhE7vh51A4PGqCdWKt2atmx8ipiUAoesxDXfHClLKf1F8TWIu99DDgJjbhK++19w3p9lsztPWk11TsNVP3ohYdg1A0uPdS+OG1/DkIQ5fGbZD24tCT3iIrJTSjEIoWt6n/HDYfCVe8BFrOppuedIiBOXW5UQhFXqBeAfsX/XVuHQKd5Bl4twPa6dFAYRG0xHYcQnajJ5tKtCClYOieziBAYq/axF6XSEi9ViRC7hkH0mH+bR8BD/EPLBLtBfSk9JhQfxSJkMtZiqjuUTlgiKeFrgqjE2Nv+kRIHLEI2cl+on5Gjfsu8LRgOvAazcXfESG5R7EI2b26oKBKzU5Ayx1TDGZ2mZs/5+T+knMXjZADRTyHmijHdton78CEwQZqyQ4+XUc0QujZhdQB4xe+LHiojb24wj2QkB77eISuGQHSEdsJq/yBvCJT5ea/tQjSEhE6lvPVP/GBseOMXLzb/QEQGr4KPzYRoX6gY0gVg4YBA+/9H/PYb92ALAi1eNw1EIAB8B0Xum+IF/RPFoTaQhSuYX90grZxh90QYbWAbV9FbWCVitBe2cc5pIodxzcmnryIe7CUt4SC/KiEdsDqHClB27L1CDCK3oXwxoWoHW0KNzFUiUto2UTnp4QwaK5TF2fyIBNX1DyUucJkR+Kn1FmJ6OTVc+yg+utH2zi6uwQIdWOYMUjd07je28Vd66cS29n2t+k7dy4D5aTQBKW2Fkp0Xwvzc7t+A/5Y0C3YPZKUM8BMQExCdV10bSxCFLKQ/2yryHjmuwPIs8fmHZHQMSlOd2rQid0l6aHvmSLQ+3P+B8+JaYx4hMpAXy07j72VvQN0lhQsvacOn/Gc6M3HI9STtz1HcIGENsJvaIb70QDMWGL/FY2QLAW3SC1AtAmx81kbnkPyDQkxIxeNEBe6mTxTilhx3bDC9oSQiRmYnvPQjPGU2H3FIiRLMRXOjRxv4RrfR+wwotg3fvbBBZ0oh8QkpIMuxSQYe+GcS+2spn9dHrIaprawI0tASDmGbSvhSrQSpujBHB5ibTTUWD5Mq+Mti0PIlmLbv7/wYI38oC7ekUPHqKVBTJyEJBNIoschpBrb3WA2HrLkgbaNjDqeqxbmmCdwx6IQ8hDpzmnk7lS6p3hLjINilwy2lFYlgxA4CiEPc292f86aDsWNM/Vf68ZQ4ALj3DEIOaY4VAkfyy+iYKfy6DhRDzKL4hBM/8Qg5AMOMS/XCFsMrHUIhWSBeME0lA4Wlgj7i2tNo81JhDxlyEyh3PDBzmFNIJQrAKKrQDfsST+VU9wNfJBQxBTQQkSzwoQGBk+QkhDzqyY4+Yn6azjGi5Dmp3yUkG07+sRifVQMCHALVBQP/rNDS+VA0BmccM67UAZ45tyGhPgEcdk0RYUmIIGTFJyQLQXnLERLNBvJWGJwxY4bvehITzA06tCEYhq0eDlRVOLh2aKkC054o8w2F0c+HXSyoQl5Z2vEXpxg8/43pQZxosYcK5fn1lDSG1poYELR+Q3kdlGJeyeMap4OwOtd0RY6ZqwfEYCQLcXEekN4LmZPvg/S08NIB0B/whPWud7hSsISiipSZqKLPd7vPbUp2h8cNzHmQYmgWIQy3FFe/JKVuHNGnMOdDSKzBAOv4S1+B1UIu69C2H39y4SOscDOyb2Oy2R1/OgOqOm7Ht1cl0aq6VsC2nTm7sk5T/TLdDWNH5y1x8m6p+YPs3yF3vTIilj6jN8uSX2jEdX1zqapm/kStXi0Bre6cEzk6oDOfb/bPbzXp6fnref7psWFLC3H/a0Oj+xo2M9Lw4P/Na1/jz/58dWvv/ZlIUyoQuipQphQhdBThTChCqGnCmFCFUJPFcKEKoSeKoQJVQg9VQgTqhB6qhAmVCH0VCFMqELoqUKYUIXQU4UwoQqhpwphQhVCTxXChCqEnvqHCEfjYV4aj1omzFiF8F8nvFW+fZOZXtxfyvOS9hGqvKSu5vgBORcozUbOlfJ8lfts4efjCEfkWqA0F/WPIxyT9rG0fOT1Ie5j6sulyvLRaws1WGu6XuXXHJ9Xa6+XK/4DifmfHXwwJQUAAAAASUVORK5CYII=");
  background-size: 100%;
  height: 1rem;
  width: 1rem;
  margin: 0.1875rem 0;
  display: block;
}
</style>
