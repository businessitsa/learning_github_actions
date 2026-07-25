import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// Explicit sidebar: the course is strictly sequential, so the order here is
// the order a learner should follow.
const sidebars: SidebarsConfig = {
  course: [
    'intro',
    {
      type: 'category',
      label: '1. Foundations',
      items: [
        'foundations/what-is-iac',
        'foundations/how-the-tools-fit',
        'foundations/lab',
      ],
    },
    {
      type: 'category',
      label: '2. GitHub Actions basics',
      items: [
        'github-actions/workflow-anatomy',
        'github-actions/triggers-and-contexts',
        'github-actions/lab',
      ],
    },
    {
      type: 'category',
      label: '3. Azure for IaC',
      items: [
        'azure/identity-and-hierarchy',
        'azure/rbac-least-privilege',
        'azure/lab',
      ],
    },
    {
      type: 'category',
      label: '4. OpenTofu fundamentals',
      items: [
        'opentofu/hcl-and-providers',
        'opentofu/state-and-lifecycle',
        'opentofu/remote-state-azure',
        'opentofu/lab',
      ],
    },
    {
      type: 'category',
      label: '5. Wiring it together with OIDC',
      items: [
        'oidc-pipeline/oidc-explained',
        'oidc-pipeline/federated-credentials',
        'oidc-pipeline/plan-and-apply-workflows',
        'oidc-pipeline/lab',
      ],
    },
    {
      type: 'category',
      label: '6. Security deep dive',
      items: [
        'security/hardening-workflows',
        'security/scanning-and-state-security',
        'security/lab',
      ],
    },
    {
      type: 'category',
      label: '7. Capstone',
      items: [
        'capstone/overview',
        'capstone/repository-walkthrough',
        'capstone/run-the-pipeline',
        'capstone/teardown',
      ],
    },
  ],
};

export default sidebars;
