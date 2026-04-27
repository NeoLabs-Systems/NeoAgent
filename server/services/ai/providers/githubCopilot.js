const { OpenAIProvider } = require('./openai');

class GithubCopilotProvider extends OpenAIProvider {
  constructor(config = {}) {
    // GitHub Copilot base URL defaults to the individual endpoint
    const defaultBaseUrl = 'https://api.individual.githubcopilot.com';
    const baseUrl = config.baseUrl || process.env.GITHUB_COPILOT_BASE_URL || defaultBaseUrl;

    super({
      ...config,
      apiKey: config.apiKey || process.env.GITHUB_COPILOT_ACCESS_TOKEN,
      baseUrl,
      // Pass special headers required by GitHub Copilot
      defaultHeaders: {
        'Editor-Version': 'vscode/1.90.0',
        'Editor-Plugin-Version': 'copilot-chat/0.15.0',
        'User-Agent': 'GithubCopilot/1.155.0',
        'X-Github-Api-Version': '2023-07-07',
        'Copilot-Integration-Id': 'vscode-chat'
      }
    });
    this.name = 'github-copilot';
    this.githubToken = config.apiKey || process.env.GITHUB_COPILOT_ACCESS_TOKEN;
    this.copilotToken = null;
    this.tokenExpiresAt = 0;
    this._refreshPromise = null;
  }

  async _refreshCopilotToken() {
    if (this._refreshPromise) return this._refreshPromise;

    const now = Math.floor(Date.now() / 1000);
    // Refresh token if missing or expiring in less than 5 minutes
    if (this.copilotToken && this.tokenExpiresAt >= now + 300) {
      return;
    }

    this._refreshPromise = (async () => {
      try {
        if (!this.githubToken) {
          throw new Error('GitHub Copilot access token is missing. Please run `neoagent login github-copilot`.');
        }

        const res = await fetch('https://api.github.com/copilot_internal/v2/token', {
          headers: {
            'Authorization': `token ${this.githubToken}`,
            'Accept': 'application/json',
            'User-Agent': 'NeoAgent/1.0.0'
          }
        });

        if (!res.ok) {
          const errorText = await res.text().catch(() => 'Unknown error');
          throw new Error(`Failed to refresh GitHub Copilot token: HTTP ${res.status} - ${errorText}`);
        }

        const data = await res.json();
        if (!data || typeof data.token !== 'string' || !data.token) {
          throw new Error('Invalid token response from GitHub Copilot.');
        }

        this.copilotToken = data.token;
        this.tokenExpiresAt = typeof data.expires_at === 'number'
          ? data.expires_at
          : Math.floor(new Date(data.expires_at).getTime() / 1000);

        if (isNaN(this.tokenExpiresAt)) {
          this.tokenExpiresAt = Math.floor(Date.now() / 1000) + 1800;
        }

        // Update the client's API key
        this.client.apiKey = this.copilotToken;
      } finally {
        this._refreshPromise = null;
      }
    })();

    return this._refreshPromise;
  }

  async chat(messages, tools = [], options = {}) {
    await this._refreshCopilotToken();
    return super.chat(messages, tools, options);
  }

  async *stream(messages, tools = [], options = {}) {
    await this._refreshCopilotToken();
    yield* super.stream(messages, tools, options);
  }

  async analyzeImage(options = {}) {
    await this._refreshCopilotToken();
    return super.analyzeImage(options);
  }
}

module.exports = { GithubCopilotProvider };
