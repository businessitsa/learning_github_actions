import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'From Commit to Cloud',
  tagline:
    'A hands-on course: GitHub Actions, OpenTofu and Azure, from zero to a working OIDC deployment pipeline',
  favicon: 'img/favicon.ico',

  url: 'https://businessitsa.github.io',
  baseUrl: '/learning_github_actions/',
  trailingSlash: false,

  organizationName: 'businessitsa',
  projectName: 'learning_github_actions',

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl:
            'https://github.com/businessitsa/learning_github_actions/tree/main/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'From Commit to Cloud',
      items: [
        {
          href: 'https://github.com/businessitsa/learning_github_actions',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Official documentation',
          items: [
            {label: 'GitHub Actions', href: 'https://docs.github.com/en/actions'},
            {label: 'OpenTofu', href: 'https://opentofu.org/docs/'},
            {label: 'Microsoft Azure', href: 'https://learn.microsoft.com/en-us/azure/'},
          ],
        },
      ],
      copyright: `Built as a community learning resource. Content verified against official documentation in July 2026; check SOURCES.md for retrieval dates.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'json', 'yaml', 'hcl', 'powershell', 'ini'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
