// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'NeoAgent',
  tagline: 'Documentation for the self-hosted NeoAgent service',

  url: 'https://neolabs-systems.github.io',
  baseUrl: '/NeoAgent/docs/',

  organizationName: 'NeoLabs-Systems',
  projectName: 'NeoAgent',

  onBrokenLinks: 'throw',
  trailingSlash: false,

  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

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
            type: 'doc',
            docId: 'getting-started',
            label: 'User Guide',
            position: 'left',
          },
          {
            type: 'doc',
            docId: 'architecture',
            label: 'Developer Guide',
            position: 'left',
          },
          {
            type: 'doc',
            docId: 'memory',
            label: 'Memory',
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
              { label: 'Installation', to: '/getting-started' },
              { label: 'Memory', to: '/memory' },
              { label: 'Security', to: '/security-boundaries' },
              { label: 'Configuration', to: '/configuration' },
            ],
          },
          {
            title: 'Developers',
            items: [
              { label: 'Architecture', to: '/architecture' },
              { label: 'Memory Architecture', to: '/memory-architecture' },
              { label: 'Development', to: '/development' },
            ],
          },
          {
            title: 'Project',
            items: [
              { label: 'GitHub', href: 'https://github.com/NeoLabs-Systems/NeoAgent' },
              { label: 'Issues', href: 'https://github.com/NeoLabs-Systems/NeoAgent/issues' },
              { label: 'Discussions', href: 'https://github.com/NeoLabs-Systems/NeoAgent/discussions' },
            ],
          },
        ],
        copyright: `Copyright ${new Date().getFullYear()} NeoLabs Systems. Released under the GNU AGPLv3 License.`,
      },
    }),
};

module.exports = config;
