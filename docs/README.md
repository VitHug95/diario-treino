# App de Treino

Aplicação para registrar treinos e acompanhar a evolução ao longo do tempo. Nasce para uso pessoal (Vitor e parceiro educador físico), com estrutura preparada para, no futuro, um educador físico montar treinos para os seus alunos.

## Visão

O registro pode ser feito depois do treino: a pessoa anota na academia e alimenta o app quando tiver tempo. O valor está no feedback: filtrar um período, olhar o gráfico de evolução, identificar um ponto fora da curva e clicar para ler a observação daquele dia.

O parceiro não quer usar o app como personal. O uso inicial é pessoal, com a porta aberta para mostrar a outras pessoas e, se fizer sentido, virar produto.

## Requisitos levantados

**Registro de treino de musculação**
- Treinos organizados por ficha (A, B, C), cada uma com seus exercícios
- Por exercício: carga, repetições e tempo de descanso, registrados por série
- Duração total do treino
- Campo de observação do dia (ex.: "comi mal", "tava doente", "troquei a ordem dos exercícios")
- Ao registrar uma ficha, a carga vem preenchida com a última usada naquele exercício, editável

**Registro de cardio**
- Registro por tempo (ex.: 50 minutos)
- Observação sobre o modelo do treino: intervalado, contínuo, intensidade

**Acompanhamento**
- Gráfico de desempenho por exercício (evolução de carga; sem carga, de repetições)
- Quantidade de treinos realizados no período
- Clique em um ponto do gráfico abre a observação daquele dia
- Filtro com atalhos (últimos 10, 15 e 30 dias) e período livre, desde o cadastro até hoje

**Acesso**
- Login simples; cada usuário monta o próprio treino

**Modo educador físico (futuro)**
- O educador cadastra seus alunos (vínculo educador x aluno)
- Tem acesso ao treino e ao progresso de cada aluno vinculado
- Pode exportar os dados do aluno em PDF

## Estado atual (21/10/2026)

O app está **publicado e em uso** (API no Fly, front no Cloudflare, banco no Neon), com deploy automático a cada merge na `main`. O **Incremento 1 (MVP) está completo**: login, catálogo com 89 exercícios filtrado por membro, vários planos com um em uso, fichas com alvos, registro de sessão (editar, excluir, exercício fora da ficha, "Manter na ficha?"), treino livre, primeiro acesso, treino ao vivo série por série, tela inicial com semana, último treino e dicas, progresso completo, perfil com tema e exclusão de conta, e o **E2E do fluxo principal (PBI-26)**. De 16 a 19/10 entraram as correções de uso real (PBI-73 a 80): plano novo nasce em uso, um exercício por ficha e por sessão, editor de alvos e resumo da ficha, gráfico de exercício sem carga, "Manter na ficha?" avisando quando não lê a ficha e tocar numa aba abrindo a raiz dela. Também entrou o calendário do mês (PBI-82): a partir do cartão "Esta semana", o atleta abre o mês inteiro, navega de mês em mês e toca num dia para ver ou registrar o treino.

**Incremento 1 completo**, incluindo o E2E do fluxo principal (PBI-26, `integration_test` via `flutter drive` + ChromeDriver contra a stack real). Backup do banco (PBI-05, `pg_dump` semanal no CI guardado fora do Neon, restauração testada — ver [BACKUP-RESTAURACAO.md](BACKUP-RESTAURACAO.md)) e contraste 4,5:1 nos dois temas (PBI-24, auditado e travado por teste) também concluídos. Em aberto, como melhorias: troca de métrica no registro (PBI-34), cronograma semanal (PBI-35), pop menor no aviso "Ficha criada" (PBI-75), "Manter na ficha?" por exercício (PBI-81) e o modo educador (PBI-48, épico E7). O **Incremento 2** (cardio e resumo do período) ainda não começou.

O status detalhado por PBI está no [BACKLOG.md](BACKLOG.md); a arquitetura e o modelo de dados, no [MAS.md](MAS.md) e [MER.md](MER.md).

## Incrementos

**Incremento 1 (MVP)** — completo
- Login ✅
- Cadastro de fichas A/B/C com exercícios ✅
- Registro da sessão com carga pré-preenchida e observação ✅
- Gráfico de carga por exercício com filtro de período ✅
- Backup semanal do banco ✅ (restauração testada)
- Contraste 4,5:1 nos dois temas ✅ (auditado e travado por teste)
- E2E do fluxo principal ✅ (PBI-26, `integration_test` contra a stack real)

**Incremento 2** — não iniciado
- Registro de cardio
- Contagem de treinos no período

**Futuro**
- Modo educador físico: montar treinos para alunos, acompanhar treino e progresso deles e exportar em PDF
- Modo corrida por zonas (detalhado abaixo)
- Importação de treinos do relógio ou do Strava (arquivo exportado)

## Modo corrida por zonas (incremento futuro)

Levantado pelo Vinicius a partir de como as assessorias de corrida passam treino: por zona, com tiros e recuperação (ex.: 5 tiros em Z4 com 1:30 de descanso em Z2).

**Representação**
- Todo treino de corrida é uma lista de trechos, cada um com zona e duração (tempo ou distância)
- Intervalado: Z4 · 90 s, Z2 · 1:30, repetido 5 vezes
- Contínuo: Z4 · 5 km
- Execução que fugiu do plano: Z4 · 5 min, Z3 · 5 min...
- Na tela, treino intervalado aparece em pares, como a assessoria escreve: série | zona | tempo | descanso | zona do descanso
- No banco, tudo é guardado como trechos, para atender também o caso contínuo e o caso em que a zona muda no meio

**Preenchimento**
- Treino pode ser criado previamente (ficha) ou montado na hora, adicionando trechos no próprio dia
- Quando existe plano, ele só pré-preenche a tela; a pessoa edita, apaga ou adiciona trechos e o plano fica intacto para comparação
- Campo de observação, como nos demais treinos

**Feedback**
- Comparação por tempo total em cada zona, não linha a linha, porque plano e execução podem ter estruturas diferentes
- Ex.: planejado 25 min em Z4; executado 20 min em Z4 e 5 min em Z3
- Gráfico de barras empilhadas por zona e percentual de aderência ao plano

**Riscos e dependências**
- Preenchimento manual dias depois é aproximado: ninguém lembra em que minuto mudou de zona. A precisão vem do relógio, por isso a importação de arquivo é o passo natural depois deste modo
- Depende da definição de zona (frequência cardíaca, pace ou percepção de esforço), que decide se o tempo em zona pode ser calculado automaticamente

## Documentação técnica

- [MAS.md](MAS.md): arquitetura, decisões (ADRs), autenticação, contrato da API, implantação e testes
- [MER.md](MER.md): modelo de dados completo, dicionário, índices e regras
- [DESIGN.md](DESIGN.md): fontes, cores dos temas claro e escuro, espaçamentos, raios e tamanhos
- [BACKLOG.md](BACKLOG.md): Product Goal, DoR, DoD, PBIs com critérios de aceite e status
- [ESTADO-DO-PROJETO.md](ESTADO-DO-PROJETO.md): snapshot detalhado do que existe (telas, endpoints, banco, CI)
- [HISTORICO-DE-ALTERACOES.md](HISTORICO-DE-ALTERACOES.md): tudo que entrou na `main`, PR por PR, com as migrations
- [PENDENCIAS-PUBLICACAO.md](PENDENCIAS-PUBLICACAO.md): o que ainda falta (cardio, modo educador)
- [DEPLOY-AUTOMATICO.md](DEPLOY-AUTOMATICO.md): como funciona o deploy automático no CI
- [BACKUP-RESTAURACAO.md](BACKUP-RESTAURACAO.md): backup semanal do banco e como restaurar (PBI-05)

O modelo de dados oficial é o do MER. Este README guarda a visão de produto e as decisões em alto nível.

## Decisões de arquitetura

- **Estrutura preparada, funcionalidade depois.** O banco já conhece atleta e educador, mas o MVP só tem telas de atleta.
- **Papel em tabela separada**, não coluna única, porque uma mesma pessoa pode ser educador e atleta ao mesmo tempo.
- **Plano com `AutorId` e `AtletaId` separados.** No MVP os dois apontam para a mesma pessoa. Quando o educador entrar, ele passa a ser o autor.
- **Prescrito separado do executado.** `TreinoExercicio` guarda o planejado, `SerieExecutada` guarda o realizado. Isso permite, no futuro, o educador comparar planejado x realizado.
- **Registro por série, não por exercício**, para o gráfico de evolução refletir a realidade.
- **Toda série tem dois eixos: intensidade e volume** (proposta do Vinicius: "carga ou zona" e "repetições ou tempo"). Supino = 40 kg × 10 reps; prancha isométrica = peso corporal × 45 s; tiro de corrida = zona 4 × 90 s. Um modelo só cobre academia, isometria, corrida e reabilitação.
- **Intervalado é etapa com rodadas.** O educador prescreve uma vez (zona 4 por 90 s + zona 2 por 5 min de recuperação, 3 rodadas) e o registro já abre expandido com as 3 rodadas preenchidas. O atleta só corrige o que fugiu do plano.
- **Métrica é escolhida de uma lista, não digitada livre**, para o gráfico conseguir agrupar e comparar valores ao longo do tempo.
- **Feedback depende do tipo de exercício.** Carga: evolução de carga com reps. Isometria: tempo sustentado na mesma intensidade. Intervalado: rodadas cumpridas e tempo mantido na zona-alvo. Zona sozinha não mostra evolução, porque é relativa à pessoa.
- **Tema claro e escuro (layouts A e B aprovados).** Segue o sistema por padrão, com botão de troca na tela inicial e opção em Perfil.
- **Exercícios filtrados por membro (ADR-10).** Membro obrigatório de lista fixa (Peito, Costas, Ombros, Braços, Pernas, Core, Cardio, Mobilidade) e músculo opcional. A modalidade continua definindo como o exercício é medido, mas deixa de ser filtro.
- **Um exercício por ficha e por sessão (PBI-74).** O seletor mostra quem já está presente como indisponível e a API recusa a repetição (409 na ficha, 400 na sessão).
- **O gráfico escolhe a grandeza por exercício (PBI-73).** Com carga, evolui a carga; sem carga (peso corporal), evolui as repetições; isometria, o tempo.
- **Plano novo nasce em uso quando não há plano em uso (PBI-77).** Planos escondidos por terem histórico não contam.
- **Tocar numa aba abre a raiz dela (ADR-11, PBI-80).**
- **Identidade no Firebase, autorização no nosso banco.** O token diz quem é a pessoa; o Postgres diz o que ela pode fazer.
- **Autorização centralizada em uma regra só:** pode ver dados do atleta quem for o próprio atleta ou educador com vínculo ativo. Todo endpoint passa por ela, inclusive a exportação em PDF.
- **PDF é uma visão dos mesmos dados da tela de progresso**, gerado a partir da mesma consulta, para o relatório nunca divergir do que aparece no app.

## Stack e infraestrutura

- Front: Flutter (mesma base para web e, depois, Android/iOS). Começa como web.
- Back: API em .NET 10, monólito em camadas, EF Core + Npgsql
- Banco: PostgreSQL no Neon (plano gratuito), com `pg_dump` semanal guardado fora
- Login: Firebase Authentication (e-mail/senha e Google); papéis e vínculos ficam no Postgres
- Hospedagem final: máquina própria com Docker e Caddy (HTTPS automático) e domínio próprio
- Hospedagem na fase de testes (provisória): API no Fly.io e front no Cloudflare (Workers Static Assets), sem dependência desses serviços no código (ADR-09)
- Desenvolvimento assistido pelo Kiro

## Custos levantados na conversa

- Domínio: em torno de R$ 50 por ano
- Teto combinado: até uns R$ 30 por mês, dividido entre os dois
- Publicar na Google Play tem custo baixo; na Apple Store o custo anual é bem maior e o processo de aprovação é mais exigente. Só vale a pena se for vender.

## Pontos de atenção

- **LGPD:** o campo de observação pode conter dado de saúde (ex.: "senti dor no joelho"). Para uso pessoal, tranquilo. Quando houver alunos de terceiros e cobrança, vai precisar de termo de consentimento e de uma hospedagem adequada para esses dados. O consentimento precisa cobrir o acesso do educador e a exportação em PDF, já que o arquivo sai do app.
- **Não inchar o MVP:** o modo educador fica só no modelo de dados até o MVP estar em uso.

## Perguntas em aberto

- O PDF do aluno traz o quê? Período filtrado, gráficos, lista de sessões, observações?
- O aluno pode marcar uma observação como privada, para o educador não ver?
- Quando o vínculo com o educador termina, ele perde o acesso ao histórico do aluno?
- Zona é definida por frequência cardíaca, por pace ou por percepção de esforço? Vale guardar as faixas de cada atleta?
- Intervalado com sobra de rodada (fez 4 em vez de 3) ou rodada incompleta: como mostrar no feedback?

## Ideias para depois

- Modo educador físico com cadastro de alunos e vínculo
- Possibilidade de vender e dividir a receita
- Ideia antiga do Vitor: app para pessoa comum com IA, objetivo (emagrecimento, ganho de peso), cálculo de taxa metabólica basal e sugestão de treino e dieta, com aviso para procurar profissional em caso de problema de saúde

## Backlog de novas ideias

<!-- Adicione aqui as próximas ideias -->
