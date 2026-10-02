# Diário de Treino — convenções do projeto

App para registrar treinos (inclusive dias depois) e acompanhar a evolução por
exercício. Uso pessoal primeiro, com estrutura pronta para o modo educador.
Documentos de referência: [README](../../README.md), [MAS](../../docs/MAS.md),
[MER](../../docs/MER.md), [BACKLOG](../../BACKLOG.md).

## Estrutura do repositório

```
backend/   solução .NET (src/, tests/, e2e/)
app/       app Flutter
docs/      MAS.md, MER.md
.github/   workflows de CI/CD
```

## Back-end (.NET 10)

- Namespace raiz: `DiarioTreino`.
- Monólito em camadas. Regra de dependência (MAS 9.1):
  `Api → Application → Domain` e `Infrastructure → Application`.
  O domínio não conhece EF Core, Firebase nem HTTP.
- Projetos: `DiarioTreino.Domain`, `.Application`, `.Infrastructure`, `.Api`,
  `DiarioTreino.UnitTests`, `DiarioTreino.IntegrationTests`.
- Minimal APIs, prefixo `/api/v1`. Erros em Problem Details (RFC 9457).
- Validação de entrada com FluentValidation.
- Logs com Serilog, estruturados, com identificador de correlação por
  requisição. Logs nunca registram token nem o texto de observação da sessão.
- ORM: EF Core + Npgsql. Migrations versionadas no repositório.
- Testes: xUnit; integração com Testcontainers (Postgres real) e
  WebApplicationFactory.

## Autorização (MAS 11.3) — regra única

Toda leitura/escrita de dados de atleta passa pelo serviço `IControleAcesso`:
pode acessar quem for o próprio atleta OU educador com vínculo ATIVO. Nunca
reescrever essa regra dentro de endpoint. Recurso de outro usuário responde
**404, não 403**. Todo endpoint novo que lê/grava dado de atleta precisa de
teste do caso "outro usuário" (404).

## Front-end (Flutter)

- Organização feature-first: `core/`, `features/`, `shared/`, `theme/` (MAS 10).
- Estado: Riverpod. Navegação: go_router. HTTP: Dio com interceptor que anexa o
  ID token do Firebase. Login: firebase_auth. Gráficos: fl_chart.
- Acessibilidade: habilitar a árvore de semântica no build web
  (`SemanticsBinding.instance.ensureSemantics()`); todo campo e botão com rótulo.

## Identidade e dados

- Identidade no Firebase (token), autorização no nosso Postgres. Custom claims
  do Firebase não são usadas para regra de negócio.
- O modelo de dados oficial é o do MER. Qualquer mudança de banco gera migration
  que aplica do zero sem erro.

## Definition of Done (resumo do BACKLOG 4)

Código revisado e integrado na `main`; CI verde (build + testes unitários e de
integração); migration quando houver mudança de banco; endpoints novos passam
pela regra de acesso e têm teste do caso 404; telas conferidas nos dois temas
com rótulo de acessibilidade; MAS/MER atualizados se alguma decisão mudou.
