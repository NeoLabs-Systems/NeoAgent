// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'NeoAgent',
  tagline: 'Self-hosted proactive AI agent docs',

  url: 'https://neolabs-systems.github.io',
  baseUrl: '/NeoAgent/',

  organizationName: 'NeoLabs-Systems',
  projectName: 'NeoAgent',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',
  trailingSlash: false,

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          path: 'docs',
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/NeoLabs-Systems/NeoAgent/edit/main/',
          showLastUpdateAuthor: false,
          showLastUpdateTime: true,
          breadcrumbs: true,
          sidebarCollapsed: false,
        },
        blog: false,
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'NeoAgent',
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Docs',
          },
          {
            to: '/capabilities#android-control',
            label: 'Android Control',
            position: 'left',
          },
          {
            to: '/capabilities#recordings',
            label: 'Recordings',
            position: 'left',
          },
          {
            to: '/why-neoagent',
            label: 'Why NeoAgent',
            position: 'left',
          },
          {
            href: 'https://github.com/NeoLabs-Systems/NeoAgent',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      tableOfContents: {
        minHeadingLevel: 2,
        maxHeadingLevel: 3,
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              { label: 'Getting Started', to: '/getting-started' },
              { label: 'Capabilities', to: '/capabilities' },
              { label: 'Configuration', to: '/configuration' },
              { label: 'Operations', to: '/operations' },
            ],
          },
          {
            title: 'Project',
            items: [
              { label: 'GitHub', href: 'https://github.com/NeoLabs-Systems/NeoAgent' },
              { label: 'Issues', href: 'https://github.com/NeoLabs-Systems/NeoAgent/issues' },
            ],
          },
        ],
        copyright: `Copyright ${new Date().getFullYear()} NeoLabs Systems. Released under the MIT License.`,
      },
    }),
};

module.exports = config;
