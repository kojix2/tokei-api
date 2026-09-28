# tokei-api

Analyze a Git repository with [tokei](https://github.com/XAMPPRocky/tokei) and view the result in a browser or retrieve it as JSON.

[Web app](https://tokei.kojix2.net/) · [API documentation](https://tokei.kojix2.net/api) · [Badge documentation](https://tokei.kojix2.net/badges)

[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Flines)](https://tokei.kojix2.net/github/kojix2/tokei-api)
[![Top Language](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Flanguage)](https://tokei.kojix2.net/github/kojix2/tokei-api)
[![Languages](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Flanguages)](https://tokei.kojix2.net/github/kojix2/tokei-api)
[![Code to Comment](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Fratio)](https://tokei.kojix2.net/github/kojix2/tokei-api)

## What it provides

- A web interface with language charts, file-level statistics, and shareable result pages
- JSON endpoints for repository summaries and per-language statistics
- Direct GitHub URLs such as `/github/owner/repository`
- Dynamic [Shields.io](https://shields.io/) badges
- A SQLite cache to avoid analyzing the same repository on every request

## Try it

Open a GitHub repository in the hosted web app:

```text
https://tokei.kojix2.net/github/kojix2/tokei-api
```

Or use the API:

```bash
# Analyze any supported Git repository.
curl -X POST https://tokei.kojix2.net/api/analyses \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://github.com/kojix2/tokei-api.git"}'

# Analyze a GitHub repository and return its summary.
curl https://tokei.kojix2.net/api/github/kojix2/tokei-api

# Return its language breakdown.
curl https://tokei.kojix2.net/api/github/kojix2/tokei-api/languages
```

## API

### Analyses

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/api/analyses` | Analyze the repository in the JSON `url` field |
| `GET` | `/api/analyses?url=...` | Retrieve the latest cached analysis for a repository URL |
| `GET` | `/api/analyses/:id` | Retrieve an analysis by ID |
| `GET` | `/api/analyses/:id/languages` | Retrieve its language breakdown |
| `GET` | `/api/github/:owner/:repo` | Analyze a GitHub repository |
| `GET` | `/api/github/:owner/:repo/languages` | Retrieve its language breakdown |

### Badges

| Endpoint | Purpose |
| --- | --- |
| `/badge/github/:owner/:repo/:type` | Analyze a GitHub repository and return Shields.io endpoint JSON |
| `/api/badge/:type?url=...` | Return badge JSON for an already-cached repository |
| `/api/analyses/:id/badges/:type` | Return badge JSON for an analysis ID |
| `/api/github/:owner/:repo/badges/:type` | Return badge JSON for a GitHub repository |

Badge types are `lines`, `language`, `languages`, and `ratio`.

## Add a badge to a README

Shields.io renders the JSON returned by tokei-api. Replace `OWNER` and `REPOSITORY` in this example:

```markdown
[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2FOWNER%2FREPOSITORY%2Flines)](https://tokei.kojix2.net/github/OWNER/REPOSITORY)
```

Change the final `lines` segment to another badge type as needed. For a non-GitHub repository, analyze it first and use `/api/badge/:type?url=...` as the URL passed to Shields.io.

## Run locally

### Docker Compose

Docker Compose is the quickest way to run the complete application:

```bash
cp .env.example .env
docker compose up --build
```

Then open <http://localhost:3000>. The default SQLite cache is stored inside the container and is lost when the container is replaced.

### Native development

Requirements:

- Crystal 1.21 or later
- Git
- [tokei](https://github.com/XAMPPRocky/tokei)
- SQLite development libraries
- A `timeout` command; on macOS, install GNU coreutils and make its `timeout` command available on `PATH`

```bash
git clone https://github.com/kojix2/tokei-api.git
cd tokei-api
shards install
cp .env.example .env
crystal run src/main.cr
```

The database and its tables are created automatically on startup.

## Configuration

The application loads settings from the environment and from `.env` when present.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `3000` | HTTP port |
| `BASE_URL` | `http://localhost:$PORT` | Canonical public URL used in links, Open Graph metadata, and badges |
| `CACHE_DB_PATH` | `/tmp/tokei-api/tokei-api.sqlite3` | SQLite cache path |
| `TEMP_DIR` | `/tmp/tokei-api` | Working directory for repository clones |
| `RETENTION_DAYS` | `7` | Number of days to retain cached analyses |
| `CLONE_TIMEOUT_SECONDS` | `30` | Git clone timeout |
| `TOKEI_TIMEOUT_SECONDS` | `30` | Repository analysis timeout |
| `KEMAL_ENV` | `development` | Kemal environment |

Set `BASE_URL` in production so generated links and badges use the correct public origin.

## Test

```bash
crystal spec
```

## Deployment notes

- The default database path is intentionally ephemeral. Mount persistent storage and change `CACHE_DB_PATH` if analysis results must survive instance replacement.
- Use a single application instance when SQLite is stored in a local file.
- Repository URLs and analysis results are cached temporarily. The service does not use user tracking or long-term analytics.
- Access logs are kept minimal and are used for operations and abuse prevention.

The included [Dockerfile](Dockerfile) builds a production image containing the application and `tokei`.

## License

[MIT](LICENSE)
