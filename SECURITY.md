# Security policy

## Supported versions

Fixes land on the latest minor release only.

| Version | Supported |
|---|---|
| 0.2.x | Yes |
| Older | No |

## Reporting a vulnerability

`lumenparty` installs hooks that are meant to stop an agent from pushing to
protected branches, merging without review, releasing, or reading signing
keys and other secret files. A command or tool call that slips past a hook it
should be caught by, a hook that can be made to run something it should not,
or a way to read a protected file without being blocked is a security
problem.

The gaps listed under **Known gaps** in the README are already known and do
not need a report, but a new way around them does.

Please report privately: open this repository's **Security** tab and choose
**Report a vulnerability**. This creates a private advisory that only you and
the maintainer can see.

Do **not** open a public issue, pull request or discussion for a
vulnerability.

Useful things to include:

- the plugin version and your Claude Code version
- the hook or agent involved, and the exact command or tool call that got
  through
- what an agent or an attacker could achieve, and any fix you have in mind

## What to expect

You will usually get a first reply within a week. Once the issue is
confirmed, a fix is prepared in the private advisory, released, and the
advisory is published with credit to you unless you prefer otherwise.
