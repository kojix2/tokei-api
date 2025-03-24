# tokei-api

[![Lines of Code](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Flines)](https://tokei.kojix2.net/github/kojix2/tokei-api)
[![Top Language](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Flanguage)](https://tokei.kojix2.net/github/kojix2/tokei-api)
[![Languages](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Flanguages)](https://tokei.kojix2.net/github/kojix2/tokei-api)
[![Code to Comment](https://img.shields.io/endpoint?url=https%3A%2F%2Ftokei.kojix2.net%2Fbadge%2Fgithub%2Fkojix2%2Ftokei-api%2Fratio)](https://tokei.kojix2.net/github/kojix2/tokei-api)

tokei-api is a web application that provides an API to retrieve source code from a specified Git repository, execute the [tokei](https://github.com/XAMPPRocky/tokei) command, and return the results in JSON format. It also provides a web interface to visualize the code statistics.

## Features

### API

#### Core API

- `POST /api/analyses` - Analyzes the source code of a specified Git repository and returns the results in JSON

  ```json
  {
    "url": "https://github.com/kojix2/tokei-api.git"
  }
  ```

- `GET /api/analyses/:id` - Retrieves a specific analysis result with detailed information
- `GET /api/analyses/:id/languages` - Retrieves language statistics for a specific analysis
- `GET /api/analyses/:id/badges/:type` - Retrieves badge data for a specific analysis

#### GitHub-specific API

- `GET /api/github/:owner/:repo` - Analyzes a GitHub repository directly
- `GET /api/github/:owner/:repo/languages` - Retrieves language statistics for a GitHub repository
- `GET /api/github/:owner/:repo/badges/:type` - Retrieves badge data for a GitHub repository

#### Badge API

- `GET /badge/github/:owner/:repo/:type` - Simplified URL for retrieving badge data in shields.io compatible format

Available badge types: `lines`, `language`, `languages`, `ratio`

- `GET /api/badge/:type?url=...` - Retrieves badge data in shields.io compatible format for any Git repository

### Web Interface

- Input repository URL on the home page for analysis
- Visualize results with graphs and tables
- View past analysis results
- Direct access to GitHub repositories via `/github/:owner/:repo`
- Badge integration for READMEs

## Installation

### Requirements

- [Crystal](https://crystal-lang.org/) 1.15.1 or higher
- [tokei](https://github.com/XAMPPRocky/tokei) command
- [Git](https://git-scm.com/)
- PostgreSQL (or Neon)

### Setup

1. Clone the repository

   ```bash
   git clone https://github.com/kojix2/tokei-api.git
   cd tokei-api
   ```

2. Install dependencies

   ```bash
   shards install
   ```

3. Set environment variables

   ```bash
   cp .env.example .env
   # Edit the .env file to set database connection information and other settings
   ```

   Key environment variables:
   - `DATABASE_URL`: PostgreSQL connection string
   - `DATABASE_PROVIDER`: Database provider (local or neon)
   - `TEMP_DIR`: Directory for temporary git clones
   - `CLONE_TIMEOUT_SECONDS`: Timeout for git clone operations (default: 30)

4. Prepare the database

   ```bash
   # Tables will be created automatically on first application startup
   ```

5. Start the application
   ```bash
   crystal run src/tokei-api.cr
   ```

## Usage

### API Usage Examples

```bash
# Analyze a repository
curl -X POST -H "Content-Type: application/json" -d '{"url":"https://github.com/kojix2/tokei-api.git"}' http://localhost:3000/api/analyses

# Analyze a GitHub repository directly
curl http://localhost:3000/api/github/kojix2/tokei-api

# Retrieve language statistics
curl http://localhost:3000/api/github/kojix2/tokei-api/languages

# Get badge data
curl http://localhost:3000/badge/github/kojix2/tokei-api/lines
```

### Badge Integration

You can add badges to your README to showcase your code statistics:

```markdown
[![Lines of Code](https://tokei.kojix2.net/badge/github/username/repo/lines)](https://tokei.kojix2.net/github/username/repo)
[![Top Language](https://tokei.kojix2.net/badge/github/username/repo/language)](https://tokei.kojix2.net/github/username/repo)
[![Languages](https://tokei.kojix2.net/badge/github/username/repo/languages)](https://tokei.kojix2.net/github/username/repo)
[![Code to Comment](https://tokei.kojix2.net/badge/github/username/repo/ratio)](https://tokei.kojix2.net/github/username/repo)
```

These badges are dynamic and will automatically reflect the latest analysis of your repository.

### Web Interface

Access http://localhost:3000 in your browser and enter a repository URL in the form to run the analysis.

For GitHub repositories, you can use the direct access URL format:

```
http://localhost:3000/github/owner/repo
```

For example: http://localhost:3000/github/kojix2/tokei-api

## Development

```bash
# Run in development mode (auto-reload)
crystal run src/tokei-api.cr
```

### Database Schema

The application uses a PostgreSQL database with the following schema:

```sql
CREATE TABLE analyses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  repo_url TEXT NOT NULL,
  analyzed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  result JSONB NOT NULL,
  total_lines INTEGER,
  total_code INTEGER,
  total_comments INTEGER,
  total_blanks INTEGER,
  top_language TEXT,
  top_language_lines INTEGER,
  language_count INTEGER,
  code_comment_ratio FLOAT
);
```

## Deployment

### Deploying to Koyeb

1. Create a Koyeb account
2. Create a new application
3. Connect your GitHub repository
4. Set environment variables (DATABASE_URL, etc.)
5. Execute deployment

## Running with Docker

### Running in a single container

```bash
# Build Docker image
docker build -t tokei-api .

# Run container
docker run -p 3000:3000 --env-file .env tokei-api
```

### Running with Docker Compose (recommended)

Docker Compose allows you to start the application and PostgreSQL database together.

```bash
# Build and start containers
docker compose up -d

# Check logs
docker compose logs -f

# Stop containers
docker compose down

# Completely remove including database volume
docker compose down -v
```

#### Switching environments

You can switch between local PostgreSQL and Neon by changing `DATABASE_PROVIDER` in the `.env` file:

```
# For local development (PostgreSQL in Docker Compose)
DATABASE_PROVIDER=local
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/tokei-api

# For Neon connection (when deploying to Koyeb)
# DATABASE_PROVIDER=neon
# DATABASE_URL=postgresql://username:password@hostname/database?sslmode=require
```

## Technology Stack

- **Language:** Crystal
- **Framework:** Kemal
- **Database:** PostgreSQL (Neon)
- **Frontend:** Bootstrap, Chart.js
- **Other:** tokei, Git

## License

[MIT](LICENSE)

## Contributing

1. Fork it (<https://github.com/kojix2/tokei-api/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Author

- [kojix2](https://github.com/kojix2) - creator and maintainer
