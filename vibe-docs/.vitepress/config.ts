import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'zh-CN',
  title: 'VibeBase',
  description: '能收钱、能运营的 AI 产品平台 — 一次买断 · 源码交付 · 可私有化部署',

  // 部署子路径：生产部署在 vibebase.vibeadmin.cn/docs/ 下，构建时设 VITEPRESS_BASE=/docs/；
  // 本地开发默认根路径（npm run dev 仍可 http://localhost:5173/ 访问）。
  base: (process.env.VITEPRESS_BASE as string | undefined) || '/',

  // 本地开发地址（localhost）在构建期不可达，但运行时有效，故忽略
  ignoreDeadLinks: [
    /^https?:\/\/localhost/,
    /^https?:\/\/127\.0\.0\.1/,
  ],

  // 站点级 Head：中文字体回退、SEO
  head: [
    ['meta', { name: 'theme-color', content: '#3b82f6' }],
    ['meta', { property: 'og:title', content: 'VibeBase — 能收钱、能运营的 AI 产品平台' }],
    ['meta', { property: 'og:description', content: '一次买断 · 源码交付 · 可私有化部署。四端齐全、后端完整、开箱即用的 AI 商业化解决方案。' }],
    ['meta', { property: 'og:image', content: '/og.svg' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:image', content: '/og.svg' }],
  ],

  // 主题配置
  themeConfig: {
    logo: '/logo.svg',

    // 顶部导航
    nav: nav(),

    // 左侧目录（按分组）
    sidebar: {
      '/introduction/': sidebarIntroduction(),
      '/quickstart/': sidebarQuickstart(),
      '/configuration/': sidebarConfiguration(),
      '/development/': sidebarDevelopment(),
      '/api/': sidebarApi(),
      '/guide/': sidebarGuide(),
      '/deployment/': sidebarDeployment(),
      '/multi-end/': sidebarMultiEnd(),
      '/faq/': sidebarFaq(),
    },

    // 全文搜索
    search: {
      provider: 'local',
      options: {
        translations: {
          button: {
            buttonText: '搜索文档',
            buttonAriaLabel: '搜索文档',
          },
          modal: {
            noResultsText: '无法找到相关结果',
            resetButtonTitle: '清除查询条件',
            footer: {
              selectText: '选择',
              navigateText: '切换',
            },
          },
        },
      },
    },

    // 社交链接
    socialLinks: [
      { icon: 'github', link: 'https://github.com/vibase' },
    ],

    // 大纲（右侧"本页目录"）
    outline: {
      level: [2, 3],
      label: '本页目录',
    },

    // 文档页元信息
    docFooter: {
      prev: '上一页',
      next: '下一页',
    },

    lastUpdated: {
      text: '最后更新于',
    },

    returnToTopLabel: '回到顶部',
    sidebarMenuLabel: '菜单',
    darkModeSwitchLabel: '主题',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',
  },

  lastUpdated: true,
})

/* ===================== 顶部导航 ===================== */
function nav() {
  return [
    { text: '介绍', link: '/introduction/whats-vibebase', activeMatch: '/introduction/' },
    { text: '快速开始', link: '/quickstart/requirements', activeMatch: '/quickstart/' },
    { text: '配置', link: '/configuration/backend', activeMatch: '/configuration/' },
    {
      text: '开发',
      items: [
        { text: '开发指南', link: '/development/structure', activeMatch: '/development/' },
        { text: 'API 参考', link: '/api/overview', activeMatch: '/api/' },
        { text: '功能指南', link: '/guide/dashboard', activeMatch: '/guide/' },
      ],
    },
    { text: '部署', link: '/deployment/docker', activeMatch: '/deployment/' },
    { text: '多端', link: '/multi-end/overview', activeMatch: '/multi-end/' },
    { text: 'FAQ', link: '/faq/faq', activeMatch: '/faq/' },
  ]
}

/* ===================== 侧边栏分组 ===================== */
function sidebarIntroduction() {
  return [
    {
      text: '介绍',
      collapsed: false,
      items: [
        { text: '什么是 VibeBase', link: '/introduction/whats-vibebase' },
        { text: '核心特性', link: '/introduction/features' },
        { text: '产品矩阵', link: '/introduction/product-matrix' },
        { text: '技术架构', link: '/introduction/architecture' },
        { text: '适用场景', link: '/introduction/use-cases' },
      ],
    },
  ]
}

function sidebarQuickstart() {
  return [
    {
      text: '快速开始',
      collapsed: false,
      items: [
        { text: '环境要求', link: '/quickstart/requirements' },
        { text: '获取源码与安装', link: '/quickstart/installation' },
        { text: '本地启动', link: '/quickstart/local-startup' },
        { text: '首次配置', link: '/quickstart/first-config' },
      ],
    },
  ]
}

function sidebarConfiguration() {
  return [
    {
      text: '配置',
      collapsed: false,
      items: [
        { text: '后端配置', link: '/configuration/backend' },
        { text: '数据库配置', link: '/configuration/database' },
        { text: 'Redis 配置', link: '/configuration/redis' },
        { text: 'LLM 模型配置', link: '/configuration/llm' },
        { text: '对象存储配置', link: '/configuration/storage' },
        { text: '支付配置', link: '/configuration/payment' },
        { text: 'CORS 与跨端', link: '/configuration/cors' },
        { text: 'JWT 与认证密钥', link: '/configuration/jwt' },
        { text: '前端配置', link: '/configuration/frontend' },
      ],
    },
  ]
}

function sidebarDevelopment() {
  return [
    {
      text: '开发指南',
      collapsed: false,
      items: [
        { text: '项目结构', link: '/development/structure' },
        { text: '后端开发规范', link: '/development/backend-conventions' },
        { text: '前端开发规范', link: '/development/frontend-conventions' },
        { text: '认证机制', link: '/development/authentication' },
        { text: '聊天与流式', link: '/development/chat-streaming' },
        { text: '积分系统', link: '/development/points-system' },
        { text: '充值与支付', link: '/development/recharge-payment' },
        { text: '数据模型', link: '/development/data-models' },
      ],
    },
  ]
}

function sidebarApi() {
  return [
    {
      text: 'API 参考',
      collapsed: false,
      items: [
        { text: 'API 概览', link: '/api/overview' },
        { text: '用户与认证', link: '/api/user' },
        { text: '对话', link: '/api/chat' },
        { text: '积分', link: '/api/points' },
        { text: '充值', link: '/api/recharge' },
        { text: 'API Key', link: '/api/apikey' },
        { text: 'AI 能力', link: '/api/ability' },
        { text: '用量分析', link: '/api/analytics' },
        { text: '个人资料', link: '/api/profile' },
        { text: '角色权限', link: '/api/role' },
        { text: '公告', link: '/api/announcement' },
        { text: '反馈', link: '/api/feedback' },
        { text: '工单', link: '/api/ticket' },
        { text: '子账号', link: '/api/accounts' },
        { text: '消费记录', link: '/api/consume' },
        { text: '控制台', link: '/api/console' },
        { text: '图像理解', link: '/api/image' },
        { text: '错误码', link: '/api/error-codes' },
      ],
    },
  ]
}

function sidebarGuide() {
  return [
    {
      text: '功能指南',
      collapsed: false,
      items: [
        { text: '控制台概览', link: '/guide/dashboard' },
        { text: 'AI 对话', link: '/guide/chat' },
        { text: '对话管理', link: '/guide/conversation' },
        { text: '积分中心', link: '/guide/points' },
        { text: '充值套餐', link: '/guide/recharge' },
        { text: 'API Key 管理', link: '/guide/apikey' },
        { text: '用量分析', link: '/guide/analytics' },
        { text: '安全中心', link: '/guide/security' },
        { text: '工单系统', link: '/guide/ticket' },
        { text: '角色权限', link: '/guide/role' },
        { text: '子账号管理', link: '/guide/account' },
        { text: '公告中心', link: '/guide/announcement' },
        { text: '个人设置', link: '/guide/settings' },
        { text: '邀请系统', link: '/guide/invitation' },
      ],
    },
  ]
}

function sidebarDeployment() {
  return [
    {
      text: '部署',
      collapsed: false,
      items: [
        { text: 'Docker 部署', link: '/deployment/docker' },
        { text: '生产环境部署', link: '/deployment/production' },
        { text: 'Nginx 反向代理', link: '/deployment/nginx' },
        { text: '域名与 HTTPS', link: '/deployment/domain-https' },
        { text: 'ICP 备案', link: '/deployment/icp-filing' },
      ],
    },
  ]
}

function sidebarMultiEnd() {
  return [
    {
      text: '多端协作',
      collapsed: false,
      items: [
        { text: '多端概览', link: '/multi-end/overview' },
        { text: 'VibeBase 用户 Web', link: '/multi-end/vibebase-web' },
        { text: 'VibeAdmin 运营后台', link: '/multi-end/vibeadmin' },
        { text: 'VibeApp Flutter', link: '/multi-end/vibeapp' },
        { text: 'Vibe-Mp-H5 小程序', link: '/multi-end/vibe-mp-h5' },
      ],
    },
  ]
}

function sidebarFaq() {
  return [
    {
      text: '常见问题',
      collapsed: false,
      items: [
        { text: 'FAQ', link: '/faq/faq' },
      ],
    },
  ]
}
