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
- Gráfico de desempenho por exercício (evolução de carga)
- Quantidade de treinos realizados no período
- Clique em um ponto do gráfico abre a observação daquele dia
- Filtro com atalhos (últimos 10, 15 e 30 dias) e período livre, desde o cadastro até hoje

**Acesso**
- Login simples; cada usuário monta o próprio treino

**Modo educador físico (futuro)**
- O educador cadastra seus alunos (vínculo educador x aluno)
- Tem acesso ao treino e ao progresso de cada aluno vinculado
- Pode exportar os dados do aluno em PDF

## Incrementos

**Incremento 1 (MVP)**
- Login
- Cadastro de fichas A/B/C com exercícios
- Registro da sessão com carga pré-preenchida e observação
- Gráfico de carga por exercício com filtro de período

**Incremento 2**
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

- [docs/MAS.md](docs/MAS.md): arquitetura, decisões (ADRs), autenticação, contrato da API, implantação e testes
- [docs/MER.md](docs/MER.md): modelo de dados completo, dicionário, índices e regras

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
- **Identidade no Firebase, autorização no nosso banco.** O token diz quem é a pessoa; o Postgres diz o que ela pode fazer.
- **Autorização centralizada em uma regra só:** pode ver dados do atleta quem for o próprio atleta ou educador com vínculo ativo. Todo endpoint passa por ela, inclusive a exportação em PDF.
- **PDF é uma visão dos mesmos dados da tela de progresso**, gerado a partir da mesma consulta, para o relatório nunca divergir do que aparece no app.

## Stack e infraestrutura

- Front: Flutter (mesma base para web e, depois, Android/iOS). Começa como web.
- Back: API em .NET 10, monólito em camadas, EF Core + Npgsql
- Banco: PostgreSQL no Neon (plano gratuito), com `pg_dump` semanal guardado fora
- Login: Firebase Authentication (e-mail/senha e Google); papéis e vínculos ficam no Postgres
- Hospedagem da API: Docker na mesma VPS do bot de WhatsApp, atrás do Caddy (HTTPS automático)
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
