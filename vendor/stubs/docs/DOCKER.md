# DOCKER.md
_Docker container reference — human-authored; Claude may propose edits, but never writes them without developer approval_
_Environment-specific gotchas go in docs/memory/environment.md_
_Last updated: YYYY-MM-DD_

## Services
| Service | Image | Purpose |
|---|---|---|
| [name] | [image:tag] | [what it does] |

## Port mappings
| Service | Host | Container |
|---|---|---|
| [name] | [host] | [container] |

## Volume mounts
| Service | Host path | Container path | Purpose |
|---|---|---|---|
| [name] | [path] | [path] | [why] |

## Environment variables
| Variable | Service | Purpose |
|---|---|---|
| [VAR_NAME] | [service] | [what it controls] |

## Service dependencies
[Which containers depend on which. Start order if relevant.]

## Common commands
```bash
docker compose up -d
docker compose down
docker compose exec [service] bash
docker compose logs -f [service]
docker compose build [service]
```

## Config notes
<!-- Persistent config issues only -->
