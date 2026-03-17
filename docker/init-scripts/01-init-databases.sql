-- Script de inicialização dos databases para cada microsserviço
-- Este script será executado automaticamente quando o container do PostgreSQL subir pela primeira vez

-- Database para o microsserviço de Usuários
CREATE DATABASE postech_users;

-- Database para o microsserviço de Catálogo
CREATE DATABASE postech_catalog;

-- Garantir permissões
GRANT ALL PRIVILEGES ON DATABASE postech_users TO postech_admin;
GRANT ALL PRIVILEGES ON DATABASE postech_catalog TO postech_admin;
GRANT ALL PRIVILEGES ON DATABASE postech_payments TO postech_admin;
GRANT ALL PRIVILEGES ON DATABASE postech_notifications TO postech_admin;