# 前端开发规范

本页定义 VibeBase 前端（`vibe-base-web/`）的编码规范：技术栈、组件写法、状态管理、API 调用模式，以及「新增一个页面」的完整步骤。技术栈基线见 [技术架构](../introduction/architecture#用户端-vibebase-web)。

## 技术栈基线

| 维度 | 选型 | 说明 |
| --- | --- | --- |
| 框架 | Vue 3.5 + TypeScript 5.8 | 一律用 `<script setup lang="ts">` |
| 构建 | Vite 6 | 开发热重载 |
| 样式 | Tailwind CSS 4 | utility-first，少写自定义 CSS |
| UI 组件 | shadcn-vue（基于 Reka UI） | 位于 `components/ui/` |
| 状态 | Pinia 3 + pinia-plugin-persistedstate | 持久化到 localStorage |
| 路由 | Vue Router 4（hash 模式） | `router/index.ts` 集中配置 |
| HTTP | axios | 封装在 `utils/httpUtil.ts` |
| SSE | @microsoft/fetch-event-source | 仅对话用，见 `components/chat/Chat.vue` |
| Markdown | marked + highlight.js | AI 回复渲染 |
| 图标 | lucide-vue-next + @iconify/vue | 按需引入 |

## 组件写法

所有组件使用 `<script setup>` + Composition API + TypeScript，三段式顺序：`script setup` → `template` → `style`（如需）。

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { useUserStore } from '@/stores/userStore'

const props = defineProps<{
  userId: string
  editable?: boolean
}>()

const emit = defineEmits<{
  (e: 'update', value: string): void
}>()

const userStore = useUserStore()
const name = computed(() => userStore.user?.username ?? '')
const loading = ref(false)

onMounted(async () => {
  loading.value = true
  await userStore.fetchUser(props.userId)
  loading.value = false
})
</script>

<template>
  <div class="flex items-center gap-3">
    <Button :disabled="loading" @click="emit('update', name)">
      保存
    </Button>
  </div>
</template>
```

::: tip 强制要求
- 用 `defineProps<...>()` / `defineEmits<...>()` 的泛型签名，不要用运行时声明
- 用 `ref` / `computed`，不要用 Options API 的 `data` / `computed` 选项
- 模板里用 Tailwind 类名布局，复杂逻辑用 `computed` 抽离
:::

## 样式：Tailwind 优先

VibeBase 是 **utility-first**，绝大多数样式用 Tailwind 类名直接写在模板里：

```vue
<!-- 推荐：直接用 Tailwind 类名 -->
<div class="flex items-center justify-between p-4 rounded-lg bg-white shadow-sm">
  <span class="text-sm font-medium text-gray-900">{{ title }}</span>
</div>
```

::: warning 何时写自定义 CSS
只有以下情况才写 `<style scoped>`：动态主题色、第三方库样式覆写、Tailwind 难以表达的复杂动画。常规间距/颜色/布局一律用 Tailwind。
:::

## shadcn-vue 组件

基础 UI 组件位于 `components/ui/`（Button、Input、Dialog、Select、Table、Toast 等），基于 Reka UI。用法：

```vue
<script setup lang="ts">
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
</script>

<template>
  <Dialog>
    <DialogContent>
      <DialogHeader>
        <DialogTitle>编辑资料</DialogTitle>
      </DialogHeader>
      <Input v-model="name" placeholder="请输入昵称" />
      <Button>保存</Button>
    </DialogContent>
  </Dialog>
</template>
```

::: info 业务组件 vs 基础组件
- `components/ui/` — 无业务语义的基础组件（shadcn-vue 体系）
- `components/{chat,console,login,sidebar,...}/` — 带业务语义的组合组件
- `views/` — 页面级组件，对应一条路由
:::

## Pinia Store 模式

Store 位于 `stores/`，用 setup 风格定义（共 19 个 store）。结合 `pinia-plugin-persistedstate` 自动持久化到 localStorage：

```ts
// stores/authStore.ts（真实示例简化版）
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { loginAPI } from '@/apis/user/userApi'
import { appStorage } from '@/utils/storage'

export const useAuthStore = defineStore(
  'authStore',                              // 唯一 id
  () => {                                   // setup 风格
    const user = ref<LoginUser | null>(null)
    const isLoggedIn = computed(() => !!user.value)

    const login = async (userName: string, password: string) => {
      const resp = await loginAPI({ user_name: userName, user_password: password })
      if (resp.status_code === 200) {
        const token = resp.data?.access_token || resp.data || ''
        user.value = { username: userName, token }
        appStorage.setAuthToken(token)     // 供 axios 拦截器读取
        return user.value
      }
      return null
    }

    return { user, isLoggedIn, login }
  },
  {
    persist: true,                          // 自动持久化到 localStorage（pinia/authStore）
  },
)
```

### 读取响应的统一约定

所有 API 返回 `ApiResponse`（对应后端 `UnifiedResponseModel`），结构为 `{ status_code, status_message, data }`。判断成功用 `status_code === 200`：

```ts
const resp: ApiData = await someAPI(params)
if (resp.status_code === 200) {
  // 使用 resp.data
} else {
  toast.error(resp.status_message || '操作失败')
}
```

::: warning 不要用 try/catch 判业务成败
`status_code !== 200` 是**业务失败**（如积分不足 402），由 axios 拦截器正常 resolve；只有网络错误才走 catch。业务判断一律看 `status_code`。
:::

## API 模块模式

API 调用按模块组织在 `apis/{module}/{module}Api.ts`，每个函数返回一个 axios Promise。约定：

- 目录名 = 模块名（`apis/recharge/`）
- 文件名 = `{module}Api.ts`（`rechargeApi.ts`）
- 函数名 = `{verb}{Resource}API`（`listPackagesAPI`、`createOrderAPI`），全大写 `API` 结尾
- URL 集中定义为 `enum XxxUrl`，与后端路径一一对应

```ts
// apis/user/userApi.ts（真实示例简化版）
import { httpInstance } from '@/utils/httpUtil'
import type { ApiData, LoginParam } from '@/types/user/userModel'

enum UserUrl {
  REGISTER = '/api/v1/user/register',
  LOGIN    = '/api/v1/user/login',
  LOGOUT   = '/api/v1/user/logout',
  QUERY_USER = '/api/v1/user/info',
  UPDATE_USER = '/api/v1/user/update',
}

export function loginAPI({ user_name, user_password }: LoginParam) {
  return httpInstance.post<any, ApiData>(UserUrl.LOGIN, { user_name, user_password })
}

export function queryUserAPI() {
  return httpInstance.get<any, ApiData>(UserUrl.QUERY_USER)
}
```

### axios 封装

`utils/httpUtil.ts` 导出 `httpInstance`，自动：
- 在请求头注入 `Authorization: Bearer {token}`（从 `appStorage` 读取）
- 401 时清理登录态并跳转登录页
- 解析响应为 `ApiResponse` 类型

## 如何新增一个页面

以「新增一个工单详情页 `/app/ticket/:id`」为例：

::: details 完整步骤

**第一步：新增 API 函数**

```ts
// apis/ticket/ticketApi.ts
import { httpInstance } from '@/utils/httpUtil'
import type { ApiData } from '@/types'

export function queryTicketDetailAPI(id: string) {
  return httpInstance.get<any, ApiData>(`/api/v1/ticket/${id}`)
}
```

**第二步：新增/扩展 Store（如需共享状态）**

```ts
// stores/ticketStore.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { queryTicketDetailAPI } from '@/apis/ticket/ticketApi'

export const useTicketStore = defineStore('ticketStore', () => {
  const detail = ref<Ticket | null>(null)
  const fetchDetail = async (id: string) => {
    const resp = await queryTicketDetailAPI(id)
    if (resp.status_code === 200) detail.value = resp.data
  }
  return { detail, fetchDetail }
}, { persist: true })
```

**第三步：新增 View 页面**

```vue
<!-- views/user/TicketDetailView.vue -->
<script setup lang="ts">
import { useRoute } from 'vue-router'
import { onMounted } from 'vue'
import { useTicketStore } from '@/stores/ticketStore'

const route = useRoute()
const ticketStore = useTicketStore()

onMounted(() => ticketStore.fetchDetail(route.params.id as string))
</script>

<template>
  <div class="p-6">
    <h1 class="text-xl font-semibold">{{ ticketStore.detail?.title }}</h1>
    <p class="mt-2 text-gray-600">{{ ticketStore.detail?.content }}</p>
  </div>
</template>
```

**第四步：注册路由**

在 `router/index.ts` 的对应 children 数组中新增：

```ts
{
  path: 'ticket/:id',
  name: 'ticketDetail',
  component: () => import('../views/user/TicketDetailView.vue'),
  meta: { requiresAuth: true, title: '工单详情', group: '工单' },
}
```

**第五步：验证**

启动前端 `pnpm dev`，访问 `/#/app/ticket/TK20260715001` 查看效果。

:::

## 命名规范

| 对象 | 约定 | 示例 |
| --- | --- | --- |
| 组件文件 | PascalCase | `ChatMessage.vue`、`DialogHeader.vue` |
| 组件使用 | PascalCase | `<ChatMessage />` |
| 变量 / 函数 | camelCase | `const isLoading = ref(false)`、`function fetchUser()` |
| API 函数 | camelCase + `API` 后缀 | `listPackagesAPI`、`createOrderAPI` |
| Store id | camelCase + `Store` 后缀 | `'authStore'`、`'pointsStore'` |
| Store 文件 | camelCase + `Store` | `authStore.ts`、`pointsStore.ts` |
| 类型文件 | camelCase + `Model` | `chatModel.ts`、`userModel.ts` |
| 部分 config / 工具文件 | kebab-case | `constants.ts`、`markdown-parser.ts` |
| 路由 name | camelCase | `consoleDashboard`、`ticketDetail` |

## 路由与鉴权

路由配置在 `router/index.ts`，通过 `meta.requiresAuth` 控制是否需要登录：

```ts
{
  path: 'console/dashboard',
  name: 'consoleDashboard',
  component: () => import('../views/console/DashboardIndex.vue'),
  meta: { requiresAuth: true, title: '控制台概览', icon: 'LayoutDashboard', group: '首页' },
}
```

- `requiresAuth: true` — 未登录访问会跳转登录页
- `title` — 浏览器标签页与侧边栏显示
- `icon` — 侧边栏图标（lucide 图标名）
- `group` — 侧边栏分组（`首页` / `财务` / `开发` / `分析` / `系统`）

## 对话流式：fetchEventSource

唯一不走 axios 的接口是对话 `/api/v1/chat`，用 `@microsoft/fetch-event-source` 处理 SSE：

```ts
import { fetchEventSource } from '@microsoft/fetch-event-source'

await fetchEventSource(streamChatUrl, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,     // 手动注入 token
  },
  body: JSON.stringify({ dialog_id, user_input, ... }),
  onmessage(event) {
    if (event.data === '[DONE]') return   // 流结束
    const data = JSON.parse(event.data)
    switch (data.type) {
      case 'response_chunk': /* 追加字符 */ break
      case 'llm_end':        /* 结束处理 */ break
      case 'points_deducted':/* 积分扣减 */ break
      // ...
    }
  },
  onerror(err) { /* 错误处理 */ },
})
```

完整事件列表见 [聊天与流式](./chat-streaming)。

## 接下来

- [项目结构](./structure) — 前端目录的完整职责
- [后端开发规范](./backend-conventions) — 后端如何配合
- [聊天与流式](./chat-streaming) — SSE 前端处理细节
- [功能指南 · 控制台概览](../guide/dashboard) — 页面功能说明
