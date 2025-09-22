-- PostgreSQL initialization script

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Note: Tables and indexes are not created here as they are handled by the application
-- They will be created by the setup method in src/config/database.cr when the application starts
