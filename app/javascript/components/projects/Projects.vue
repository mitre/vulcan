<template>
  <div>
    <h1>Projects</h1>

    <!-- Project search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text"><i class="mdi mdi-magnify" aria-hidden="true"></i></div>
          </div>
          <input type="text" class="form-control" id="userSearch" placeholder="Search projects by name..." v-model="search">
        </div>
      </div>
    </div>

    <!-- 
      This is currently just a list of cards as a placeholder to easily navigate to
      other project-related pages, but in the future this should be changed to a 
      paginated table like users and project members.
    -->
    <Project v-bind:key="project.id" 
             v-bind:project="project" 
             v-for="project in searchedProjects" />
  </div>
</template>

<script>
export default {
  name: 'Projects',
  props: {
    projects: {
      type: Array,
      required: true,
    }
  },
  data: function () {
    return {
      search: ""
    }
  },
  computed: {
    searchedProjects: function () {
      let downcaseSearch = this.search.toLowerCase()
      return this.projects.filter(project => project.name.toLowerCase().includes(downcaseSearch));
    }
  }
}
</script>

<style scoped>

</style>
