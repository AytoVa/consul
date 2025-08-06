# Rails 5.0.7.2 Docker Setup - Quick Start Guide

## Overview

This setup provides a containerized development environment for Consul running on:
- **Rails 5.0.7.2**
- **Ruby 2.4.9**
- **Puma 4.3.3**
- **Bundler 2.1.4**
- **PostgreSQL 9.5.21**
- **Capistrano 3.x** (for deployment)

## Quick Start

1. **Ensure you're on the correct branch:**
   ```bash
   git checkout feature/development-env-poc
   ```

2. **Build and start services:**
   ```bash
   docker-compose up --build
   ```

3. **Access the application:**
   - Web app: http://localhost:3000
   - PostgreSQL: localhost:5432
   - Redis: localhost:6379

## Rails 5.0 Specific Commands

### Database Operations (use `rake` not `rails`)
```bash
# Create database
docker-compose exec app bundle exec rake db:create

# Run migrations
docker-compose exec app bundle exec rake db:migrate

# Seed database
docker-compose exec app bundle exec rake db:seed

# Reset database
docker-compose exec app bundle exec rake db:drop db:create db:migrate db:seed
```

### Asset Compilation
```bash
# Precompile assets
docker-compose exec app bundle exec rake assets:precompile

# Clean assets
docker-compose exec app bundle exec rake assets:clean
```

### Console Access
```bash
# Rails console
docker-compose exec app bundle exec rails console

# Database console
docker-compose exec app bundle exec rails dbconsole
```

## Important Rails 5.0 Caveats

1. **Database Commands**: Always use `rake db:*` instead of `rails db:*`
2. **Asset Pipeline**: Use `rake assets:*` for asset operations
3. **Bundler**: Locked to version 2.1.4 for compatibility
4. **PostgreSQL**: Minimum version 9.5.21 required
5. **Ruby Version**: Must use Ruby 2.4.9 for optimal compatibility

## Troubleshooting

### Bundle Issues
```bash
# Rebuild bundle
docker-compose exec app bundle install --redownload

# Clear bundle cache
docker-compose down
docker volume rm consul_bundle_cache
docker-compose up --build
```

### Database Issues
```bash
# Reset database completely
docker-compose exec app bundle exec rake db:drop db:create db:migrate db:seed
```

### Permission Issues
```bash
# Fix file permissions
docker-compose exec app chown -R consul:consul /var/www/consul
```

## Development Workflow

1. **Start services in background:**
   ```bash
   docker-compose up -d
   ```

2. **View logs:**
   ```bash
   docker-compose logs -f app
   ```

3. **Run tests:**
   ```bash
   docker-compose exec app bundle exec rspec
   ```

4. **Stop services:**
   ```bash
   docker-compose down
   ```

## Production Deployment

The Docker setup is compatible with Capistrano 3.x:

```bash
# Deploy to staging
bundle exec cap staging deploy

# Deploy to production
bundle exec cap production deploy
```

## Key Files

- `Dockerfile` - Rails 5.0.7.2 container definition
- `docker-compose.yml` - Multi-service orchestration
- `config/database-docker.yml.example` - Rails 5.0 database config
- `scripts/entrypoint.sh` - Container startup script
- `.dockerignore` - Build optimization

For detailed documentation, see `DOCKER_SETUP.md`.
