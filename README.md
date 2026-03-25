# postech-orchestration

Orquestracao de ambiente para o projeto FIAP Cloud Games.

Este repositorio concentra os recursos para executar o ecossistema em tres modos:

- Infra local com Docker (`docker/`)
- Deploy em cluster Kubernetes (`k8s/`)
- Stack local k8s-like completa com Docker Compose (`temp/`)

## Dependencias gerais

- Docker Desktop (ou Docker Engine + Compose)
- kubectl
- Cluster Kubernetes acessivel (Minikube, Kind, Docker Desktop Kubernetes ou cluster remoto)
- envsubst (gettext)
- Bash

## Estrutura

```text
postech-orchestration/
  docker/   # Infra local: PostgreSQL + RabbitMQ
  k8s/      # Manifests e scripts de deploy Kubernetes
  temp/     # Stack completa k8s-like em Docker Compose
```

## Fluxos recomendados

## 1) Infra local para desenvolvimento de APIs

Use quando as APIs rodam localmente na sua maquina e voce so precisa de banco e broker.

```bash
cd docker
bash scripts/start.sh
```

Documentacao detalhada: `docker/README.md`.

## 2) Deploy no Kubernetes

Use quando quer validar o ambiente no cluster com manifests.

```bash
cd k8s/scripts
bash start.sh
```

O script realiza deploy e abre port-forwards locais das APIs.

Documentacao detalhada: `k8s/README.md`.

## 3) Ambiente completo local (k8s-like)

Use quando quer rodar toda a stack localmente via Compose.

```bash
cd temp
docker compose up -d
```

Documentacao detalhada: `temp/README.md`.

## Exemplo completo com Docker + Kubernetes + kubectl

```bash
# 1) Rebuild das imagens dos microsservicos (fluxo k8s)
cd k8s/scripts
bash rebuild-images.sh

# 2) Push para o registry
# (ajuste DOCKER_USER e IMAGE_TAG em k8s/env.sh)
docker push ${DOCKER_USER}/users-api:${IMAGE_TAG}
docker push ${DOCKER_USER}/catalog-api:${IMAGE_TAG}
docker push ${DOCKER_USER}/payments-api:${IMAGE_TAG}
docker push ${DOCKER_USER}/notifications-api:${IMAGE_TAG}

# 3) Deploy no cluster
bash start.sh

# 4) Verificacao via kubectl
# Para listar pods em execucao, sempre especifique o namespace com -n
kubectl get ns
kubectl get pods -n infrastructure
kubectl get pods -n gamestore
kubectl get svc -n gamestore

# 5) Logs
kubectl logs -n gamestore deploy/users-api -f
```

## Observacoes

- Os manifests Kubernetes usam imagens no formato `${DOCKER_USER}/<service>:${IMAGE_TAG}`.
- O arquivo `k8s/env.sh` e a principal configuracao para imagem/tag e host de acesso.
- Para limpar port-forwards iniciados pelo `k8s/scripts/start.sh`, execute:

```bash
cd k8s/scripts
bash stop-port-forward.sh
```
