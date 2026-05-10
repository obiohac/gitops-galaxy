#!/bin/bash
# database-init.sh
# Initialize PostgreSQL database with test data and schema

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
NAMESPACE=${1:-"db-layer"}
DB_POD=${2:-"postgres-0"}
DB_USER="sherlock"
DB_PASSWORD="sherlock-password"
DB_NAME="sherlock_db"

echo -e "${YELLOW}Initializing PostgreSQL database...${NC}"

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=300s || true

# Run initialization SQL
INIT_SQL="
-- Create extensions
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create logs table
CREATE TABLE IF NOT EXISTS logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    message TEXT NOT NULL,
    level VARCHAR(10),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_logs_user_id ON logs(user_id);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_logs_level ON logs(level);

-- Insert sample data
INSERT INTO users (username, email) VALUES ('admin', 'admin@example.com') ON CONFLICT DO NOTHING;
INSERT INTO users (username, email) VALUES ('testuser', 'test@example.com') ON CONFLICT DO NOTHING;

SELECT COUNT(*) as user_count FROM users;
"

echo -e "${YELLOW}Applying schema...${NC}"
kubectl exec -i "$DB_POD" -n "$NAMESPACE" -- psql -U "$DB_USER" -d "$DB_NAME" <<< "$INIT_SQL" || echo -e "${RED}Warning: Schema application had issues${NC}"

echo -e "${GREEN}✓ Database initialization complete!${NC}"
