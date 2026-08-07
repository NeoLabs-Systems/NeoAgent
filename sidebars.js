/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docsSidebar: [
    'index',
    {
      type: 'category',
      label: '🧭 User Guide',
      collapsed: false,
      items: [
        'getting-started',
        'docker',
        'models',
        'agents-and-users',
        'automation',
        'memory',
        'integrations',
        'devices',
        'health',
        'skills',
        'security-boundaries',
        'operations',
        'billing',
        'migration',
        'configuration',
        'why-neoagent',
        'hardware',
      ],
    },
    {
      type: 'category',
      label: '🛠️ Developer Guide',
      collapsed: false,
      items: [
        'architecture',
        'agent-run-lifecycle',
        'memory-architecture',
        'runtime-and-tools',
        'automation-architecture',
        'integrations-architecture',
        'clients-and-devices',
        'persistence',
        'development',
        'benchmarking',
      ],
    },
  ],
};

module.exports = sidebars;
