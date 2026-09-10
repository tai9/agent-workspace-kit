# Cross-repo contracts

Each section names one contract that spans repos and fails silently when only
one side moves. `contract-check` reads the paths from `contracts:` in
`workspace.yml`; this file holds the rules a reviewer needs.

## example

- **Owner:** backend. **Consumers:** app.
- **Closed set?** no.
- **Deploy order:** backend live before the app build ships.
- **If one side is missing:** the app falls back to its bundled default.
