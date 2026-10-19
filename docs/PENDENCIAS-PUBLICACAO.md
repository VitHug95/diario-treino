# Pendências do projeto

O que ainda falta no Diário de Treino, consolidado do [BACKLOG](BACKLOG.md),
[MAS](MAS.md) e [MER](MER.md). A publicação (PBI-04) está **concluída**: API no
Fly, front no Cloudflare, banco no Neon, com deploy automático a cada merge na
`main` (ver [DEPLOY-AUTOMATICO.md](DEPLOY-AUTOMATICO.md)).

Data: 19/10/2026. Última entrega: correções de uso real PBI-73 a 80.

---

## Incremento 1 (MVP) — em finalização

Falta fechar:

- **PBI-26 — E2E Robot completo.** Hoje o fluxo é coberto por teste em
  `flutter test`; o E2E com a Browser Library está quebrado e será reconciliado
  manualmente, aplicando as correções de bug depois dos testes manuais.
- **PBI-24 — Conferência final de contraste.** Tema claro e escuro já existem e
  persistem; falta a checagem final de 4,5:1 em cada componente nos dois temas.
  Validação completa exige teste manual com tecnologia assistiva.

## Melhorias e decisões em aberto com o PO

- **PBI-34 — Trocar a métrica no registro.** Escolher outra métrica (ex.: tempo
  no lugar de reps) na hora de registrar.
- **PBI-35 — Cronograma semanal.** Planejar quais fichas em quais dias.
- **PBI-75 — Aviso "Ficha criada" como pop menor.** Hoje o aviso é maior do que
  o PO quer.
- **PBI-73 (decisão pendente)** — exercício só de repetições no gráfico: está
  implementada a **melhor série** (maior nº de repetições da sessão). O PO ainda
  pode preferir o total de repetições da sessão.
- Série adicionada copiando a anterior; "Treino salvo" com ou sem "Ver treino".

## Dados antigos a observar (não bloqueiam)

- **Exercício repetido (PBI-74).** A unicidade por ficha e por sessão vive na
  aplicação, sem constraint no banco. Fichas ou sessões criadas antes da regra
  podem ter repetição; elas continuam abrindo normalmente, só não é possível
  criar novos casos.

## Modo educador e incremento 2 — não iniciados

- **Modo educador (PBI-48, épico E7).** O banco já conhece educador, vínculo e
  autoria de plano; falta a camada de telas e os endpoints de aluno/vínculo.
- **Incremento 2 — Cardio (PBI-27 a 30).** Registro por zonas e resumo do
  período por zona. Modelo de dados preparado (duas métricas por série), telas e
  consultas ainda não feitas.

## Operação (herdado da publicação)

- **Backup do banco (PBI-05): concluído.** Backup semanal no CI, secret
  configurado e restauração testada em 19/10/2026. Ver
  [BACKUP-RESTAURACAO.md](BACKUP-RESTAURACAO.md).
- Domínio próprio (hoje usa os subdomínios grátis `*.fly.dev` /
  `*.workers.dev`).
- Resetar a senha do role do Neon (foi digitada em texto no chat durante o
  setup inicial).
- Ruído de log cosmético na API (`libgssapi_krb5.so.2`), não afeta a conexão.
