<template>
  <div>
    <b-nav-item :href="link" class="mx-3">
      <i :class="'bi bi-' + icon" aria-hidden="true"></i>
      <span class="d-sm-inline-block d-lg-block ms-1">{{ name }}</span>
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
