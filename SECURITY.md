# Security Policy

## Reporting

Please report security issues privately through GitHub Security Advisories for this repository. Avoid opening public issues for vulnerabilities that expose credentials, local files, or provider account data.

## Local Data

AgentBar reads local provider state to show usage and reset information. Depending on enabled providers and source modes, that can include:

- Provider CLI output.
- Usage logs under provider-managed directories.
- OAuth credentials created by provider CLIs.
- Browser cookies for known provider domains.
- API keys or cookie headers you manually add to `~/.agentbar/config.json`.

AgentBar does not send this data to an AgentBar backend.

## File Permissions

AgentBar writes its main config and local credential/token caches with `0600` permissions. Treat `~/.agentbar/config.json` as sensitive if it contains manually configured API keys or cookie headers.

## Logging

AgentBar redacts common email, cookie, authorization, and bearer-token patterns in its logs. Do not run with verbose/debug options when sharing output publicly unless you have reviewed the output first.

## Network Access

AgentBar contacts provider endpoints only to fetch usage/status data for enabled providers and selected source modes. It does not expose an inbound network service.
