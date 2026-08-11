---
aside: false
outline: false
title: "{{ $params.pageTitle }}"
---

<script setup>
import { useRoute } from 'vitepress'

const route = useRoute()
const tag = route.data?.params?.tag
</script>

<OASpec :tags="[tag]" hide-info hide-servers hide-paths-summary />
