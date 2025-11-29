<script>
export default {
  name: 'NavbarItem',
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
}
</script>

<template>
  <div>
    <b-nav-item :to="link" class="mx-3">
      <i :class="`bi bi-${icon}`" aria-hidden="true" />
      <span class="d-sm-inline-block d-lg-block ms-1">{{ name }}</span>
    </b-nav-item>
  </div>
</template>
