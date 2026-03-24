-- Script de inicialização dos databases para cada microsserviço
-- Este script será executado automaticamente quando o container do PostgreSQL subir pela primeira vez

-- Database para o microsserviço de Usuários
CREATE DATABASE postech_users;

-- Database para o microsserviço de Catálogo
CREATE DATABASE postech_catalog;

-- Database para o microsserviço de Pagamentos
CREATE DATABASE postech_payments;

-- Database para o microsserviço de Notificações
CREATE DATABASE postech_notifications;

-- Garantir permissões (usuário padrão do compose alinhado ao .env.example: postgres)
GRANT ALL PRIVILEGES ON DATABASE postech_users TO postgres;
GRANT ALL PRIVILEGES ON DATABASE postech_catalog TO postgres;
GRANT ALL PRIVILEGES ON DATABASE postech_payments TO postgres;
GRANT ALL PRIVILEGES ON DATABASE postech_notifications TO postgres;