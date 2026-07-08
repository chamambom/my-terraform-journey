# Atlassian Rovo MCP Server — Authentication

The Atlassian Rovo MCP Server is a cloud-hosted remote MCP server that provides AI agents access to Jira, Confluence, and Compass. It uses **OAuth 2.1** as its primary authentication mechanism.

## Endpoint

```
https://mcp.atlassian.com/v1/mcp/authv2
```

> **Note:** The legacy `/v1/sse` endpoint was deprecated and stopped working after 30 June 2026. All clients must use `/v1/mcp/authv2`.

## How Authentication Works

1. **Client connects** — Kiro CLI (or any MCP client) connects to the endpoint
2. **OAuth 2.1 flow initiated** — The server responds with an auth challenge
3. **Browser consent** — A browser opens showing Atlassian's consent screen
4. **User grants permissions** — You select which scopes to allow (read/write Jira, Confluence, etc.)
5. **Token issued** — Client receives an access token + refresh token
6. **Token stored** — Kiro CLI persists the token locally for future sessions
7. **Auto-refresh** — When the token expires, Kiro CLI refreshes it transparently

## Permission Scopes

When you authenticate, Atlassian presents a consent screen with these scope categories:

| Category | Scope | What It Allows |
|---|---|---|
| Read | `read_jira` | View Jira issues, projects, and details |
| Read | `read_confluence` | Read Confluence pages, spaces, and comments |
| Read | `read_compass` | View Compass components and scorecards |
| Read | `read_jsm` | View JSM alerts and on-call settings |
| Read | `read_teamwork_graph` | Read relationships across Atlassian apps |
| Search | `search_jira` | Search Jira with JQL |
| Search | `search_confluence` | Search Confluence pages and spaces |
| Search | `search_atlassian` | Search across Jira and Confluence |
| Write | `write_jira` | Create and edit Jira issues |
| Write | `write_confluence` | Create and update Confluence pages |
| Write | `write_compass` | Create and update Compass components |
| Write | `write_jsm` | Update JSM alerts |
| Write | `write_teamwork_graph` | Create relationships in the Teamwork Graph |

## Configuration in Kiro CLI

Minimal configuration — the server handles OAuth on its side:

```json
{
  "mcpServers": {
    "atlassian-mcp-server": {
      "url": "https://mcp.atlassian.com/v1/mcp/authv2",
      "type": "http",
      "disabled": false,
      "autoApprove": [
        "getConfluencePage",
        "search",
        "updateConfluencePage"
      ]
    }
  }
}
```

## Managing Authentication

| Action | Command | When to Use |
|---|---|---|
| View status | `/mcp` | Check if server is authenticated |
| Force re-auth | `/mcp auth atlassian-mcp-server` | Token expired or scopes changed |
| Abort auth flow | `/mcp cancel-auth atlassian-mcp-server` | Auth stuck waiting for browser |
| Remove credentials | `/mcp logout atlassian-mcp-server` | Start fresh or switch accounts |

## Troubleshooting

### "Unauthorized; scope does not match"

This means the OAuth token was granted with insufficient scopes. Common causes:

1. **Didn't grant all permissions** — During the browser consent flow, you may not have selected all scope categories. Re-authenticate: `/mcp logout` then `/mcp auth`
2. **Org admin restriction** — Your Atlassian org admin may have restricted which scopes the MCP app can request. Check admin console at `https://admin.atlassian.com` under Security > API tokens or Connected apps
3. **Stale token** — The in-memory token may be from a previous session with different scopes. Full restart: logout, restart Kiro CLI, then re-auth

### Token works for userInfo but not Jira

The `atlassianUserInfo` tool only needs basic profile scopes (`openid`, `email`, `profile`). If this works but Jira/Confluence calls fail, it confirms the token lacks product-specific scopes. Re-authenticate and ensure you grant all categories on the consent screen.

## Alternative: API Token Authentication

If your org admin enables it, you can authenticate with an API token instead of OAuth:

1. Generate a token at: https://id.atlassian.com/manage-profile/security/api-tokens
2. Configure with headers instead of OAuth:

```json
{
  "mcpServers": {
    "atlassian-mcp-server": {
      "url": "https://mcp.atlassian.com/v1/mcp/authv2",
      "type": "http",
      "headers": {
        "Authorization": "Bearer <your-api-token>"
      }
    }
  }
}
```

This bypasses the browser OAuth flow entirely. Useful for CI/CD or headless environments.

## References

- [Atlassian Rovo MCP Server - Authentication and Authorization](https://support.atlassian.com/rovo/docs/authentication-and-authorization/)
- [Configuring OAuth 2.1](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/configuring-oauth-2-1/)
- [Configuring API Token Authentication](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/configuring-authentication-via-api-token/)
- [Setting up IDEs](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-ides/)
