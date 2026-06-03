<template>
  <b-nav-item :href="link" link-classes="nav-item__link">
    <b-icon :icon="icon" aria-hidden="true" class="nav-item__icon" />
    <span class="nav-item__label">{{ name }}</span>
  </b-nav-item>
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

<style>
/* Unscoped — b-nav-item renders the link outside the component root */

/* Collapsed (below xl): icon + text inline */
.nav-item__link {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* Desktop (xl+): icon above text, centered */
@media (min-width: 1200px) {
  .nav-item__link {
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 0.125rem;
  }

  .nav-item__label {
    font-size: 0.8125rem;
  }
}
</style>
