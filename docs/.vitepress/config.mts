import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'NeoAgent',
  description: 'Self-hosted proactive AI agent docs',
  base: '/NeoAgent/',
  cleanUrls: true,
  lastUpdated: true,
  themeConfig: {
    nav: [
      {
        text: 'Start',
        activeMatch: '^/(getting-started|why-neoagent)?$',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'Why NeoAgent', link: '/why-neoagent' },
        ],
      },
      {
        text: 'Product',
        activeMatch: '^/(capabilities|automation|integrations|skills)',
        items: [
          { text: 'Capabilities', link: '/capabilities' },
          { text: 'Android Control', link: '/capabilities#android-control' },
          { text: 'Recordings', link: '/capabilities#recordings' },
          { text: 'Integrations', link: '/integrations' },
          { text: 'Automation', link: '/automation' },
        ],
      },
      {
        text: 'Operate',
        activeMatch: '^/(configuration|operations)',
        items: [
          { text: 'Configuration', link: '/configuration' },
          { text: 'Skills', link: '/skills' },
          { text: 'Operations', link: '/operations' },
        ],
      },
      { text: 'Why NeoAgent', link: '/why-neoagent' },
      { text: 'GitHub', link: 'https://github.com/NeoLabs-Systems/NeoAgent' },
    ],
    sidebar: [
      {
        text: 'Start',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'Why NeoAgent', link: '/why-neoagent' },
        ],
      },
      {
        text: 'Product Surface',
        items: [
          {
            text: 'Capabilities',
            link: '/capabilities',
            items: [
              { text: 'Android Control', link: '/capabilities#android-control' },
              { text: 'Recordings', link: '/capabilities#recordings' },
              { text: 'Health Data', link: '/capabilities#health-data' },
              { text: 'Agent Tools', link: '/capabilities#agent-tools' },
              { text: 'Runtime Modes', link: '/capabilities#runtime-modes' },
            ],
          },
          { text: 'Automation', link: '/automation' },
          { text: 'Integrations', link: '/integrations' },
          { text: 'Skills', link: '/skills' },
        ],
      },
      {
        text: 'Operate',
        items: [
          { text: 'Configuration', link: '/configuration' },
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
    outline: {
      level: [2, 3],
      label: 'On This Page',
    },
    editLink: {
      pattern: 'https://github.com/NeoLabs-Systems/NeoAgent/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },
    docFooter: {
      prev: 'Previous',
      next: 'Next',
    },
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright NeoLabs Systems',
    },
  },
});
