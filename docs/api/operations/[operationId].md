---
aside: false
outline: false
title: "{{ $params.pageTitle }}"
---

<script setup>
import { useRoute } from 'vitepress'
import { OAOperation } from 'vitepress-openapi/client'

const route = useRoute()
const operationId = route.data?.params?.operationId
</script>

<OAOperation :operationId="operationId" />
