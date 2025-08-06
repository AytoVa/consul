# Docker Setup for Consul Rails 5.0.7.2

This document provides comprehensive setup instructions for running the Consul application in Docker containers with Rails 5.0.7.2, Ruby 2.4.9, and PostgreSQL 9.5.21.

## Prerequisites

- Docker Engine 20.10+ 
- Docker Compose 1.29+
- Git
- At least 4GB RAM available for Docker

## Quick Start

1. **Build and start the services:**
   ```bash
   docker-compose up --build
   ```

2. **Access the application:**
   - Web application: http://localhost:3000
   - PostgreSQL: localhost:5432
   - Redis: localhost:6379

## Detailed Setup Instructions

### 1. Environment Configuration

Copy the example configuration files:
```bash
# Database configuration (automatically handled by entrypoint)
cp config/database-docker.yml.example config/database.yml

# Secrets configuration (automatically handled by entrypoint)
cp config/secrets.yml.example config/secrets.yml
```

### 2. Docker Services

The docker-compose.yml includes:

- **app**: Rails 5.0.7.2 application with Puma 4.3.3
- **database**: PostgreSQL 9.5.21
- **redis**: Redis 6.2 for caching and background jobs
- **worker**: Background job processor using delayed_job

### 3. Development Workflow

**Start all services:**
```bash
docker-compose up
```

**Start in background:**
```bash
docker-compose up -d
```

**View logs:**
```bash
docker-compose logs -f app
docker-compose logs -f database
```

**Run Rails commands:**
```bash
# Rails console
docker-compose exec app bundle exec rails console

# Run migrations
docker-compose exec app bundle exec rails db:migrate

# Run tests
docker-compose exec app bundle exec rspec

# Generate new migration
docker-compose exec app bundle exec rails generate migration AddFieldToModel
```

**Install new gems:**
```bash
# Add gem to Gemfile, then:
docker-compose exec app bundle install
docker-compose restart app
```

### 4. Database Management

**Reset database:**
```bash
docker-compose exec app bundle exec rails db:drop db:create db:migrate db:seed
```

**Backup database:**
```bash
docker-compose exec database pg_dump -U postgres consul_development > backup.sql
```

**Restore database:**
```bash
docker-compose exec -T database psql -U postgres consul_development < backup.sql
```

### 5. Database Operations
```bash
docker-compose exec app bundle exec rake db:create
docker-compose exec app bundle exec rake db:migrate
docker-compose exec app bundle exec rake db:seed
```

## Troubleshooting

### Common Issues

**1. Database Connection Errors:**
```bash
# Check if database is ready
docker-compose exec database pg_isready -U postgres

# Restart database service
docker-compose restart database
```

**2. Permission Errors:**
```bash
# Fix file permissions
docker-compose exec app chown -R consul:consul /var/www/consul
```

**3. Bundle Install Failures:**
```bash
# Clear bundle cache and reinstall
docker-compose down
docker volume rm consul_bundle_cache
docker-compose up --build
```

**4. Port Already in Use:**
```bash
# Check what's using port 3000
lsof -i :3000

# Use different port
docker-compose up -p 3001:3000
```

**5. Memory Issues:**
```bash
# Increase Docker memory limit to 4GB+
# Check Docker Desktop settings
```

## Rails 5.0.7.2 Specific Considerations

### Important Caveats for Rails 5.0 + Docker Compatibility

1. **Database Commands**: Rails 5.0 uses `rake` instead of `rails` for database commands:
   ```bash
   # Rails 5.0 syntax
   bundle exec rake db:create
   bundle exec rake db:migrate
   bundle exec rake db:seed

   # NOT: bundle exec rails db:create (Rails 5.1+)
   ```

2. **Asset Pipeline**: Rails 5.0 asset compilation:
   ```bash
   bundle exec rake assets:precompile
   ```

3. **Bundler Compatibility**:
   - Uses Bundler 2.1.4 for compatibility
   - Some gems may require specific versions for Rails 5.0

4. **PostgreSQL Version**:
   - PostgreSQL 9.5.21 is the minimum supported version
   - Newer PostgreSQL features are not available

5. **Ruby Version Lock**:
   - Ruby 2.4.9 is the recommended version for Rails 5.0.7.2
   - Newer Ruby versions may have compatibility issues

## Production Considerations

1. **Environment Variables**: Set proper production values
2. **SSL/TLS**: Configure reverse proxy (nginx/traefik)
3. **Secrets Management**: Use Docker secrets or external vault
4. **Monitoring**: Add health checks and logging
5. **Backup Strategy**: Implement automated database backups

## Capistrano Deployment

The Docker setup is compatible with Capistrano 3.x deployment:

```bash
# Deploy to staging
bundle exec cap staging deploy

# Deploy to production  
bundle exec cap production deploy
```

## Services Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Rails App     │    │   PostgreSQL    │    │     Redis       │
│  (Rails 5.0.7.2)│◄──►│    (9.5.21)     │    │    (6.2)        │
│   Port: 3000    │    │   Port: 5432    │    │   Port: 6379    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲
         │
┌─────────────────┐
│  Worker Service │
│  (delayed_job)  │
└─────────────────┘
```
