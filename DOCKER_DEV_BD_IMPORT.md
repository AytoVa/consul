# Consul Database Import & Admin Creation Guide

This guide explains how to import a **production** database dump into your **local Docker** environment and create a local admin user for development purposes.

---

## Prerequisites

- Docker **and** Docker Compose installed
- CONSUL project running locally with Docker
- Database dump file (`.sql` **or** `.sql.gz`)

---

# Part 1 · Database Import

### Step 1 · Prepare the Database Dump

1. **Place the dump file** in the `db/` folder of your project:
   ```bash
   # Example: copy your dump file to the db folder
   cp /path/to/your/dump-file.sql db/
   ```
2. **Check if the file is compressed**:
   ```bash
   file db/your-dump-file.sql
   ```
   - If it shows `gzip compressed data`, it's compressed.
   - If it shows `ASCII text`, it's uncompressed.

---

### Step 2 · Stop Application Containers

```bash
# Stop app and worker to free database connections
docker compose stop app worker
```

### Step 3 · (Recommended) Backup Current Database

```bash
# Create backup with timestamp
docker exec -it consul_postgres pg_dump -U postgres consul_development > \
  backup_before_import_$(date +%Y%m%d_%H%M%S).sql
```

### Step 4 · Drop and Re‑create Database

```bash
# Terminate any remaining connections
docker exec -it consul_postgres psql -U postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity \
   WHERE datname = 'consul_development' AND pid <> pg_backend_pid();"

# Drop the database
docker exec -it consul_postgres psql -U postgres -c \
  "DROP DATABASE IF EXISTS consul_development;"

# Create fresh database
docker exec -it consul_postgres psql -U postgres -c \
  "CREATE DATABASE consul_development;"
```

### Step 5 · Import the Database Dump

**For compressed files (**`.sql.gz`**):**

```bash
gunzip -c db/your-dump-file.sql.gz | \
  docker exec -i consul_postgres psql -U postgres -d consul_development
```

**For uncompressed files (**`.sql`**):**

```bash
docker exec -i consul_postgres psql -U postgres -d consul_development < \
  db/your-dump-file.sql
```

### Step 6 · Verify Import

```bash
# 1 · List tables (first 20)
docker exec -it consul_postgres psql -U postgres -d consul_development -c "\dt" | head -20

# 2 · Total users
docker exec -it consul_postgres psql -U postgres -d consul_development -c \
  "SELECT count(*) AS total_users FROM users;"

# 3 · Existing admin users
docker exec -it consul_postgres psql -U postgres -d consul_development -c \
  "SELECT u.username, u.email FROM users u \
   JOIN administrators a ON u.id = a.user_id;"
```

### Step 7 · Start Application

```bash
# Start the application containers
docker compose up -d app worker

# Run any pending migrations
docker exec -it consul_app bundle exec rake db:migrate
```

---

# Part 2 · Create Local Admin User

## Method 1 · Rails Console (Recommended)

1. **Open Rails console**
   ```bash
   docker exec -it consul_app bundle exec rails console
   ```
2. **Create admin user** (copy‑paste):
   ```ruby
   # Create admin user with required fields
   admin = User.new(
     username: "admin_local",
     email:    "admin@local.dev",
     password: "password123",
     password_confirmation: "password123",
     confirmed_at:       Time.current,
     terms_of_service:   "1",
     gender:             "male"
   )

   # Save the user
   admin.save!

   # Create administrator record
   Administrator.create!(user: admin)

   # Verify it worked
   puts "User created: #{admin.username} - #{admin.email}"
   puts "Is admin: #{admin.administrator.present?}"
   puts "User ID: #{admin.id}"
   ```
3. **Exit console**
   ```bash
   exit
   ```

---

## Method 2 · Rails Runner (One‑liner)

```bash
docker exec -it consul_app bundle exec rails runner "
admin = User.create!(
  username: 'admin_local',
  email:    'admin@local.dev',
  password: 'password123',
  password_confirmation: 'password123',
  confirmed_at:     Time.current,
  terms_of_service: '1',
  gender:           'male'
)
Administrator.create!(user: admin)
puts 'Admin created: admin@local.dev / password123'
"
```

---

## Admin Access Information

| Field        | Value             |
| ------------ | ----------------- |
| **Email**    | `admin@local.dev` |
| **Password** | `password123`     |
| **Username** | `admin_local`     |

### Access URLs

- **Login Page:** [http://localhost:3000/presupuestosparticipativos/users/sign\_in](http://localhost:3000/presupuestosparticipativos/users/sign_in)
- **Admin Panel:** [http://localhost:3000/presupuestosparticipativos/admin/settings](http://localhost:3000/presupuestosparticipativos/admin/settings)

---

## Important Notes

### Database Import

- **Data Loss Warning:** Importing will **replace** your local database.
- **Production Data:** You'll have real production data locally—handle with care.
- **Migrations:** Always run `rake db:migrate` after import.

### Admin Creation

- **Required Fields:** `terms_of_service` and `gender` are mandatory.
- **Security:** Change the default password in production.
- **Multiple Admins:** Create more admins by changing email/username.

### Validation Requirements

- `terms_of_service: "1"` - Required for every user.
- `gender: "male" / "female" / "no_answer"` - Required for **non‑admin** users.
- `confirmed_at: Time.current` - Marks email as confirmed.

---

# Troubleshooting

### Common Issues

- **"Database is being accessed by other users"**

  ```bash
  docker compose stop app worker
  ```

- **"Terms of service must be accepted"** - Add `terms_of_service: "1"` when creating user.

- **"Gender must be selected"** - Include `gender: "male"` (or `"female"`, `"no_answer"`).

- **Import shows encoding errors**

  ```bash
  file db/your-dump-file.sql  # Check compression
  gunzip -c …                 # Use if compressed
  ```

---

## Quick Reference Commands Quick Reference Commands

```bash
# Complete database import workflow
docker compose stop app worker
docker exec -i consul_postgres psql -U postgres -d consul_development < db/dump-file.sql
docker compose up -d app worker

# Create admin user (one‑liner)
docker exec -it consul_app bundle exec rails runner "admin = User.create!(username: 'admin_local', email: 'admin@local.dev', password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current, terms_of_service: '1', gender: 'male'); Administrator.create!(user: admin); puts 'Admin created: admin@local.dev / password123'"

# Test application is up
curl -s -o /dev/null -w "%{http_code}" \
  http://localhost:3000/presupuestosparticipativos
```

---

## Success Verification

After completing **Part 1** and **Part 2** you should be able to:

1. **Access the app** at [http://localhost:3000/presupuestosparticipativos](http://localhost:3000/presupuestosparticipativos)
2. **Log in** with `admin@local.dev` / `password123`
3. **Access** the admin panel at `/admin/settings`
4. **See** imported production data (users, proposals, etc.)
