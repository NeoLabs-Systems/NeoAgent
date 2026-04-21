/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docsSidebar: [
    {
      type: 'category',
      label: 'Start',
      collapsed: false,
      items: ['index', 'getting-started', 'why-neoagent'],
    },
    {
      type: 'category',
      label: 'Product Surface',
      collapsed: false,
      items: [
        'capabilities',
        {
          type: 'link',
          label: 'Android Control',
          href: '/capabilities#android-control',
        },
        {
          type: 'link',
          label: 'Recordings',
          href: '/capabilities#recordings',
        },
        {
          type: 'link',
          label: 'Health Data',
          href: '/capabilities#health-data',
        },
        {
          type: 'link',
          label: 'Agent Tools',
          href: '/capabilities#agent-tools',
        },
        {
          type: 'link',
          label: 'Runtime Modes',
          href: '/capabilities#runtime-modes',
        },
        'automation',
        'integrations',
        'skills',
      ],
    },
    {
      type: 'category',
      label: 'Operate',
      collapsed: false,
      items: [
        'configuration',
        'operations',
        {
          type: 'doc',
          id: 'hardware',
          label: 'Waveshare 1.8inch AMOLED Setup',
        },
      ],
    },
  ],
};

module.exports = sidebars;
