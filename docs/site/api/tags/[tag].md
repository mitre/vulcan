---
aside: false
outline: false
---

<script setup>
import { useRoute } from 'vitepress'

const route = useRoute()
const tag = route.data?.params?.tag
</script>

<OASpec :tags="[tag]" hide-info hide-servers hide-paths-summary />
