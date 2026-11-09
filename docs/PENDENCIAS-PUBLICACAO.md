# Pendências do projeto

O que ainda falta no Diário de Treino, consolidado do [BACKLOG](BACKLOG.md),
[MAS](MAS.md) e [MER](MER.md). A publicação (PBI-04) está **concluída**: API no
Fly, front no Cloudflare, banco no Neon, com deploy automático a cada merge na
`main` (ver [DEPLOY-AUTOMATICO.md](DEPLOY-AUTOMATICO.md)).

Data: 05/11/2026. Última entrega: PBI-35, semana planejada (PR #135). O Incremento 1
(modo atleta) e o modo educador (E7) estão entregues.

---

## Incremento 1 (MVP) — entregue

O E2E do fluxo principal (PBI-26), o backup (PBI-05) e o contraste (PBI-24) foram
concluídos. A validação final de acessibilidade com tecnologia assistiva (leitor de
tela) continua sendo um passo manual recomendado antes do lançamento.

## Melhorias e decisões em aberto com o PO

- **PBI-34 — Trocar a métrica no registro.** Bloqueada: (a) por série no registro
  (flexível, o gráfico agrupa por métrica) ou (b) no alvo da ficha (previsível, com
  mudança de banco). Recomendação: (a).
- **PBI-73 (decisão pendente)** — exercício só de repetições no gráfico: está
  implementada a **melhor série**; o PO ainda pode preferir o total de repetições.
- **E12 · Corpo e medidas (PBI-91 a 96).** Medidas prontas no back (PBI-91) e no app (PBI-92). Faltam dados corporais/TMB e gráfico; o compartilhamento com o educador espera as respostas do PO (todos os educadores ou por educador; educador vê dados corporais ou só medidas; PDF com medidas; lista de 12 medidas).
- **Termo de consentimento (PBI-87).** O texto atual é provisório; falta o texto
  jurídico antes de abrir ao público.
- (Decididos: série adicionada copia a anterior — PBI-84 revertida; "Treino salvo"
  é só a pílula; semana do plano — PBI-35 entregue.)
## Dados antigos a observar (não bloqueiam)

- **Exercício repetido (PBI-74).** A unicidade por ficha e por sessão vive na
  aplicação, sem constraint no banco. Fichas ou sessões criadas antes da regra
  podem ter repetição; elas continuam abrindo normalmente, só não é possível
  criar novos casos.

## Próximos épicos e incremento 2 — não iniciados

- **Incremento 2 — Cardio (PBI-27 a 30).** Registro por zonas e resumo do período
  por zona. Falta a resposta do Vinicius sobre como a zona é definida (FC, pace ou
  percepção). Modelo de dados preparado (duas métricas por série).
- **E8 a E11.** Ver [BACKLOG](BACKLOG.md), seção 9. Inclui a publicação na Google
  Play (E10).
## Operação (herdado da publicação)

- **Backup do banco (PBI-05): concluído.** Backup semanal no CI, secret
  configurado e restauração testada em 19/10/2026. Ver
  [BACKUP-RESTAURACAO.md](BACKUP-RESTAURACAO.md).
- Domínio próprio (hoje usa os subdomínios grátis `*.fly.dev` /
  `*.workers.dev`).
- Resetar a senha do role do Neon (foi digitada em texto no chat durante o
  setup inicial).
- Ruído de log cosmético na API (`libgssapi_krb5.so.2`), não afeta a conexão.
- Confirmar que o `deploy-web` segue verde com o Wrangler v4 (#121).
