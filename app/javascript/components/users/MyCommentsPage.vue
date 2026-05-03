<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <div class="px-3">
      <h1 class="h3 mb-3">
        <b-icon icon="chat-left-text" class="mr-2" />
        {{ heading }}
      </h1>
      <UserComments :user-id="userId" />
    </div>
  </div>
</template>

<script>
import UserComments from "./UserComments.vue";

export default {
  name: "MyCommentsPage",
  components: { UserComments },
  props: {
    userId: { type: Number, required: true },
    userName: { type: String, default: null },
    isSelf: { type: Boolean, default: true },
  },
  computed: {
    heading() {
      if (this.isSelf) return "My Comments";
      return this.userName ? `Comments by ${this.userName}` : "Comments";
    },
    breadcrumbs() {
      const trail = [{ text: "Profile", href: "/users/edit" }];
      trail.push({ text: this.heading, active: true });
      return trail;
    },
  },
};
</script>
