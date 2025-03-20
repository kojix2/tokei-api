# tokei-api

tokei-api is a web application that provides an API to retrieve source code from a specified Git repository, execute the [tokei](https://github.com/XAMPPRocky/tokei) command, and return the results in JSON format. It also provides a web interface to visualize the code statistics.

## Features

### API

- `POST /api/analyze` - Analyzes the source code of a specified Git repository and returns the results in JSON

  ```json
  {
    "repo_url": "https://github.com/crystal-lang/crystal.git"
  }
  ```

- `GET /api/analysis/:id` - Retrieves a specific analysis result

### Web Interface

- Input repository URL on the home page for analysis
- Visualize results with graphs and tables
- View past analysis results

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
   # Edit the .env file to set database connection information
   ```

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
curl -X POST -H "Content-Type: application/json" -d '{"repo_url":"https://github.com/crystal-lang/crystal.git"}' http://localhost:3000/api/analyze

# Retrieve a specific analysis result
curl http://localhost:3000/api/analysis/[analysis-id]
```

### Web Interface

Access http://localhost:3000 in your browser and enter a repository URL in the form to run the analysis.

## Development

```bash
# Run in development mode (auto-reload)
crystal run src/tokei-api.cr
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
docker-compose up -d

# Check logs
docker-compose logs -f

# Stop containers
docker-compose down

# Completely remove including database volume
docker-compose down -v
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
