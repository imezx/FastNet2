import { defineConfig } from 'vitepress'

function nav() {
  return [
    {
      text: 'API Reference',
      items: [
        { text: '1.0', link: '/api/1.0/server' }
      ]
    }
  ]
}

function side() {
  return {
    '/api/1.0': [
      {
        text: 'API Reference',
        items: [
          { text: 'Server', link: '/api/1.0/server' },
          { text: 'Client', link: '/api/1.0/client' },
        ]
      }
    ],
    '/guide/': [
      {
        text: 'Guide',
        items: [
          { text: 'Overview', link: '/guide/' },
          { text: 'Installation', link: '/guide/installation' },
          { text: 'Getting Started', link: '/guide/getting-started' },
          { text: 'Example', link: '/guide/example' },
        ]
      },
    ]
  }
}

export default defineConfig({
  title: "FastNet2",
  description: "FastNet2 - a Incredible and Powerful networking library for ROBLOX Games",
  lang: 'en-US',
  base: "/FastNet2",
  cleanUrls: true,
  assetsDir: '/assets',
  themeConfig: {
    nav: nav(),
    sidebar: side(),
    socialLinks: [
      { icon: 'github', link: 'https://github.com/imezx/FastNet2' }
    ]
  }
})