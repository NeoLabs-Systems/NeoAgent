import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'NeoAgent',
  description: 'Self-hosted proactive AI agent docs',
  base: '/NeoAgent/',
  cleanUrls: true,
  themeConfig: {
    nav: [
      { text: 'Guide', link: '/getting-started' },
      { text: 'Capabilities', link: '/capabilities' },
      { text: 'Configuration', link: '/configuration' },
      { text: 'Why NeoAgent', link: '/why-neoagent' },
      { text: 'GitHub', link: 'https://github.com/NeoLabs-Systems/NeoAgent' },
    ],
    sidebar: [
      {
        text: 'Start',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'Capabilities', link: '/capabilities' },
          { text: 'Why NeoAgent', link: '/why-neoagent' },
        ],
      },
      {
        text: 'Operate',
        items: [
          { text: 'Configuration', link: '/configuration' },
          { text: 'Automation', link: '/automation' },
          { text: 'Integrations', link: '/integrations' },
          { text: 'Skills', link: '/skills' },
          { text: 'Operations', link: '/operations' },
        ],
      },
    ],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/NeoLabs-Systems/NeoAgent' },
    ],
    search: {
      provider: 'local',
    },
    editLink: {
      pattern: 'https://github.com/NeoLabs-Systems/NeoAgent/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright NeoLabs Systems',
    },
  },
});
