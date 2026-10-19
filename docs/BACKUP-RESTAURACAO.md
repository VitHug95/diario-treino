# Backup e restauração do banco (PBI-05)

O banco de produção fica no **Neon** (Postgres 18; o banco é `neondb`, role
`neondb_owner`). Um backup semanal automático
roda no GitHub Actions e guarda o dump **fora do Neon**, como artifact do próprio
Actions. Este documento explica como funciona, como configurar uma vez e como
restaurar — com um teste de restauração que deve ser feito antes do lançamento.

## Como funciona

- Workflow: [`.github/workflows/backup.yml`](../.github/workflows/backup.yml).
- Agenda: **toda segunda-feira às 06:00 UTC** (03:00 em Brasília). Também dá para
  rodar sob demanda em **Actions → Backup do banco (Neon) → Run workflow**.
- Faz `pg_dump --format=custom` (arquivo `.dump` comprimido e restaurável
  seletivamente) do banco apontado por `NEON_DATABASE_URL`.
- Sobe o dump como **artifact** com **retenção de 63 dias**. Com a cadência
  semanal, isso mantém sempre **pelo menos 8 cópias** (≈ 9 semanas de folga),
  atendendo o critério da PBI-05.
- O artifact vive na infraestrutura do GitHub — **fora do Neon e fora da VPS**.

## Configuração (uma vez)

Criar o secret com a connection string do Neon no repositório:

1. No Neon, copie a connection string do banco de produção (Dashboard → Connection
   Details). O valor **precisa começar com `postgresql://`** (ou `postgres://`),
   no formato:
   `postgresql://neondb_owner:SENHA@HOST/neondb?sslmode=require`
   - Cole **só a URL**, sem `psql `, sem aspas em volta e sem quebra de linha. Se
     o Neon mostrar algo como `psql 'postgresql://...'`, copie apenas a parte
     entre aspas. O workflow recusa (com erro claro) um valor que não comece com
     `postgresql://`, justamente para evitar o `pg_dump` cair no socket local.
2. No GitHub: repo → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**.
   - Name: `NEON_DATABASE_URL`
   - Secret: cole a connection string do passo 1.
3. Pronto. No próximo agendamento (ou via **Run workflow**) o backup roda.

> O secret é a credencial do banco de produção. Fica **só** no secret do GitHub,
> nunca no código. Se vazar, troque a senha do role no Neon e atualize o secret.

## Baixar um backup

**Actions → Backup do banco (Neon)** → abra a execução desejada → seção
**Artifacts** → baixe o `.dump` (o nome tem a data/hora UTC, ex.:
`diariotreino-20261019-060012.dump`).

## Restaurar

Pré-requisito: `pg_restore` **18+** (mesma major do servidor de origem, o Neon
roda Postgres 18). Confira com `pg_restore --version`.

### Restaurar num banco novo (recomendado para testar)

Sobe um Postgres local com Docker, cria um banco limpo e restaura o dump nele —
sem tocar na produção.

```bash
# 1. Postgres local (porta 5432)
docker run --name pg-restore-teste -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:18-alpine

# 2. Cria um banco de destino vazio
docker exec -e PGPASSWORD=postgres pg-restore-teste psql -U postgres -c "CREATE DATABASE diariotreino_restore;"

# 3. Restaura o dump baixado (ajuste o caminho do arquivo)
pg_restore --no-owner --no-privileges --verbose \
  --dbname="postgresql://postgres:postgres@localhost:5432/diariotreino_restore" \
  ./diariotreino-AAAAMMDD-HHMMSS.dump

# 4. Confere que os dados vieram
docker exec -e PGPASSWORD=postgres pg-restore-teste \
  psql -U postgres -d diariotreino_restore \
  -c "SELECT count(*) AS usuarios FROM usuario; SELECT count(*) AS sessoes FROM sessao;"

# 5. Limpa o container de teste
docker rm -f pg-restore-teste
```

`--no-owner --no-privileges` ignora dono/grants do Neon (o role de destino é
diferente). Em `--format=custom`, o `pg_restore` recria tabelas, índices,
constraints e dados.

### Restaurar sobre o Neon (recuperação real, cuidado)

Só em caso de perda. É destrutivo: sobrescreve o banco.

1. De preferência, restaure num **branch do Neon** ou num banco novo e promova
   depois, em vez de escrever direto no banco vivo.
2. Com o banco de destino vazio:
   ```bash
   pg_restore --no-owner --no-privileges --verbose \
     --dbname="postgresql://USUARIO:SENHA@HOST/DESTINO?sslmode=require" \
     ./diariotreino-AAAAMMDD-HHMMSS.dump
   ```
3. Suba a API apontando para o banco restaurado e valide o fluxo (login →
   plano → registrar treino → progresso).

## Teste de restauração antes do lançamento (critério da PBI-05)

Fazer **uma vez**, e repetir se o schema mudar muito:

1. Rode o workflow sob demanda (**Run workflow**) para gerar um dump atual.
2. Baixe o `.dump`.
3. Siga "Restaurar num banco novo" acima (passos 1 a 5).
4. Confirme que `usuario` e `sessao` têm as contagens esperadas e que uma
   consulta de progresso devolve dados.
5. Anote aqui a data do teste e o resultado.

| Data do teste | Dump usado | Resultado |
|---|---|---|
| _(preencher)_ | _(arquivo)_ | _(ok / ajustes)_ |

## Limitações e evolução

- Artifact tem retenção por tempo (63 dias). Para guarda longa (anos) ou
  imutável, migrar o destino para um bucket (Cloudflare R2 / S3) num passo extra
  do mesmo workflow — o `pg_dump` não muda, só o "onde guardar".
- O backup cobre o banco. O Firebase (identidade) tem o próprio backup do Google.
