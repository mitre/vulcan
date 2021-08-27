<template>
  <div>
    <b-nav-item :href="link" class="mx-3">
      <i class="mdi" :class="icon" aria-hidden="true" />
      <div class="d-sm-inline-block d-lg-block">{{ name }}</div>
    </b-nav-item>
  </div>
</template>

<script>
export default {
  name: "NavbarItem",
  props: {
    icon: {
      type: String,
      required: false,
    },
    link: {
      type: String,
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
  },
};
</script>
