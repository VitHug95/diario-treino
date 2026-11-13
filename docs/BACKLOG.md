# Product Backlog

**Projeto:** Diário de Treino (nome provisório)
**Versão:** 1.0, atualizada em 05/11/2026 (até o PR #135)
**Documentos relacionados:** [MAS.md](MAS.md), [MER.md](MER.md), [README.md](../README.md), protótipo no canvas "Telas App de Treino"

---

## 1. Product Goal

> O atleta registra o treino quando puder e entende a própria evolução sem perder o motivo de cada dia fora da curva.

O incremento 1 entrega isso para o modo atleta (musculação e isometria). O incremento 2 acrescenta cardio. O modo educador já foi entregue (E7), sobre a estrutura que nasceu pronta.

## 2. Papéis

| Papel | Quem |
|---|---|
| Product Owner | Vinicius: ordena o backlog e aceita os incrementos |
| Developers | Vitor (e quem mais entrar), com apoio do Kiro |
| Scrum Master | Vitor acumula; vale combinar quem facilita os eventos quando ele estiver codando |

## 3. Definition of Ready

Uma PBI só entra na Sprint Planning quando:

- tem história no formato "Como... quero... para..." e valor claro para o PO;
- tem critérios de aceite verificáveis;
- as dependências estão prontas ou entram na mesma Sprint;
- não tem pergunta em aberto que bloqueie (seção 10);
- os Developers estimaram e acham que cabe numa Sprint.

## 4. Definition of Done

Vale para toda PBI, além dos critérios de aceite dela:

- código revisado e integrado na `main`;
- CI verde: build, testes unitários e de integração;
- migration criada quando houver mudança de banco, aplicando sem erro do zero;
- endpoints novos passam pela regra de controle de acesso (MAS, seção 11.3) e têm teste do caso "outro usuário" (404);
- telas novas conferidas nos temas claro e escuro, com rótulo de acessibilidade em todo campo e botão;
- publicado no ambiente de produção;
- MAS ou MER atualizados se alguma decisão mudou.

## 5. Convenções deste backlog

- **ID:** `PBI-nn`, fixo para sempre, mesmo que a ordem mude.
- **Ordem:** a lista está na ordem sugerida de execução. Quem decide a ordem final é o PO.
- **Estimativa:** fica em branco de propósito. Quem estima são os Developers, no refinamento.
- **Referências:** "API" aponta para a tabela de endpoints do MAS (seção 12); "Tabelas" aponta para o MER.
- **Kiro:** cada PBI vira uma spec. A história e os critérios de aceite vão no `requirements.md`; as notas técnicas ajudam o `design.md`.

---

## 6. Incremento 1: MVP modo atleta

### Épico E0: Fundação

#### PBI-01 · Estrutura da solução back-end
**História:** Como desenvolvedor, quero a solução .NET organizada em camadas e com testes rodando no CI, para que toda PBI seguinte já nasça no lugar certo.

**Critérios de aceite**
- Solução com os projetos `Domain`, `Application`, `Infrastructure`, `Api`, `UnitTests` e `IntegrationTests`, respeitando a regra de dependência do MAS (9.1).
- `GET /health` responde 200.
- OpenAPI disponível em ambiente local.
- Logs estruturados com Serilog e identificador de correlação por requisição.
- Pipeline do GitHub Actions roda build e testes a cada push e bloqueia merge com falha.

**Notas técnicas:** .NET 10, Minimal APIs, FluentValidation, Problem Details para erros.
**Depende de:** nada.

#### PBI-02 · Estrutura do app Flutter
**História:** Como desenvolvedor, quero o app Flutter estruturado por funcionalidade e com os dois temas prontos, para que as telas sejam construídas sem retrabalho de estrutura ou de cor.

**Critérios de aceite**
- Estrutura `core / features / shared / theme` conforme MAS (seção 10).
- Riverpod, go_router e Dio configurados; o Dio tem interceptor preparado para anexar token.
- Temas claro e escuro definidos por tokens (`ThemeData` + `ThemeExtension`), com as cores das opções A e B do protótipo.
- Nenhuma cor escrita direto em widget (regra registrada no steering do Kiro).
- Árvore de semântica habilitada (`ensureSemantics`) no build web.
- Build web gerado no CI.

**Depende de:** nada.

#### PBI-03 · Banco de dados e migrations iniciais
**História:** Como desenvolvedor, quero o banco criado a partir do MER com dados de referência, para que as funcionalidades tenham onde gravar desde o primeiro dia.

**Critérios de aceite**
- Postgres local via Docker Compose para desenvolvimento.
- `DbContext` com todas as tabelas do MER, incluindo as preparadas para o futuro (`vinculo`).
- Constraints, índices e `CHECK`s do MER aplicados pela migration.
- Seed da tabela `metrica` com os seis registros do MER (3.4).
- Seed do catálogo global com pelo menos os exercícios usados no protótipo (supino reto, supino inclinado, crucifixo, tríceps corda, agachamento livre, remada curvada, prancha, agachamento isométrico, corrida, bicicleta).
- Testes de integração sobem um Postgres real (Testcontainers).

**Tabelas:** todas.
**Depende de:** PBI-01.
**Carga de catálogo (14/10):** o seed global passou de 10 para 89 exercícios
(`CatalogoGlobalSeed` + migration `CatalogoExerciciosCompleto`), cobrindo peito,
costas, ombros, braços, pernas, core, cardio e mobilidade, com o grupo muscular
e a forma de medir de cada um: CR (carga×reps, força), PR (peso corporal×reps,
força — ex.: flexão, barra fixa), PT (peso corporal×tempo, isometria), ZT
(zona×tempo, cardio). Os 10 genéricos antigos foram preservados: 3 que os testes
de integração usam por GUID (Supino reto→"Supino reto com barra", Agachamento
livre, Prancha) continuam ativos; os outros 7 viraram **inativos**
(`ativo=false`, soft-delete) em vez de apagados, porque as FKs de
`treino_exercicio`/`serie_executada` são `Restrict` e já pode haver histórico
ligado em produção (regra de dados: nada é apagado fisicamente). Nomes únicos
por catálogo respeitados (`ux_exercicio_nome_catalogo`).

#### PBI-04 · Publicação em produção
**História:** Como PO, quero cada incremento publicado num endereço real, para usar o app no celular e dar feedback de verdade.

**Critérios de aceite**
- Domínio registrado e apontando para a VPS.
- Caddy servindo o app web e a API com HTTPS automático.
- API em container, separada do compose do bot.
- Banco de produção no Neon; string de conexão só em variável de ambiente.
- Deploy automático a cada merge na `main`, aplicando migrations.
- Docker reinicia a API se o `/health` falhar.

**Depende de:** PBI-01, PBI-02, PBI-03.

#### PBI-05 · Backup do banco
**História:** Como atleta, quero ter certeza de que meu histórico nunca se perde, porque a graça do app é olhar meses de evolução.

**Critérios de aceite**
- `pg_dump` semanal automático do banco de produção.
- Arquivo guardado fora da VPS e fora do Neon.
- Mantém pelo menos as últimas 8 cópias.
- Procedimento de restauração documentado e testado uma vez antes do lançamento.

**Status:** ✅ concluída — workflow `.github/workflows/backup.yml` (`pg_dump`
semanal, artifact com retenção de 63 dias = ≥ 8 cópias, fora do Neon), secret
`NEON_DATABASE_URL` configurado, backup rodado com sucesso e **restauração
testada em 19/10/2026** (Postgres 18 local, contagens conferidas). Procedimento
em [BACKUP-RESTAURACAO.md](BACKUP-RESTAURACAO.md).

**Depende de:** PBI-04.

### Épico E1: Acesso

#### PBI-06 · Autenticação na API
**História:** Como atleta, quero que meus dados só sejam acessados com o meu login, para ter segurança sobre o que registro.

**Critérios de aceite**
- API valida o token do Firebase (emissor, audiência, assinatura e validade) conforme MAS 11.2.
- Requisição sem token ou com token inválido recebe 401.
- `GET /me` devolve perfil e papéis.
- No primeiro acesso, `GET /me` cria o `usuario` com o `firebase_uid` e o papel `ATLETA`.
- Teste de integração usando token assinado localmente.

**API:** `GET /me`. **Tabelas:** `usuario`, `usuario_papel`.
**Depende de:** PBI-03.

#### PBI-07 · Controle de acesso centralizado
**História:** Como atleta, quero que ninguém veja meus treinos sem permissão, inclusive quando o modo educador existir.

**Critérios de aceite**
- Serviço `IControleAcesso` com a regra do MAS 11.3: dono ou educador com vínculo ativo.
- Todos os casos de uso que leem ou gravam dados de atleta chamam o serviço.
- Recurso de outro usuário responde 404.
- Testes cobrindo: dono, educador com vínculo ativo, educador com vínculo encerrado, terceiro sem vínculo.

**Tabelas:** `vinculo`.
**Depende de:** PBI-06.

#### PBI-08 · Login e cadastro no app
**História:** Como atleta, quero entrar com e-mail e senha ou com minha conta Google, para começar a usar sem burocracia.

**Critérios de aceite**
- Tela de login conforme protótipo (tela 1).
- Cadastro com nome, e-mail e senha; login com e-mail e senha; login com Google.
- "Esqueci minha senha" envia o e-mail de redefinição do Firebase.
- Sessão continua aberta ao fechar e reabrir o app.
- Mensagens de erro claras para senha errada, e-mail já cadastrado e falta de conexão.
- Depois do login, o app chama `GET /me`.

**Depende de:** PBI-02, PBI-06.

#### PBI-09 · Primeiro acesso
**História:** Como atleta novo, quero entender em segundos como o app funciona, para não ficar perdido numa tela vazia.

**Critérios de aceite**
- Conta nova (nenhuma sessão e nenhuma ficha: sem plano, ou plano sem fichas) vê o primeiro acesso (tela 29) **só na Início**. A aba Planos tem estado vazio próprio (PBI-68).
- Primário: "Criar meu plano" (sem plano) ou "Montar a primeira ficha" (plano vazio, abre o detalhe dele).
- Secundário: "Registrar treino" leva para o treino livre (era "Registrar sem ficha").
- Depois que existe ao menos uma ficha ou sessão, a tela não aparece mais. Quem apagou os planos mas já treinou vê a Início normal com o card "Crie seu plano".

**Depende de:** PBI-08. O destino do segundo botão depende de PBI-19.
**Status:** FEITO. `PrimeiroAcessoScreen` (tela 6) aparece no lugar da inicial
quando o atleta não tem nenhuma ficha **nem** sessão. O gate é client-side em
`InicioScreen`, derivado dos providers já existentes (`planoAtivoProvider` +
`sessoesRecentesProvider`): só mostra quando os dois carregaram e estão vazios
(não pisca durante o carregamento nem em erro de rede). Botão "Montar minhas
fichas" leva às fichas; "Registrar sem ficha" leva ao treino livre (PBI-19).
Com ao menos uma ficha ou sessão, a tela inicial normal volta. Teste de widget
cobre os dois caminhos e o caso "tem sessão, sem ficha". **Revisto na PBI-68:**
textos e botões acima; o gate "sem plano em uso" da PBI-47 saiu.

### Épico E2: Catálogo de exercícios

#### PBI-10 · Buscar exercício no catálogo
**História:** Como atleta, quero encontrar rápido o exercício que fiz, para montar a ficha ou registrar o treino sem digitar tudo.

**Critérios de aceite**
- Lista o catálogo global mais os exercícios criados pelo próprio usuário.
- Busca por nome sem diferenciar maiúsculas e acentos.
- Filtro por modalidade: Todos, Força, Isometria, Cardio. *(Substituído pelo filtro por membro na PBI-31.)*
- Cada item mostra grupo e forma de medir (ex.: "Carga × repetições").
- Exercícios próprios aparecem com a marca "Meu".
- Estado vazio sugere criar o exercício.

**API:** `GET /exercicios`. **Tela:** 8.
**Depende de:** PBI-03, PBI-06.

#### PBI-11 · Criar exercício próprio
**História:** Como atleta, quero cadastrar um exercício que não está no catálogo e dizer como ele é medido, para registrar qualquer treino, inclusive de reabilitação.

**Critérios de aceite**
- Campos: nome, grupo, tipo (Força, Isometria, Cardio).
- Ao escolher o tipo, intensidade e volume vêm sugeridos (Força = carga × repetições; Isometria = peso corporal × tempo; Cardio = zona × tempo) e podem ser trocados.
- Métricas escolhidas apenas da lista da tabela `metrica`.
- Prévia mostra como os campos vão aparecer no registro.
- Não permite nome repetido no catálogo do próprio usuário.
- O exercício criado fica visível só para quem criou.

**API:** `POST /exercicios`. **Tabelas:** `exercicio`, `metrica`. **Tela:** 9.
**Depende de:** PBI-10.

### Épico E3: Fichas

#### PBI-12 · Criar fichas de treino
**História:** Como atleta, quero organizar meus treinos em fichas A, B, C, para registrar cada dia sem montar tudo de novo.

**Critérios de aceite**
- Ao criar a primeira ficha, o sistema cria um plano ativo com o usuário como autor e atleta.
- Criar, renomear e arquivar fichas, com nome curto ("A") e descrição ("Peito e tríceps").
- Ordem das fichas define a sequência sugerida na tela inicial.
- Ficha arquivada some da lista, mas o histórico de sessões dela continua.

**API:** `GET /planos/ativo`, `POST /planos`, `POST /planos/{id}/treinos`, `PUT /treinos/{id}`, `DELETE /treinos/{id}`. **Tabelas:** `plano_treino`, `treino`. **Tela:** 5.
**Depende de:** PBI-07.

#### PBI-13 · Montar exercícios da ficha
**História:** Como atleta, quero adicionar, reordenar e remover exercícios de uma ficha, para ela refletir o treino que eu faço.

**Critérios de aceite**
- Adicionar exercício a partir do catálogo (reaproveita a busca da PBI-10).
- Reordenar arrastando.
- Remover exercício da ficha sem apagar o histórico já registrado.

**Tabelas:** `treino_exercicio`. **Tela:** 5.
**Depende de:** PBI-10, PBI-12.

#### PBI-14 · Definir alvos do exercício na ficha
**História:** Como atleta, quero definir séries, carga, repetições e descanso de cada exercício, para o registro já abrir com o plano.

**Critérios de aceite**
- Séries com botões de mais e menos (de 1 a 12).
- Campos de alvo seguem as métricas do exercício (carga e repetições, ou só tempo, etc.).
- Descanso entre séries e instrução livre opcional.
- Frase de resumo atualiza enquanto edita ("3 séries de 10 com 30 kg, 90 s de descanso").

**Tabelas:** `treino_exercicio`, `etapa_prescrita`. **Tela:** 10.
**Depende de:** PBI-13.

### Épico E4: Registro do treino

#### PBI-15 · Registrar sessão a partir de uma ficha
**História:** Como atleta, quero lançar o treino que fiz escolhendo a ficha e o dia, com as cargas já preenchidas, para registrar em poucos toques mesmo dias depois.

**Critérios de aceite**
- Campo "Dia em que treinou" com hoje como padrão; aceita datas passadas e não aceita datas futuras além de amanhã.
- Duração em minutos, opcional.
- Cada exercício abre preenchido com as séries da última sessão do mesmo atleta que teve aquele exercício; sem histórico, usa os alvos da ficha.
- Aviso visível de onde veio o preenchimento ("Preenchido com o último Treino A (27/09)").
- Campo de observação do dia com texto livre.
- Salvar mostra a confirmação com atalhos para Progresso e Início.
- Exercício sem séries é salvo como não realizado, sem erro.

**API:** `GET /treinos/{id}/rascunho-sessao`, `POST /sessoes`. **Tabelas:** `sessao`, `serie_executada`. **Tela:** 3.
**Depende de:** PBI-14.

#### PBI-16 · Editar séries durante o registro
**História:** Como atleta, quero ajustar, adicionar e remover séries de cada exercício, para o registro bater com o que eu realmente fiz.

**Critérios de aceite**
- Exercício recolhido mostra resumo ("3 séries · 30 kg × 10, 35 kg × 8...").
- Adicionar série copia a anterior; remover tira só aquela linha.
- Colunas seguem as métricas do exercício: carga, reps e descanso para força; tempo e descanso para peso corporal, com o selo "Intensidade: peso corporal".
- Só aceita números válidos e não negativos.

**Tela:** 3.
**Depende de:** PBI-15.

#### PBI-17 · Adicionar exercício fora da ficha
**História:** Como atleta, quero incluir na sessão um exercício que não estava na ficha, porque nem sempre o treino sai igual ao plano.

**Critérios de aceite**
- Botão "Adicionar exercício fora da ficha" abre a busca do catálogo.
- O exercício entra na sessão sem alterar a ficha.
- A série é gravada sem vínculo com o prescrito (`treino_exercicio_id` nulo).

**Depende de:** PBI-10, PBI-16.

#### PBI-18 · Ver, editar e excluir sessão
**História:** Como atleta, quero abrir uma sessão antiga, corrigir algo ou apagá-la, para meu histórico ficar fiel.

**Critérios de aceite**
- Detalhe mostra data, ficha, duração, observação e as séries por exercício.
- Cada exercício mostra o plano ao lado ("Plano: 3 × 10 com 30 kg") quando houver.
- Exercício da ficha que não foi feito aparece como "Não realizado".
- Editar abre o registro preenchido com os dados da sessão.
- Excluir pede confirmação e remove a sessão do histórico e do gráfico.

**API:** `GET /sessoes/{id}`, `PUT /sessoes/{id}`, `DELETE /sessoes/{id}`. **Tela:** 11.
**Depende de:** PBI-15.

#### PBI-19 · Treino livre (sem ficha)
**História:** Como atleta, quero registrar um treino montando os exercícios na hora, para não depender de ter ficha pronta.

**Critérios de aceite**
- Registro começa vazio, só com data e duração.
- Adicionar exercícios pelo catálogo, cada um com suas séries.
- Mostra a última execução do exercício como referência, quando houver.
- Opção "Salvar também como ficha" cria uma ficha nova com os exercícios do treino.
- Sessão salva com `treino_id` nulo.

**Tela:** 7.
**Depende de:** PBI-16, PBI-17.
**Status:** FEITO. Back-end: a gravação de sessão com `treino_id` nulo já era
suportada (atleta = usuário logado, sem checagem de ficha); novo endpoint
`GET /exercicios/{id}/ultima-execucao` monta o rascunho de um exercício avulso
(séries da última execução do atleta ou uma série em branco das métricas padrão,
404 se o exercício não estiver disponível ao usuário); novo
`POST /planos/fichas-de-treino` cria uma ficha a partir dos exercícios do treino
(garante o plano, cria o treino e adiciona os exercícios na ordem, 404 se algum
não for acessível). Front: `TreinoLivreScreen` (tela 7) começa vazia (só data e
duração), "Adicionar exercício" traz a última execução como referência e a opção
"Salvar também como ficha" cria a ficha após gravar. Testes de integração cobrem
o treino livre, a última execução (com/sem histórico) e os casos 404 de outro
usuário; testes de widget da tela. CI roda a integração.

### Épico E5: Progresso

#### PBI-20 · Gráfico de evolução por exercício
**História:** Como atleta, quero ver num gráfico como um exercício evoluiu no período, para saber se estou progredindo.

**Critérios de aceite**
- Seleção do exercício entre os que têm sessões registradas.
- Filtros: 10, 15 e 30 dias e período livre (desde o cadastro até hoje).
- Força: maior carga de esforço por sessão. Isometria: maior tempo sustentado por sessão. O título do gráfico diz qual dos dois está sendo mostrado.
- Resumo do período: número de sessões, variação entre a primeira e a última, sessões com observação.
- Período sem dados mostra estado vazio, sem gráfico quebrado.

**API:** `GET /progresso/exercicios/{id}`. **Tela:** 4.
**Depende de:** PBI-15.
**Decidido (PO, 14/10):** o gráfico de força usa a **maior carga da sessão**
(não o volume total). Além da carga (eixo do gráfico), cada ponto mostra as
**repetições feitas com aquela carga** — a reps da própria série de maior carga,
não a maior reps da sessão —, porque o atleta progride também variando as reps
na mesma carga. Isometria segue com o maior tempo sustentado. Pergunta da
seção 10 resolvida.
**Status back-end:** FEITO — `GET /progresso/exercicios/{id}` e
`GET /progresso/exercicios` (lista com histórico, para o seletor) implementados
(ServicoProgresso + RepositorioProgresso), com força (carga + reps daquela
carga), isometria (tempo), resumo (sessões, variação, sessões com obs) e filtro
de/ate.
**Status front-end:** FEITO — aba Progresso (`progresso_screen.dart`) com seletor
de exercício (dropdown de `GET /progresso/exercicios`), `LineChart` (fl_chart)
acima da lista de sessões. Título por métrica (CARGA → "Carga (kg)", TEMPO →
"Tempo (s)"); tooltip da força mostra carga × reps daquela carga; resumo
(sessões · variação · com obs.); estados loading/erro/sem-seleção/sem-dados.
Reusa o filtro de período do PBI-22. Cores/tamanhos por token (`chartLine`).
9 testes de widget em `progresso_screen_test.dart`.
**Nota técnica:** fl_chart fixado em **1.0.0** (não 1.1.0): a 1.1.0 chama
`Matrix4.translateByDouble`/`scaleByDouble`, que só existem no `vector_math` do
Flutter 3.32+. O projeto/CI está no Flutter 3.29.3 (Dart 3.7.2). A 1.0.0 tem a
mesma API usada (`getTooltipColor`, `SideTitleWidget(meta:)`) e compila no 3.29.

#### PBI-21 · Observação no ponto do gráfico
**História:** Como atleta, quero tocar num ponto do gráfico e ler o que anotei naquele dia, para entender por que o desempenho caiu ou subiu.

**Critérios de aceite**
- Pontos de sessões com observação têm cor própria e legenda.
- Tocar num ponto mostra data, valor e observação, ou "Sem observação neste dia".
- Ao abrir o gráfico, a última sessão com observação já vem selecionada.
- Link "Abrir sessão" leva ao detalhe.
- Cada ponto é um alvo de toque de pelo menos 44 px e tem rótulo de acessibilidade.

**Tela:** 4.
**Depende de:** PBI-20.
**Status back-end:** FEITO — cada `PontoProgresso` (`GET /progresso/exercicios/{id}`)
agora traz `sessaoId` (para o link "Abrir sessão") e `observacao` (texto anotado
naquele dia, ou nulo). O texto já era projetado no `RepositorioProgresso` (só era
usado como booleano para o resumo); agora flui até o DTO. Observação nunca vai
para log (regra de dados). 2 testes de integração: isometria confere o texto no
ponto; força confere ponto com obs, ponto sem obs (nulo) e ids de sessão
distintos por ponto.
**Status front-end:** FEITO — gráfico interativo em `progresso_screen.dart`.
Pontos de sessões com observação usam a cor `obs` (laranja) + legenda "com
observação"; tocar num ponto o seleciona (fica maior, aumentando o alvo de
toque) e abre, abaixo do gráfico, um cartão com data longa, valor (e reps na
força) e o texto da observação, ou "Sem observação neste dia." quando não houve.
Ao abrir, a última sessão com observação já vem pré-selecionada (ou a mais
recente, se nenhuma tiver). Botão "Abrir sessão" navega para o detalhe (PBI-18)
via `DetalheSessaoArgs(sessaoId)`. O cartão tem rótulo de acessibilidade
(`Semantics`) com data + valor + observação. Cores/tamanhos por token. 2 testes
de widget novos (pré-seleção + nota; estado "sem observação"). Model Dart
`PontoProgresso` estendido com `sessaoId`/`observacao`.
**PBI-21 COMPLETO** (back + front).

#### PBI-22 · Sessões do período
**História:** Como atleta, quero a lista das sessões recentes, para achar um treino específico rapidinho.

**Critérios de aceite**
- Lista em ordem de data, mais recente primeiro, respeitando o filtro de período.
- Cada item mostra data, ficha (ou "Treino livre"), quantidade de exercícios, duração e selo "Obs." quando houver observação.
- Tocar abre o detalhe da sessão.

**API:** `GET /sessoes?de=&ate=`. **Tela:** 4.
**Depende de:** PBI-18.

#### PBI-23 · Tela inicial
**História:** Como atleta, quero abrir o app e já ver qual treino vem agora, para registrar com um toque.

**Critérios de aceite**
- Cartão "Próximo da sequência" com a ficha seguinte à última registrada, respeitando a ordem das fichas.
- Lista de fichas com a data da última vez de cada uma.
- Tocar no cartão "Próximo da sequência" ou em qualquer ficha da lista abre direto o registro daquela ficha. Nada é gravado até o atleta tocar em "Salvar treino", então um toque por engano não suja o histórico.
- Editar ficha continua na aba Fichas; a Início é só para treinar.
- O botão "Ver exercícios" sai da Início. O catálogo passa a ter entrada própria na aba Fichas (ação "Meus exercícios" no topo), além do seletor dentro do registro e da montagem de ficha.
- Atalhos para treino livre e, a partir do incremento 2, para cardio.
- Navegação inferior: Início, Fichas, Progresso.

**Tela:** 2.
**Depende de:** PBI-12, PBI-15.

### Épico E6: Experiência e conta

#### PBI-24 · Tema claro e escuro
**História:** Como atleta, quero escolher entre tema claro e escuro, ou seguir o do celular, para usar o app confortável em qualquer ambiente.

**Critérios de aceite**
- Padrão: seguir o tema do sistema.
- Botão na tela inicial alterna entre claro e escuro.
- Em Perfil, opção Sistema, Claro ou Escuro.
- Escolha salva no aparelho e mantida ao reabrir.
- Todas as telas do MVP conferidas nos dois temas, com contraste mínimo de 4,5:1 em texto.

**Notas técnicas:** ADR-08 do MAS.
**Depende de:** PBI-02, PBI-25.
**Status:** ✅ concluída — opção tríplice (Sistema/Claro/Escuro) em Perfil
(`SegmentedButton` + `TemaController`), botão sol/lua na Início e persistência em
`shared_preferences`. A **conferência de contraste** foi feita: auditados os 26
pares texto/fundo dos dois temas, todos ≥ 4,5:1; o único ícone abaixo de 3:1
(`iconMuted` no tema claro, 2,72:1) foi escurecido para `#82858C` (3,70:1). O
teste `app/test/contraste_tema_test.dart` trava o mínimo e previne regressão.
Validação final com tecnologia assistiva continua sendo manual.

#### PBI-25 · Perfil e conta
**História:** Como atleta, quero ver meus dados, sair da conta e poder excluí-la, para ter controle sobre o que fica guardado.

**Critérios de aceite**
- Tela de Perfil com nome, e-mail e opção de tema.
- Sair encerra a sessão no Firebase e volta ao login.
- Excluir conta pede confirmação digitada, apaga os dados no banco e o usuário no Firebase.
- Exclusão coberta por teste de integração.

**Depende de:** PBI-08.
**Status:** ✅ FEITO (back + front). Decisão do PO: **1A + 2A** — o back apaga os
dados no Postgres (`DELETE /api/v1/me`, hard delete transacional: sessões →
planos/fichas → vínculos → exercícios próprios → papéis → usuário, já que as FKs
para `usuario` são `Restrict`) e o app remove o usuário no Firebase em seguida
(`FirebaseAuth.currentUser.delete()`; se pedir login recente, orienta a entrar de
novo). Tela de Perfil (`perfil_screen.dart`) alcançada por ícone no cabeçalho da
Início: nome/e-mail do `GET /me`, seletor de tema (PBI-24), "Sair" e "Excluir
conta" com confirmação digitada ("EXCLUIR"). Testes: integração (apaga tudo do
usuário; não afeta outro usuário; 401 sem token) + 3 de widget.

#### PBI-73 · Gráfico decide a grandeza por exercício (sem carga, usa repetições)
**História:** Como atleta, quero que o gráfico de um exercício sem carga (ex.: flexão, prancha de repetições) mostre repetições, para acompanhar a evolução de quem não usa peso.
**Status:** ✅ concluída (PR #96). O gráfico escolhe o eixo por exercício: com carga, usa a carga; sem carga no período, usa **repetições** (a melhor série = maior nº de repetições da sessão); isometria segue com tempo. Enum `MetricaProgresso`. **Decisão do PO em aberto:** usar a melhor série ou o total de repetições da sessão — hoje é a melhor série.

#### PBI-74 · Um exercício por ficha e por sessão
**História:** Como atleta, não quero o mesmo exercício duplicado numa ficha ou numa sessão, para o registro não ficar confuso.
**Status:** ✅ concluída (PR #94). `POST /treinos/{id}/exercicios` responde **409** se o exercício já está na ficha; `POST /sessoes` responde **400** se dois blocos trazem o mesmo exercício; o seletor desabilita quem já está presente, com aviso. A unicidade vive na aplicação (sem constraint no banco); dados antigos com repetição continuam abrindo.

#### PBI-75 · Aviso simples vira pop pequeno (sem barra preta)
**História:** Como atleta, quero que avisos curtos (ex.: "Ficha criada") apareçam como um pop pequeno que some sozinho, sem uma barra preta cobrindo a base da tela com um botão que não pedi.
**Status:** ✅ concluída (PRs #113, #116 e #133). Componente compartilhado `mostrarAviso` (pílula flutuante ~2 s, sem ação, cor do tema) em "Ficha criada" (PR #113) e "Treino salvo" sem a ação "Ver treino", por decisão do PO (PR #116). No fechamento, a regra passou a valer no app todo: as confirmações que ainda usavam a barra preta ("agora está em uso", "Cópia criada", "Exercício criado", "Enviamos um e-mail de redefinição" e o "Ficha criada" da tela do educador) viraram pílula, e os **erros** do modo educador, que estavam saindo na pílula, foram para a barra de erro (`mostrarErro`, ao lado do `mostrarAviso`). Testes do componente nos dois temas, do erro x confirmação no educador e da ficha nova do aluno; suíte 344 verde.

#### PBI-76 · "Manter na ficha?": aviso quando a ficha não é lida
**História:** Como atleta, quero ser avisado quando o app não conseguir ler a ficha ao perguntar "Manter na ficha?", para entender por que a pergunta não apareceu.
**Status:** ✅ concluída (PR #97). `ResultadoManterNaFicha{ids, leituraFalhou}`: quando a leitura falha, o treino é salvo sem perguntar e com aviso (catch não-silencioso). Os três botões do diálogo ficam em coluna.

#### PBI-77 · Plano novo nasce em uso quando não há plano em uso
**História:** Como atleta, quero que o primeiro plano que eu criar já nasça em uso, para não precisar ativá-lo à mão.
**Status:** ✅ concluída (PR #93). Troca `!AtletaTemAlgumPlanoAsync` por `ObterPlanoEmUsoAsync is null` (planos escondidos não contam). Migration de reparo `20261019145756_ReparoPlanoEmUso` marca em uso o plano com a sessão mais recente para atletas que ficaram sem plano em uso.

#### PBI-78 · Editor de alvos abre com o dado atual
**História:** Como atleta, quero que o editor de alvos de um exercício abra já com os valores que estão salvos, não em branco, para só ajustar o que preciso.
**Status:** ✅ concluída (PR #95). O editor lê o dado atual do `fichaDetalheProvider` em vez de reabrir em branco.

#### PBI-79 · Resumo da ficha com faixa de repetições e unidade
**História:** Como atleta, quero que o resumo da ficha mostre a faixa de repetições e a carga com unidade ("65 kg", não "65 carga"), para ler o alvo sem ambiguidade.
**Status:** ✅ concluída (PR #95, junto da PBI-78). `_ResumoAlvo` usa `formatarVolumeAlvo` + unidade kg; mostra a faixa de repetições ("8 a 12").

#### PBI-80 · Tocar numa aba abre a raiz dela
**História:** Como atleta, quero que tocar numa aba da navegação inferior me leve sempre à raiz dela (ex.: Planos abre a lista de planos), não à tela em que eu estava, para não me perder.
**Status:** ✅ concluída (PR #98). `goBranch(i, initialLocation: true)` sempre; telas de tela cheia (registro, treino ao vivo) ficam no navigator raiz, acima da barra. Registrado como **ADR-11** no MAS.

#### PBI-81 · "Manter na ficha?" decide exercício por exercício
**História:** Como atleta, quero escolher, exercício por exercício, o que fica na ficha, para manter o que funciona e deixar de fora o que fiz só naquele dia.
**Status:** ✅ concluída (PR #112). Com um exercício, o diálogo atual (três botões) é mantido; com dois ou mais, cada exercício tem a escolha "Manter na ficha" / "Só neste treino" (padrão: manter), e "Salvar" devolve só os mantidos. A API (`POST /sessoes` com lista de ids em `manterNaFicha`) já suporta lista parcial.
**Decisão do PO (19/10):** exercício por exercício.

#### PBI-84 · "Adicionar série" nasce em branco no registro posterior e na edição
**História:** Como atleta, quero que a série nova nasça vazia, com a anterior só como dica, para não gravar sem querer uma série idêntica à última.
**Status:** ↩️ revertida por decisão do PO (31/10). Chegou a entrar na `main` (PR #114): no registro posterior/edição, "Adicionar série" nascia em branco com a anterior como dica (`hintText`). Na prática o PO preferiu o mesmo comportamento do treino ao vivo — a série nova vem com os valores da anterior **já preenchidos e editáveis** —, então o PR #115 reverteu a mudança e as três telas voltaram a copiar a série anterior. A história acima fica registrada como ideia rejeitada; se um dia a duplicação acidental incomodar, reabrir discutindo a opção "copiar só a carga, repetições em branco".
**Depende de:** PBI-16.

#### PBI-82 · Calendário do mês a partir do cartão "Esta semana"
**História:** Como atleta, quero abrir o mês inteiro a partir do cartão "Esta
semana" e navegar de mês em mês, para ver em que dias treinei e abrir o que foi
feito em cada dia.

**Critérios de aceite**
- Link (ícone de calendário) no cartão "Esta semana" abre o calendário do mês atual.
- Grade seg→dom com a mesma marca de dia da semana (treinou, hoje, passado sem treino, futuro); "N dias treinados" do mês exibido.
- Seta de mês anterior sem limite; seta de mês seguinte para no mês atual; "Hoje" volta a ele fora do mês atual.
- Tocar num dia passado abre a folha do dia (ver/registrar); dia futuro não abre.
- Mês sem treino mostra "0 dias treinados"; falha de rede mostra "Tentar de novo", nunca um mês vazio falso.
- Salvar/editar/excluir sessão atualiza o calendário aberto (PBI-70).

**Notas técnicas:** só front. Reusa `GET /sessoes?de=&ate=` (sem endpoint novo,
sem mudança de banco). `MarcaDia`/`CirculoTracejado` extraídos para
`shared/calendario/`; `CalendarioMes.semanasDoMes` é função pura testável.
`sessoesDoMesProvider` (família por mês) entra no mapa de invalidação (PBI-70).
Rota `/mes` filha da Início. Os dias passados sem treino levam um "X" (semana e mês).
**Depende de:** PBI-22, PBI-23, PBI-59.
**Status:** ✅ FEITO (front; PRs #104 a #106). `flutter analyze` 0 e suíte verde; testes da função
de meses, da tela, do link na Início e da invalidação do mês.

#### PBI-90 · Treino ao vivo: "Concluir exercício" no fim das séries e descanso que conta negativo
**História:** Como atleta, quero que o "Concluir exercício" só apareça quando eu
chegar ao fim das séries, e que o descanso me avise quando acabar, para a tela
não me atrapalhar no meio da série e eu não perder o momento de voltar ao treino.

**Origem:** feedback de uso real do PO (prints de 02/10): o botão fixo "atrapalha"
e o descanso sumia sozinho ao zerar.

**Critérios de aceite**
- "Concluir exercício" / "Concluir e ir ao resumo" sai do rodapé fixo e fica no
  **fim da aba Séries**, abaixo do "Adicionar série", rolando junto com a lista.
  Não aparece nas abas Histórico e Evolução.
- O aviso "N séries sem marcar ficam de fora" vai junto, logo acima do botão.
- O descanso **não some ao zerar**: segue contando **negativo** ("−00:05") e mostra
  **"Descanso acabou, volte ao treino"**, com borda em destaque e barra cheia.
- Depois de zerar, "−15s" some e "Pular" vira **"Voltar ao treino"** (que encerra
  o descanso). "+15s" segue disponível e reinicia uma contagem de 15s. Completar a
  próxima série começa outro descanso, como antes.
- Sem limite para o tempo negativo: conta até o atleta agir.
- Acessibilidade: o aviso de "acabou" é anunciado uma vez (região viva); o tempo
  negativo não é narrado a cada segundo. O botão "Concluir" tem rótulo próprio.

**Notas técnicas:** só front, sem mudança de API ou banco. `DescansoEstado.saldo`
(com sinal) ao lado do `restante` (sem sinal, usado pelos ajustes ±15s);
`formatarSaldo` em `widgets_ao_vivo.dart`. O `Timer` da barra só redesenha, não
encerra mais o descanso. `_RodapeConcluir` virou `_BlocoConcluir`, dentro da
`_AbaSeries`. A barra de descanso continua fixa no rodapé, nas três abas.
**Depende de:** TV-5 (PBI-42), PBI-65.
**Status:** ✅ FEITO (front; PR #132). `flutter analyze` 0; suíte 336 verde (testes do botão
no fim da lista e fora das outras abas, da lista longa com rolagem, do descanso
negativo com aviso e do saldo no controller). E2E não usa essas telas.

#### PBI-26 · Teste E2E do fluxo principal
**História:** Como time, queremos um teste automatizado do caminho mais importante, para publicar sem medo de quebrar o que já funciona.

**Critérios de aceite**
- Suíte Robot Framework com Browser library rodando contra o app web.
- Cenário: entrar, registrar um treino da ficha A com observação, abrir o progresso e ver o ponto com a observação.
- Roda no CI antes do deploy, com um usuário de teste próprio.

**Depende de:** PBI-21.

**Status:** ✅ CONCLUÍDA (PRs #108 a #110). E2E do fluxo principal rodando verde no CI (job `e2e`),
contra a **stack real efêmera**: Postgres (service) + API .NET + Firebase Auth
Emulator + o app Flutter de verdade. Cenário coberto: entrar (já autenticado) →
registrar um treino livre (adicionar "Supino reto com barra" do catálogo, marcar
como feito, preencher carga e repetições, finalizar) → ver a sessão registrada
na aba Progresso. Usuário de teste próprio, provisionado na hora.

**Mudança de abordagem (Robot → integration_test).** O plano original era Robot
Framework + Browser library (Playwright) dirigindo o app web pelo DOM. Isso se
mostrou **inviável** neste stack: o Flutter 3.29 só tem o renderer **CanvasKit**
(o renderer HTML foi removido), que desenha os campos em canvas; o `<input>` da
árvore de semântica é um proxy que o framework recria/limpa, e preencher por fora
(via DOM) não alimenta o `TextEditingController` de forma confiável — testado com
`insertText`, `type` e `fill`, todos descartavam o valor. Migrou-se para
**`integration_test`** (`app/integration_test/fluxo_pbi26_test.dart` +
`test_driver/integration_test.dart`), que dirige a árvore de widgets
(`tester.enterText`) e digita de verdade. No CI roda com `flutter drive` +
ChromeDriver (Chrome headless do runner). O antigo diretório `e2e/` guarda só o
`firebase.json` do emulador; os arquivos do Robot foram removidos.

**Auto-login no modo E2E.** Como o `integration_test` não exerce a tela de login
(digitar no cadastro esbarraria no mesmo CanvasKit), o `main.dart` provisiona e
loga um usuário de teste no emulador **apenas quando `USE_AUTH_EMULATOR=true`**
(produção intacta). Com o usuário logado, o `redirect` do go_router cai na Início
e o `TokenInterceptor` anexa o ID token.

**Ajustes de backend necessários para o emulador (só no modo E2E):**
- `AutenticacaoFirebase`: aceita o token do emulador — `RequireSignedTokens=false`
  (o emulador emite `alg:none`, sem assinatura) além do `SignatureValidator`,
  ativado só quando `Firebase:AuthEmulatorHost` está definido.
- CORS: libera qualquer `localhost` no modo emulador (o `flutter drive` serve o
  app numa porta aleatória), sem lista fixa.

**Bug de produção encontrado pelo E2E (corrigido).** No primeiro acesso o app
dispara chamadas autenticadas em paralelo (`/planos/ativo` e `/sessoes`), que
chamam `ObterOuProvisionarAsync` para um usuário ainda inexistente. As duas liam
`null` e tentavam inserir o mesmo usuário → a segunda violava o índice único de
email e o endpoint devolvia **500**. Corrigido com provisionamento idempotente:
`RepositorioUsuario.TentarInserirUsuarioAsync` trata a violação de unicidade
(Postgres `23505`) e o `ServicoPerfil` re-busca o usuário. Beneficia produção, não
só o teste.

O teste antigo de fluxo de UI em `app/test/fluxo_registro_test.dart` (roda no
`flutter test`, com as bordas fakeadas) permanece como cobertura complementar.

---

## 7. Incremento 2: Cardio

> Só entra em refinamento depois da resposta do Vinicius sobre como a zona é definida (seção 10).

#### PBI-27 · Cardio contínuo
**História:** Como atleta, quero registrar uma corrida ou pedalada contínua com zona e tempo ou distância, para acompanhar meu condicionamento junto com a musculação.

**Critérios de aceite**
- Atividade (corrida, esteira, bicicleta), dia, zona, medir por tempo ou distância, valor e observação.
- Permite adicionar outro trecho quando a zona mudou no meio.
- Cada trecho é gravado como série com intensidade `ZONA` e volume `TEMPO_SEG` ou `DISTANCIA_M`.

**Tela:** 12, aba Contínuo.
**Depende de:** PBI-15.

#### PBI-28 · Cardio intervalado (tiros)
**História:** Como atleta que segue planilha de assessoria, quero registrar tiros com zona, tempo, descanso e zona do descanso, do jeito que a assessoria escreve.

**Critérios de aceite**
- Tabela com colunas série, zona, tempo, descanso e zona do descanso.
- Adicionar tiro copia o anterior.
- Quando vem de uma ficha, abre com os tiros prescritos preenchidos.
- Cada tiro vira duas séries: esforço e recuperação, na mesma rodada.

**Tela:** 12, aba Intervalado. **Tabelas:** `etapa_prescrita`, `serie_executada`.
**Depende de:** PBI-27.

#### PBI-29 · Tempo por zona
**História:** Como atleta, quero ver quanto tempo passei em cada zona, porque no cardio é isso que mostra se cumpri o treino.

**Critérios de aceite**
- Na sessão: barra com a proporção do tempo em cada zona e total.
- No progresso: tempo total por zona no período, em barras empilhadas.
- Quando houver plano, mostra o percentual de aderência (planejado x feito, por zona).

**Depende de:** PBI-28.

#### PBI-30 · Resumo do período
**História:** Como atleta, quero ver quantos treinos e quantas sessões de cardio fiz no período, para saber se estou mantendo a frequência.

**Critérios de aceite**
- Cartão na tela inicial e no progresso com treinos de musculação, sessões de cardio e dias com observação no período.
- Modalidade da sessão derivada dos exercícios das séries (MER 3.10).

**API:** `GET /progresso/resumo`.
**Depende de:** PBI-27.

---

## 8. Ajustes depois da primeira publicação

Itens que surgiram com o app em uso real.

#### PBI-31 · Filtrar exercícios por membro
**História:** Como atleta, quero filtrar os exercícios por membro (peito, pernas, costas...), para achar rápido o que eu treinei na hora de registrar ou montar a ficha.

**Critérios de aceite**
- Os chips do seletor e do catálogo passam a ser: Todos, Peito, Costas, Ombros, Braços, Pernas, Core, Cardio, Mobilidade, nessa ordem, com rolagem horizontal no celular.
- O filtro por modalidade sai dos chips. A modalidade continua aparecendo na legenda de cada item ("Carga × Repetições").
- A legenda de cada item mostra o membro (e o músculo, quando houver) com a grafia da lista, nunca o texto antigo.
- Busca por nome e filtro por membro funcionam juntos.
- No cadastro de exercício, o campo de grupo vira seleção: membro obrigatório e músculo opcional, com os músculos filtrados pelo membro escolhido.
- Migration converte o texto antigo conforme o MER (3.5); o que não for reconhecido aparece como "sem membro", com atalho para o dono classificar.
- Exercícios de cardio do catálogo global ficam no membro Cardio.

**API:** `GET /membros`, `GET /exercicios?busca=&membro=`, `POST /exercicios` (passa a exigir `membroId`). **Tabelas:** `membro`, `musculo`, `exercicio`. **Telas:** 8 e 9.
**Notas técnicas:** ADR-10 do MAS. Seed dos membros e músculos conforme MER 3.4.1 e 3.4.2. Fazer em etapas, sem quebrar o que está no ar: (1) migration cria `membro` e `musculo`, adiciona `membro_id` e `musculo_id` em `exercicio` e converte o texto, **mantendo** `grupo_muscular`; (2) API passa a ler e gravar o membro; (3) front troca os chips e o cadastro; (4) só então uma segunda migration remove `grupo_muscular`. Cada etapa vai para produção sozinha e o app continua funcionando entre elas.
**Depende de:** PBI-10, PBI-11.
**Status etapa 1 (banco):** FEITO — migration `MembroMusculoEtapa1`. Cria `membro`
(8) e `musculo` (15, com AK `(id, membro_id)`), adiciona `membro_id`/`musculo_id`
nulos em `exercicio` (FK composta garante que o músculo pertence ao membro),
mantém `grupo_muscular`. O catálogo global (89) já nasce classificado via seed;
exercícios próprios dos usuários são convertidos por SQL (unaccent+lower pelo
nome do músculo, depois pelo nome/código do membro; cardio/isometria sem grupo →
Cardio/Mobilidade). **Resíduo** (próprio que não casa) é **excluído** junto das
dependências (séries, sessões que ficarem vazias, itens de ficha) — decisão do PO
(tudo é teste). Teste de integração confere seed + classificação + consistência
da FK composta.
**Status etapa 2 (API):** FEITO — `GET /membros` (8 membros + músculos, na ordem
dos chips); `GET /exercicios?membro=` filtra por membro (modalidade continua
disponível); `POST /exercicios` passa a exigir `membroId` e aceita `musculoId`
opcional, validado como pertencente ao membro (a FK composta do banco também
protege). `ExercicioResumo` agora traz membro/músculo (id + nome) para o front.
Testes de integração: `GET /membros`, filtro por membro, criar sem membro (400),
músculo de outro membro (400), criar válido classifica (201).
**Status etapa 3 (front):** FEITO — chips de membro no lugar da modalidade no
catálogo (tela 8) e no seletor de exercício, montados a partir de `GET /membros`
(Todos + 8 membros, com rolagem horizontal). A legenda de cada item mostra
"Membro · Músculo" (ou só o membro, ou vazio quando ainda não classificado),
nunca o texto antigo. Busca e filtro por membro funcionam juntos. No cadastro
(tela 9) o campo de grupo virou seleção: membro obrigatório (dropdown com
validação) e músculo opcional, filtrado pelo membro e desabilitado quando o
membro não tem músculos (ex.: Cardio, Mobilidade). Testes de widget cobrem a
lista com legenda, os chips, o cadastro e o estado de carregamento.
**Status etapa 4 (remove grupo):** FEITO — migration `MembroMusculoEtapa4RemoveGrupo`
dá `DROP COLUMN grupo_muscular` na tabela `exercicio` (os dados já tinham migrado
para `membro_id`/`musculo_id` na etapa 1). A coluna sai do domínio (`Exercicio`),
da configuração EF, do seed e de todos os DTOs/serviços; `CriarExercicioRequest`
não aceita mais `grupoMuscular`. Build Release limpo (0 avisos com warnings-as-errors),
28 testes unitários verdes; integração roda no CI aplicando as migrations do zero.
**PBI-31 concluído.**

#### PBI-32 · Ajustes de UX do seletor e da largura no web
**História:** Como atleta, quero criar um exercício sem sair do registro quando ele não está no catálogo, e usar o app no computador sem a tela esticada.

**Critérios de aceite**
- O seletor de exercício tem o botão "Criar exercício novo", inclusive no estado vazio da busca (tela 8 do protótipo).
- Depois de criado, o exercício volta já selecionado para a tela de origem (ficha ou registro).
- No navegador de computador, o conteúdo fica limitado a 600px de largura e centralizado (MAS, seção 10).

**Depende de:** PBI-10, PBI-11.

#### PBI-33 · Bug: treino "salvo" não aparece no histórico
**História:** Como atleta, quero que o treino que registro seja de fato gravado e apareça depois, para não perder o que fiz.

**Sintoma relatado:** ao tocar em "Salvar treino", aparece a confirmação "Treino registrado" (com atalhos para Início / Ver treino / Ver progresso), mas o treino não aparece de fato salvo depois. Nos prints, todos os exercícios da ficha abrem como "Não realizado".

**Causa raiz (confirmada no código):** o registro abre cada exercício como "realizado" apenas quando o rascunho traz séries sugeridas (`ExercicioEdicao.doRascunho`: `realizado: e.series.isNotEmpty`). O rascunho (`ServicoSessao.MontarRascunhoAsync`) só sugere séries a partir de (1) última execução do exercício ou (2) alvos prescritos na ficha (PBI-14). Para exercícios **sem alvos definidos e sem histórico** (ex.: ficha recém-criada, primeiro registro), o rascunho vem **sem séries** → todos abrem como "Não realizado" → ao salvar, a regra do back-end (`CriarSessaoAsync`: exercício sem séries não grava nada) cria a sessão **vazia**. A confirmação de sucesso aparece mesmo assim, dando a impressão de "não salvou".

**Critérios de aceite**
- Exercício sem alvos e sem histórico abre de forma que dê para registrar as séries facilmente (ex.: já com uma série em branco para preencher, ou um caminho claro para adicionar a primeira série), em vez de só "Não realizado".
- Ao salvar com pelo menos um exercício com séries preenchidas, a sessão é gravada com as séries e aparece no detalhe (PBI-18) e na listagem (PBI-22).
- Exercício deixado deliberadamente como "Não realizado" continua sendo gravado como não realizado, sem impedir o salvamento dos demais (regra atual preservada).
- Se o usuário tenta salvar uma sessão **sem nenhuma série em nenhum exercício**, o app avisa (ex.: "nenhuma série registrada") em vez de mostrar "Treino registrado" para uma sessão vazia.
- Se o `POST /sessoes` falhar, o app mostra erro em vez da confirmação de sucesso.
- Teste cobrindo: registro de sessão com séries e leitura posterior; e tentativa de salvar sessão vazia.

**Notas técnicas:** front em `registrar_sessao_screen.dart` e `sessao_edicao.dart` (`ExercicioEdicao.doRascunho`). Avaliar: adicionar uma série em branco quando não há sugestão (como já é feito em `foraDaFichaDoCatalogo`), e barrar o salvamento de sessão totalmente vazia. Relaciona-se com a PBI-14 (definir alvos deixaria o rascunho pré-preenchido). Decidir também a mensagem de confirmação só após 201.
**Depende de:** PBI-15, PBI-18.
**Prioridade:** alta (bug em funcionalidade central já publicada).
**Status:** ✅ corrigida (série em branco no rascunho + trava de sessão vazia; na `main` e publicada).

#### PBI-34 · Trocar a métrica de intensidade no registro (ex.: isométrico com carga)

**História:** Como atleta, quero poder registrar um exercício com uma intensidade diferente da padrão (ex.: agachamento isométrico com halter/kettlebell/caneleira, em vez de só peso corporal), para o registro refletir o que realmente fiz.

**Contexto:** hoje a série do registro usa a métrica de intensidade **padrão do exercício** (do catálogo) e não dá para trocar. Um isométrico fica preso em "peso corporal"; um exercício de carga fica preso em "carga". Observado em teste pelo PO no agachamento isométrico.

**Decisão de produto em aberto (bloqueia o refinamento):** onde a troca acontece?
- (a) **no momento do registro** — a série deixa escolher a métrica de intensidade (dentre as do eixo INTENSIDADE); flexível por dia, mas o gráfico de progresso precisa lidar com um exercício que ora é peso corporal, ora carga;
- (b) **no exercício/alvo da ficha (PBI-14)** — define-se a intensidade ali e o registro herda; mais previsível para o gráfico, menos flexível no dia a dia.

**Critérios de aceite (preliminares, dependem da decisão)**
- Dá para registrar o mesmo exercício com carga num dia e peso corporal em outro (se for a opção a), ou a ficha define a intensidade usada (se for a opção b).
- A métrica escolhida respeita o eixo (INTENSIDADE) — validação já existe no back (`ValidarEixoAsync`).
- O gráfico de progresso (PBI-20) continua coerente quando a métrica de intensidade varia entre sessões do mesmo exercício (definir como agrupar).

**Notas técnicas:** o `POST/PUT /sessoes` já aceita `intensidadeMetricaId` por série e valida o eixo — ou seja, o back praticamente já suporta a opção (a); falta a UI de troca no registro (`registrar_sessao_screen.dart` / `sessao_edicao.dart`) e resolver o impacto no progresso. A opção (b) mexe em `treino_exercicio`/alvos.
**Depende de:** PBI-15. Relaciona-se com PBI-14 e PBI-20.
**Prioridade:** média (limitação real, mas contornável deixando o exercício com a métrica certa no catálogo).

#### PBI-35 · Cronograma semanal planejado (ficha por dia da semana)

**História:** Como atleta, quero poder planejar qual ficha é de cada dia da semana (ex.: A na segunda, B na quarta), para o app cobrar/sugerir o treino certo do dia e mostrar aderência ao plano.

**Contexto:** a tela inicial (PBI-23A) já tem uma faixa semanal que marca os dias **em que treinei** (sem planejar o quê). Esta PBI é o passo além: associar fichas a dias e mostrar "era pra fazer A na segunda — fez? ✓ / não fez". O modelo atual **não** suporta isso (não há "dia planejado da ficha" no MER).

**Decisões do PO (05/11):**
1. A semana é **do plano**: cada plano tem a sua, e a Início segue a do plano em uso. Plano do professor vem com a semana dele e só o autor edita (como as fichas).
2. **Semana fixa** (A na segunda, B na quarta…). Rotação fica fora.
3. **No máximo uma ficha por dia**; a mesma ficha pode ir em vários dias.
4. "Fez" = **treinou no dia, com qualquer ficha** (mede constância).
5. Na Início, **sem atalho novo** (respeita a PBI-59): a faixa semanal mostra a ficha planejada de cada dia e ✓ / "faltou" nos dias passados; a folha do dia mostra "Planejado: Treino A" e o registro segue como hoje.
6. Fora por ora: calendário do mês, rotação, cobranças/notificações.
- **Opcional:** criar ficha não pede dia; plano sem semana mostra a Início exatamente como antes; dá para planejar só alguns dias. Quem já tem fichas associa, troca e remove quando quiser, sem afetar treinos registrados.

**Critérios de aceite**
- Associar fichas do plano a dias da semana (dia com ficha ou livre), trocar e remover a qualquer momento.
- A tela inicial mostra o planejado × o realizado por dia (só quando o plano em uso tem semana).
- Excluir/arquivar a ficha libera os dias dela; duplicar o plano leva a semana; nenhuma mudança na semana mexe em sessões.

**Notas técnicas:** tabela `plano_dia_semana` (PK `plano_id, dia_semana`; ver MER 3.14 e regra 14), migration `PlanoSemana`, `PUT /planos/{id}/semana`, `semana` no `GET /planos/{id}` e no `GET /planos/ativo`. Fatiada em back e front.
**Depende de:** PBI-23 (parte A), PBI-15.
**Prioridade:** baixa (evolução; a faixa semanal do PBI-23A já entrega valor sem isto).

**Status (35-back):** ✅ backend feito (PR #134). Migration só cria a tabela, vazia. `ServicoPlanejamento.DefinirSemanaAsync` passa pelo acesso (outro usuário 404) e pela regra do autor (plano do professor 403; educador autor edita); `DefinirSemanaValidator` (dia 1..7, um por dia) e ficha ativa do plano conferida no serviço (400). Troca da semana por diferença (o EF não aceita remover e reinserir a mesma PK no mesmo `SaveChanges`). Arquivar ficha remove os dias na aplicação; apagar cai por cascata; duplicar mapeia ficha antiga → nova. Build 0/0; 62 unitários verdes (+8); integração (`PlanoSemanaEndpointTests`: fluxo, vazia, 400, 404, 403, educador, excluir/arquivar, duplicar) roda no CI.
**Status (35-front):** ✅ front feito (PR #135). **Detalhe do plano:** seção "SEMANA" (seg→dom) logo depois das fichas; tocar num dia abre a escolha da ficha ou "Livre", grava na hora (`FichasComandos.definirSemana`) com a pílula "Segunda: A" e, se falhar, o dia volta ao que era e o erro aparece na barra. Plano do professor mostra a semana sem toque (some se ele não definiu); plano sem fichas não mostra a seção. O mesmo widget (`SecaoSemana`) está na tela do plano do aluno, para o educador. **Início:** com semana, cada dia da faixa mostra o rótulo curto da ficha (A, B…); o "X" fica só para o dia planejado que passou sem treino ("faltou"); dia sem ficha que passou é descanso (círculo vazio); o leitor de tela ouve "planejado A, faltou" / "descanso". A folha do dia mostra "Planejado: A" e o registro segue igual. **Sem semana, a Início é a de antes** (rótulos e marcas idênticos — teste dedicado). Calendário do mês sem mudança. `flutter analyze` 0; suíte 363 verde (+19).

#### PBI-36 · Excluir ficha

**História:** Como atleta, quero excluir uma ficha que não uso mais, para a lista de fichas ficar limpa, sem perder os treinos que já registrei com ela.

**Contexto:** a ação de remover ficha existe no app, mas aparece como "Arquivar" (ícone de arquivo) e sempre arquiva (`ativo=false`), mesmo quando a ficha nunca foi usada. O usuário procura "Excluir" e não encontra; e uma ficha criada por engano, sem nenhum treino, fica arquivada para sempre em vez de sumir.

**Critérios de aceite**
- Na aba Fichas, cada ficha tem a ação "Excluir ficha" (menu de três pontos ou deslizar), com confirmação.
- Ficha **sem nenhuma sessão registrada** é apagada de verdade, com os itens (`treino_exercicio`) e etapas (`etapa_prescrita`) em cascata.
- Ficha **com sessões registradas** é arquivada (`ativo = false`): some da aba Fichas, da tela inicial e da rotação A→B→C, e as sessões continuam no histórico e no gráfico com o nome da ficha.
- O texto da confirmação diz o que vai acontecer: "Os treinos já registrados com esta ficha continuam no seu histórico."
- Teste de integração cobrindo os dois casos (sem sessões = apaga; com sessões = arquiva) e o 404 para ficha de outro usuário.

**API:** `DELETE /treinos/{id}` passa a ser condicional (apaga se não houver sessões; arquiva se houver). **Tela:** 5.
**Depende de:** PBI-12, PBI-15, PBI-18.
**Prioridade:** alta (lacuna de UX numa funcionalidade central).

#### PBI-37 · Treino em andamento: iniciar, finalizar e rascunho local

**História:** Como atleta, quero iniciar um treino, marcar cada exercício
conforme faço e finalizar no fim, com o que já preenchi guardado no aparelho se
eu sair no meio, para o registro refletir o treino de verdade e não parecer
"pronto" antes de eu começar.

**Contexto:** hoje o registro de uma ficha abre com os exercícios já marcados
como "Realizado" e as séries preenchidas pelo pré-preenchimento. Isso deixa o
layout estranho (parece que o treino já foi feito) e faz o check perder o
sentido. Falta a noção de "treino em andamento": começar desmarcado, marcar o
que foi feito e finalizar. Decisão do PO (**Opção 1 + rascunho local**): sem
mudança de banco nem de API — o treino em andamento vive só no aparelho
(`shared_preferences`) e vira sessão de verdade só ao finalizar (o mesmo
`POST /sessoes` de hoje). Um treino em andamento por vez.

**Critérios de aceite**
- **Checks começam desmarcados.** Ao abrir o registro, cada exercício mostra as
  séries da última execução (ou dos alvos) como **sugestão em tom secundário**,
  com o check "Realizado" **desligado**. Tocar no check — ou em qualquer campo do
  exercício — marca como realizado; aí os valores passam a valer e ficam
  editáveis.
- **Finalizar no lugar de salvar.** O botão principal passa a ser "Finalizar
  treino". Com todos os exercícios marcados, finaliza direto. Se houver
  exercício sem marcar, mostra: "Ainda tem N exercícios sem marcar. Finalizar
  mesmo assim? Eles ficam como não realizados." (Cancelar / Finalizar).
- **Rascunho local.** O treino em andamento é salvo no aparelho
  (`shared_preferences`) a cada alteração e apagado ao finalizar ou descartar.
  Só um em andamento por vez. O rascunho sobrevive a fechar e reabrir o app.
- **Continuar treino.** Havendo um treino em andamento, a tela inicial mostra
  "Continuar treino [ficha]" que reabre o registro de onde parou.
- **Sair com treino iniciado.** Ao tentar sair da tela (voltar ou trocar de aba)
  com um treino em andamento, abre um diálogo com três opções: "Finalizar agora",
  "Continuar depois" (mantém o rascunho) e "Descartar treino" (com confirmação).
- **Duração automática.** A hora de início é guardada ao abrir; ao finalizar, a
  duração vem calculada e editável antes de confirmar.
- **Registrar depois do fato continua.** Na ficha há dois caminhos: "Iniciar
  treino agora" (data de hoje, cronômetro/duração automática) e "Registrar treino
  já feito" (data editável, duração digitada), ambos com as mesmas regras de
  check e o mesmo aviso ao finalizar.
- **Próximo treino nasce limpo.** Ao abrir a ficha de novo depois de finalizar,
  os checks começam desmarcados e as séries aparecem com os valores da última
  sessão como sugestão (não como "feito").

**Fora de escopo:** retomar um treino em andamento em outro aparelho (o rascunho
é local); nenhum estado "em andamento" é persistido no servidor.

**Testes:** o rascunho sobrevive a fechar e reabrir o app; finalizar com
exercício sem marcar mostra o aviso e grava os não marcados como não realizados;
o próximo treino da mesma ficha nasce desmarcado, com os valores da última
sessão como sugestão.

**API:** nenhuma mudança (usa `POST /sessoes` com as séries dos exercícios
marcados). **Banco:** nenhuma mudança. **Telas:** 3 (registro) e 2 (início, com
"Continuar treino").
**Depende de:** PBI-15, PBI-16, PBI-19.
**Prioridade:** alta (ajuste de fluxo central do registro; entra antes de fechar
o MVP).
**Status:** FEITO (front, sem mudança de banco/API). Rascunho local em
`shared_preferences` (`treino_em_andamento`, um por vez) com serviço
`RascunhoTreinoService` e `treinoEmAndamentoProvider`. No registro de uma ficha
os checks começam **desmarcados**: as séries da última execução/alvos aparecem
em tom secundário como sugestão e tocar nelas (ou no check) marca o exercício e
abre os campos. O autosave grava o rascunho a cada alteração; a saída pela seta
ou troca de aba abre o diálogo Finalizar agora / Continuar depois / Descartar
(com confirmação). O botão é "Finalizar treino", com o aviso de N exercícios sem
marcar; a duração vem automática do início e é editável. A Início mostra
"Continuar treino [ficha]" quando há rascunho. A ficha ganhou "Iniciar treino
agora" e "Registrar treino já feito". Finalizar grava via `POST /sessoes` (não
marcados = não realizados) e apaga o rascunho. Testes: round-trip do rascunho
(sobrevive a reabrir), aviso ao finalizar com exercício sem marcar, exercício
nasce desmarcado com os valores da última sessão como sugestão, e o fluxo de UI
(fluxo_registro) atualizado. **GOTCHA:** o `RegistrarSessaoScreen` **lê** (não
observa) o `treinoEmAndamentoProvider` ao decidir retomar — observá-lo causaria
um loop de rebuild que reseta o formulário a cada tecla (o autosave invalida o
provider).

---

## 8b. Épico "Treino ao vivo, série por série" (pós-MVP)

Registrar o treino enquanto ele acontece, série por série. Release 1 (TV-1, TV-2)
mexe no banco e já entrega valor nas telas atuais; Release 2 (TV-3 a TV-6) é o
treino ao vivo em si (front). Spec do épico no PDF; cada PBI vira uma spec do
Kiro (`.kiro/specs/`).

#### PBI-38 (TV-1) · Tag de série

**História:** Como atleta, quero marcar cada série com o tipo de série que fiz
(aquecimento, top set, até a falha e as outras), para o histórico mostrar como o
treino foi feito, e não só a carga e as repetições.

**Escopo:** banco + API + front. Lista fixa de 10 marcadores (aprovada pelo PO,
15/10); `VALIDA` é o padrão e não mostra chip no modo leitura. A tag é **só
identificação**: não muda o gráfico (PBI-20) nem o volume.

**API/Tabelas:** nova `rodada_marcador (treino_exercicio_id, rodada, marcador)`;
`serie_executada.marcador`. Item da ficha (`PUT .../alvos`) aceita/devolve
`marcadores`; séries da sessão aceitam/devolvem `marcador`.
**Telas:** 10 (editar exercício da ficha), 3 (registrar), 11 (detalhe).
**Depende de:** PBI-14, PBI-15, PBI-18. Spec: `.kiro/specs/tv-1-tag-de-serie/`.

**Status:** FEITO (back + front) e mergeado (PR #55). Branch
`feat/pbi-38-tag-de-serie`.
- **Banco:** migration `TagDeSerie` — coluna `serie_executada.marcador`
  varchar(20) NOT NULL DEFAULT 'VALIDA' + `CHECK`; tabela nova `rodada_marcador`
  (PK composta, FK `ON DELETE CASCADE`, `CHECK` dos 10 códigos e `rodada >= 1`).
  Enum `TagSerie` numa fonte só no domínio; o `CHECK` sai dele. Sem backfill:
  registros antigos ficam `VALIDA` pelo default.
- **API:** `DefinirAlvos` aceita `marcadores` (só ≠ VALIDA; reduzir séries corta
  as rodadas maiores); detalhe da ficha devolve as tags. Séries da sessão
  (criar/editar/detalhe) recebem e devolvem `marcador`; ausente = VALIDA.
  FluentValidation: código fora da lista ou rodada fora de [1, séries] → 400.
  Pré-preenchimento da tag acompanha a origem das séries (ficha → última sessão
  → VALIDA). Gráfico PBI-20 **inalterado**.
- **Front:** componente único `ChipTagSerie` + seletor de baixo pra cima
  (`shared/tags/`), reusado no registro (edição), no detalhe (leitura, VALIDA
  não mostra chip) e na edição da ficha (um chip por série prescrita). Cores,
  tamanhos e rótulos por token; `Semantics` "Tag da série N: Rótulo".
- **Testes:** unit (sincroniza/corta marcadores) + integração (ida-volta ficha e
  sessão, 404 outro usuário, dados antigos VALIDA, gráfico intocado) + widget
  (chip leitura/edição/seletor, herança da tag). `flutter analyze` 0;
  85 testes de widget verdes; 30 unit verdes. Integração roda no CI.

#### PBI-39 (TV-2) · Faixa de repetições na prescrição

**História:** Como atleta (e, no futuro, educador), quero prescrever uma faixa
de repetições (ex.: "8 a 12"), para a ficha refletir como a gente treina.

**Escopo:** banco + API + front. Limite superior **opcional** do volume; sem ele,
nada muda. Vale para qualquer métrica de volume (reps, tempo). Não muda o gráfico
(PBI-20) nem o volume calculado.

**API/Tabelas:** `etapa_prescrita.volume_alvo_max`. Item da ficha
(`PUT .../alvos`, `GET /treinos/{id}`) aceita/devolve `volumeAlvoMax`.
**Telas:** 10 (editar exercício da ficha), 13 (resumo). Spec:
`.kiro/specs/tv-2-faixa-repeticoes/`. **Depende de:** PBI-14.

**Status:** ✅ na `main` (PR #56). Branch
`feat/pbi-39-faixa-repeticoes`.
- **Banco:** migration `FaixaRepeticoes` — coluna `volume_alvo_max`
  numeric(9,2) NULL + `CHECK (volume_alvo_max IS NULL OR >= volume_alvo)`. Sem
  backfill (registros antigos ficam sem faixa).
- **API:** `DefinirAlvos`/detalhe da ficha aceitam/devolvem `volumeAlvoMax`.
  Validação: `>= 0`, `>= volumeAlvo`, e exige `volumeAlvo` quando o máximo vem →
  400. Pré-preenchimento sem histórico continua usando o mínimo (`volume_alvo`).
  Resumo do plano no detalhe mostra a faixa ("3 × 8 a 12 com 30 kg").
- **Front:** campo "até (opcional)" ao lado do alvo de volume, com validação
  local; resumo e exibição por `formatarVolumeAlvo` ("8 a 12 reps" / "10 reps" /
  "30 a 45 s"). Gráfico intocado.
- **Testes:** unit (grava faixa + validator) + integração (ida-volta, 400
  max<min e max sem min, dados antigos nulo) + widget (resumo com/sem faixa,
  helper). `flutter analyze` 0; 91 widget verdes; 31 unit verdes. Integração no CI.

---

#### PBI-40..43 (TV-3 a TV-6) · Treino ao vivo, série por série (Release 2)

**História:** Como atleta, quero conduzir o treino ao vivo — marcar série por
série, ajustar carga/reps na hora, descansar com cronômetro e fechar com um
resumo — para registrar enquanto treino, sem depender da memória depois.

**Escopo:** só front (o único toque no back é o endpoint de leitura do
histórico). Entregue atrás da flag `TREINO_AO_VIVO` (`core/flags.dart`), numa
branch única `feat/treino-ao-vivo-r2`, porque TV-3/4/5/6 só fecham um treino
quando estão todas prontas. Evolui o PBI-37 (rascunho local, autosave, duração
automática, diálogos de sair/continuar), não reescreve.

- **TV-3 (tela 14 + check por série):** `TreinoAoVivoController` (Notifier)
  segura o estado vivo (exercícios em edição, início, check `feita` por série),
  espelhado no rascunho a cada mudança (autosave). Tela 14 com cronômetro vivo
  (tempo por `agora − início`, nunca tick a tick — sobrevive à aba em segundo
  plano), contador N/M e card por exercício. Clock injetável (`core/relogio.dart`)
  para o tempo ser testável.
- **TV-4 (tela do exercício):** `ExercicioAoVivoScreen` série por série, com
  navegação anterior/próximo e três abas — Séries (completar série, tag TV-1,
  `StepperMetrica` com passo por métrica: CARGA ±2,5 / REPS ±1 / TEMPO ±5 / ZONA
  ±1 (1–5) / DIST ±100), Histórico (3 últimas sessões, obs em laranja) e Evolução
  (gráfico reutilizado da aba Progresso). Novo endpoint de leitura
  `GET /exercicios/{id}/historico?limite=3`.
- **TV-5 (descanso):** `DescansoController` + `BarraDescanso`. Dispara ao
  completar série **só quando a ficha informa descanso**; descanso nulo não
  dispara (decisão do PO). Tempo por `fim − agora`, botões −15s/+15s/Pular.
- **TV-6 (resumo):** `ResumoTreinoScreen` com volume total (Σ carga × reps das
  feitas), status por exercício (Completo / Incompleto N/M / Não realizado),
  data e duração editáveis e observação. Salva só as séries feitas e encerra o
  treino; falha de rede mantém o rascunho. "Voltar ao treino" não perde nada.
- **Flag ligada:** "Iniciar treino agora" (Fichas) e "Continuar treino"
  (Início) abrem a tela 14 quando `TREINO_AO_VIVO=true`; desligada, seguem no
  registro atual (tela 3).

**Telas:** 14 (treino ao vivo), tela do exercício, 16 (resumo). Spec:
`.kiro/specs/treino-ao-vivo-r2/`. **Depende de:** PBI-15, PBI-18, PBI-37,
PBI-38, PBI-20.

**Status:** ✅ na `main` (PR #57; flag ligada nos PRs #58 a #61). Era: front + endpoint de histórico, atrás da flag, aguardando
merge. Branch `feat/treino-ao-vivo-r2`. `flutter analyze` 0; 115 widget verdes;
31 unit backend verdes; integração do histórico no CI (Testcontainers).

### Épico Planos: vários por atleta (PBI-44 a PBI-49)

Épico concluído (a PBI-48 fechou no E7). As decisões do PO e as
regras do plano em uso estão no [MAS](MAS.md) (ADRs) e no [MER](MER.md)
(seção 5). O que entrou em cada PR está em
[HISTORICO-DE-ALTERACOES.md](HISTORICO-DE-ALTERACOES.md).

| PBI | Título | Toca em | Release | Status |
|---|---|---|---|---|
| PBI-44 | Vários planos por atleta: banco e API | Banco + API | R1 | ✅ na `main` (PR #67) |
| PBI-45 | Lista de planos (tela 18) | Front | R1 | ✅ na `main` (PR #72) |
| PBI-46 | Detalhe do plano (tela 19) | Front | R1 | ✅ na `main` (PR #73) |
| PBI-47 | Início segue o plano em uso | Front | R1 | ✅ na `main` (PR #74) |
| PBI-48 | Plano do professor: leitura e cópia | Front | R2 | ✅ na `main` — educador monta plano/ficha para o aluno (PBI-88d: #128 back, #129 front) |
| PBI-49 | Adicionar exercícios: seletor revisado | Front | avulsa | ✅ na `main` (PR #81), sem esperar o E2E |

### Ajustes de layout (PBI-57 a PBI-67)

Onze pedidos do PO em 15/10 (rodadas 1 a 4), todos concluídos. O que entrou em
cada PR está em [HISTORICO-DE-ALTERACOES.md](HISTORICO-DE-ALTERACOES.md).

| PBI | Título | Telas | Status |
|---|---|---|---|
| PBI-57 | Ficha enxuta: só edição da ficha aberta | 22 | ✅ na `main` (PR #77) |
| PBI-58 | Renomear e excluir como ícones no topo | 19 e 22 | ✅ na `main` (PR #76) |
| PBI-59 | Início nova: semana e caixas | 23 | ✅ na `main` (PR #79), sem o atalho "Iniciar treino" (dispensado pelo PO) |
| PBI-60 | Dicas de treino na Início (era "caixa de novidades") | 23 | ✅ na `main` (PR #80) |
| PBI-61 | Treinar a partir do plano | 19 | ✅ na `main` (PR #77) |
| PBI-62 | Cartão de exercício: mover e excluir | 22 | ✅ na `main` (PR #77) |
| PBI-63 | Finalizar treino: seta só sai, botões encerram | 24 e 25 | ✅ na `main` (PR #78, #82 e #83) |
| PBI-64 | Depois de salvar: Início com aviso, sem diálogo | 23 | ✅ na `main` (PR #85) |
| PBI-65 | Concluir exercício e ir para o próximo | 26 | ✅ na `main` (PR #85) |
| PBI-66 | Bug: trocar de exercício não deve resetar a aba | 26 | ✅ na `main` (PR #84) |
| PBI-67 | Bug: treino em andamento invisível ao voltar | 19 e 23 | ✅ na `main` (PR #86) |

PBI-57, 62 e 61 vão juntas: a 57 tira os botões de treinar da ficha e a 61 os
devolve no plano. Separadas, haveria um deploy sem como treinar uma ficha.
Notas de implementação: token novo `dangerSoft` (fundo do remover); as ações
"Mover para cima/baixo" são as da própria lista reordenável, com os textos em
português em `core/localizacao/material_pt.dart`; `adicionarFicha` passou a
devolver o id da ficha criada (a API já devolvia).

PBI-63, notas (rodadas 2 e 3): a seta e o voltar do sistema só levam à Início,
sem diálogo; o treino segue em andamento. "Finalizar treino" vai direto ao Resumo, sem
diálogo. O aviso "Salvar treino vazio?" fica no "Salvar treino" do Resumo e
substitui a trava silenciosa da PBI-33 ("Marque ao menos uma série"): sem
séries, só salva com "Salvar mesmo assim" (a API já aceitava sessão vazia).
Descartar pelo diálogo do Resumo fecha o Resumo e a tela do treino, de volta
ao plano. O botão primário da barra segue "FINALIZAR TREINO" em caixa alta
(estilo `button`), o mesmo rótulo que o Robot usa. Descartar volta para a tela
de onde o treino começou (o plano, quando iniciado pelo play da PBI-61).

PBI-59, notas: tocar em qualquer dia não futuro (hoje inclusive) abre a folha
do dia; escolher uma ficha abre o registro de treino já feito naquela data, e
"Sem ficha" abre o treino livre com a data (o treino livre passou a aceitar o
dia). "Último treino" e a semana vêm das sessões recentes (~60 dias): sem
sessão nesse período, o cartão não aparece. `InicioLogica.proximaFicha` saiu
(sem uso); `ultimaVezPorFicha` fica, usada no plano e na ficha.

PBI-64 e 65, notas: salvar (Resumo ou registro) vai à Início com o aviso
"Treino salvo" e a ação "Ver treino" (shared/aviso_treino_salvo.dart); o
diálogo "Treino registrado" e dialogo_pos_registro.dart saíram. O push do
detalhe só acontece no toque, com a Início já aberta. "Concluir exercício"
grava a marca concluido no exercício (também no rascunho do aparelho;
rascunhos antigos abrem como não concluído) e o Resumo mostra "Concluído N/M".
Sem nenhuma série feita, continua "Não realizado". A tela do treino sai sozinha
quando o treino é encerrado (descartado na barra ou no Resumo).
**Robot:** os passos que tocam em "Ir para o Início" ou esperam "Treino
registrado" depois de salvar precisam esperar a Início e o aviso "Treino salvo".


PBI-67, notas: `treinoEmAndamentoProvider` deriva do treino ao vivo
(`rascunhoDoEstado`) e, sem ele, do rascunho do aparelho; a Início e o plano
deixam de depender de invalidação. O plano destaca a ficha em andamento
(borda primária, "Em andamento" com cronômetro, botão "Continuar"). Play em
outra ficha abre "Treino em andamento" com "Voltar" e "Continuar {ficha}":
nunca há dois treinos abertos. Tokens novos `AppSizes.borda` e
`AppSizes.bordaDestaque`.

### Correções e fluxos de entrada (PBI-67 a PBI-72)

Pedidos do PO em 16/10, com as respostas dele, todos concluídos (PR #86 a #91).

| PBI | Título | Telas | Status |
|---|---|---|---|
| PBI-70 | Telas atualizam pela origem da mudança | todas | ✅ na `main` (PR #88) |
| PBI-67 | Treino em andamento visível ao voltar | 19 e 23 | ✅ na `main` (PR #86); o ponto único de aviso veio com a 70 |
| PBI-68 | Início e Planos sem plano: cada aba com a sua tela | 23, 27 e 29 | ✅ na `main` (PR #89) |
| PBI-69 | Criar plano e primeira ficha em um caminho só | 27, 28 e 19 | ✅ na `main` (PR #89) |
| PBI-71 | Registrar treino sempre à mão na Início | 23 e 29 | ✅ na `main` (PR #90) |
| PBI-72 | Manter na ficha o exercício adicionado no treino? | 25 | ✅ na `main` (PR #91) |

PBI-70, notas: as telas gravam por `fichasComandosProvider`,
`sessaoComandosProvider` e `catalogoComandosProvider`; cada comando chama o
repositório e depois `invalidarDerivados` (`lib/core/dados/invalidacao.dart`),
o único lugar que invalida. "Tentar de novo" usa `ref.refresh` da própria
leitura. O rascunho do treino avisa por `versaoRascunhoTreinoProvider` (o
Riverpod não deixa invalidar quem depende do serviço). Um teste de
arquitetura falha se aparecer `invalidate(` fora do mapa ou escrita direta no
repositório fora dos comandos. Escritas que não avisavam ninguém foram
corrigidas junto: alvos e exercícios da ficha (plano e rascunho do registro
ficavam velhos), sessão (aba Progresso e histórico do exercício) e "Salvar
também como ficha". `fichaTemSessoesProvider` foi para `sessao_repository.dart`.

PBI-68 e 69, notas: o Bem-vindo (`PrimeiroAcessoScreen(plano:)`) só aparece
na Início para conta nova; a aba Planos vazia tem a tela 27. Criar plano tem um
caminho só, `criarPlanoEAbrir` (`planos/acoes_plano.dart`): diálogo "Novo
plano" com "Meu plano" sugerido e `go` para o detalhe, de qualquer aba (a pilha
fica lista → detalhe, então a seta volta à lista). O detalhe do plano vazio
mostra "Nenhuma ficha ainda" com "Nova ficha" e esconde o "Duplicar". Saíram o
"MONTAR MINHAS FICHAS", o "MONTAR FICHAS" do detalhe sem plano e o estado
vazio "CRIAR FICHA" da tela Fichas, que agora volta ao plano quando não há
ficha para abrir. O "Montar fichas" da Início (plano vazio com histórico) abre
o detalhe do plano. **Robot:** "Registrar sem ficha" virou "Registrar treino";
"MONTAR MINHAS FICHAS" e "CRIAR FICHA" não existem mais (o caminho é "Criar meu
plano" → "Criar plano" → "Nova ficha" → "Salvar").

PBI-71, notas: a linha "Registrar treino" (56 px, rótulo falado "Registrar
treino") fica logo abaixo da semana, sempre visível. Com plano em uso e
fichas, abre o sheet "Qual treino?" com as fichas que têm exercícios (a
contagem vem do `fichaDetalheProvider`, o mesmo do plano) e "Sem ficha"; sem
plano ou com plano vazio, vai direto ao treino livre. A ficha abre o registro
de treino já feito com hoje como padrão (dá para trocar por um dia passado).
O "Registrar treino" do Bem-vindo já abria o treino livre desde a PBI-68.
**Robot:** o passo depois do cadastro toca em "Registrar treino" (Bem-vindo);
para quem já tem plano, "Registrar treino" → "Sem ficha" leva ao treino livre.

PBI-72, notas: `POST /sessoes` ganhou `manterNaFicha` (ids de exercícios). O
serviço acrescenta cada um no fim da ficha (`treino_exercicio` com rodadas =
séries salvas, até 12, e descanso da última; uma `etapa_prescrita` de esforço
com a intensidade e o volume da última série) e grava sessão e ficha no mesmo
`SaveChanges`, uma transação só: não existe "sessão salva, ficha não". Recusa
com 400 id que não seja de exercício fora da ficha com séries nesta sessão, id
que já está na ficha, treino livre e o `PUT` de edição; ficha do professor dá
403 e de outro usuário, 404, antes de gravar qualquer coisa. Sem migration (só
tabelas existentes). `GET /treinos/{id}` passou a dizer `somenteLeitura`, que o
app usa para não perguntar em ficha do professor. No app,
`perguntarManterNaFicha` (`sessao/manter_na_ficha.dart`) é chamada pelo Resumo
e pelo registro de treino já feito; o Resumo mostra a etiqueta "Fora da ficha".
O histórico da sessão continua marcado como fora da ficha.

---

## 9. Épicos futuros (ainda não refinados)

Estão aqui para dar visão do caminho. Nenhum atende a Definition of Ready ainda.

| Épico | Itens previstos |
|---|---|
| **E7 · Modo educador** ✅ *concluído (PBI-85 a 89 e 48; ver nota abaixo)* | Papel de educador; convite e aceite de vínculo; lista de alunos; ver treino e progresso do aluno; montar ficha para o aluno; exportar progresso em PDF; termo de consentimento LGPD; alerta de aluno sem registrar ou com observações de dor seguidas. **Decisão (PO, histórico):** virou um épico próprio; a PBI-48 (plano do professor) entra junto. Ver nota abaixo da tabela. |
| **E8 · Inteligência no feedback** | Músculos secundários e cartão "séries por músculo na semana" (base no ADR-10); Tags rápidas na observação; recorde pessoal e 1RM estimado; sugestão de aumento de carga |
| **E9 · Corrida avançada** | Faixas de zona por atleta; importação de arquivo do relógio ou Strava |
| **E10 · Lojas** | Publicação na Google Play; avaliação de custo e processo da App Store |
| **E12 · Corpo e medidas** ⏳ *(PBI-91 a 96; ver a seção do épico abaixo)* | Medidas do corpo por dia, gráfico de evolução, TMB e compartilhamento com o educador por cadeado. |
| **E11 · Conforto no registro** | Cronômetro de descanso dentro do registro (o treino ao vivo já tem descanso, PBI-90; falta confirmar com o PO o que resta no registro posterior) |

**Nota sobre o E7 (registro histórico; o épico foi entregue):** o modo
educador fica para a **próxima sprint**, como um **épico próprio**, refinado antes
de entrar. Pontos já combinados para o refinamento:

- **Login único.** Não há login separado para professor: a identidade continua no
  Firebase e o que muda é o **papel** no Postgres (`usuario_papel`, ATLETA e/ou
  EDUCADOR). Uma pessoa pode ter os dois. O app escolhe as telas pelo papel.
- **Já existe só a estrutura:** papel `EDUCADOR`, tabela `vinculo`
  (PENDENTE/ATIVO/ENCERRADO), regra única de acesso (`IControleAcesso`: o próprio
  atleta ou educador com vínculo ativo) e plano de autor ≠ atleta como somente
  leitura (403, PBI-44).
- **Virou PBI (entregue):** tornar-se educador, convite e aceite de vínculo, lista de
  alunos, ver treino e progresso do aluno, montar plano para o aluno, termo de
  consentimento LGPD (antes de qualquer acesso do educador), PDF e a PBI-48.
- **Decisões do PO (tomadas, 31/10):**
  - **O aluno pode esconder uma observação do educador: SIM.** O atleta marca uma
    observação como privada e o educador não a vê (nem no app, nem no PDF). Exige
    uma flag de privacidade na observação da sessão (mudança de banco).
  - **O educador perde o histórico quando o vínculo acaba: NÃO apaga, mas perde o
    acesso.** Nada do aluno é apagado; o educador simplesmente deixa de ver os
    dados quando o vínculo sai de ATIVO (é o que o `IControleAcesso` já faz). Se o
    vínculo for reativado, volta a ver. (Não há "cópia" do histórico para o
    educador.)
  - **O que vai no PDF:** os **treinos (sessões registradas) e as evoluções
    (gráficos de progresso por exercício)** do período. Respeita a privacidade:
    observação marcada como privada não entra.
  - **Excluir plano do professor depois do fim do vínculo: SIM.** Encerrado o
    vínculo, o aluno pode excluir da sua lista o plano que o professor montou
    (premissa da PBI-48).

### Épico E7 · Modo educador — PBIs refinadas (31/10)

Ordem do fundamento ao visível. A estrutura de dados (papel `EDUCADOR`, tabela
`vinculo`) e a regra de acesso (`IControleAcesso`) já estão na `main`; estas PBIs
dão vida ao educador. Login é único (ADR-04): muda o **papel**, não o login.
**Progresso:** ✅ **épico concluído** — PBI-85 a 89 na `main` (PRs #120 a #131),
incluindo a PBI-48 (plano do professor) e o PDF do progresso.

#### PBI-85 · Tornar-se educador e vínculo com aluno (convite/aceite) — backend

**História:** Como educador, quero convidar um aluno e, com o aceite dele, ter um
vínculo ativo, para então acompanhar os treinos dele — e encerrar o vínculo
quando o acompanhamento acabar.

**Contexto:** a tabela `vinculo` (PENDENTE/ATIVO/ENCERRADO) e o papel `EDUCADOR`
já existem no banco; o `IControleAcesso` já libera "educador com vínculo ATIVO".
Falta o caminho que cria e muda o vínculo, e o que concede o papel `EDUCADOR`
(hoje o `GET /me` só provisiona `ATLETA`). Esta PBI é só backend; as telas vêm na
PBI-88.

**Critérios de aceite**
- Virar educador: um usuário ganha o papel `EDUCADOR` (endpoint dedicado, ex.
  `POST /me/papeis/educador`), idempotente; `GET /me` passa a devolver os papéis.
- `POST /vinculos` — educador (com papel `EDUCADOR`) convida um aluno por e-mail;
  cria `vinculo` PENDENTE. 409 se já existe vínculo aberto (respeita
  `ux_vinculo_aberto`); 400 se o convite for para si mesmo (`educador ≠ aluno`);
  404 se o e-mail não existe (sem revelar se existe — mensagem neutra).
- Aceite: o aluno vê convites pendentes (`GET /vinculos/pendentes`) e aceita
  (`POST /vinculos/{id}/aceitar` → ATIVO, grava `inicio`) ou recusa
  (→ ENCERRADO). Só o aluno do vínculo aceita/recusa (senão 404).
- Encerrar: educador ou aluno encerram um vínculo ATIVO
  (`POST /vinculos/{id}/encerrar` → ENCERRADO, grava `fim`). Fora do vínculo: 404.
- `GET /alunos` — alunos com vínculo ATIVO do educador logado.
- Validação: `educador_id` precisa ter papel `EDUCADOR` (regra do MER 3.3).

**Notas técnicas:** `ServicoVinculo` + `VinculoEndpoints`; `IRepositorioVinculo`
ganhou escrita/consulta; `POST /me/papeis/educador` concede o papel. `TentarCriarAsync`
tolera a corrida no índice `ux_vinculo_aberto` (409, não 500). Sem mudança de banco.
**Depende de:** PBI-07 (feito). **Prioridade:** alta (fundação do E7).
**Status:** ✅ na `main` (backend, PR #120). A UI veio na PBI-88 (#125 a #129). Testes de
integração cobrem fluxo feliz, 403/400/404/409 e o caso "outro usuário" → 404.

#### PBI-86 · Educador vê treino e progresso do aluno — backend

**História:** Como educador com vínculo ativo, quero ver os treinos e a evolução
do aluno, para orientar o acompanhamento.

**Critérios de aceite (preliminares)**
- Os endpoints de dados de atleta (planos, sessões, progresso) aceitam o
  `atletaId` opcional na query (MAS 12); sem ele, vale o usuário logado. A regra
  11.3 é aplicada sempre (educador com vínculo ATIVO ou dono; senão 404).
- Teste do caso "outro usuário / vínculo encerrado" → 404 em cada endpoint.
**Depende de:** PBI-85. **Prioridade:** alta.
**Status:** ✅ na `main` (backend, PR #122). `atletaId` opcional em `GET /planos`,
`/planos/ativo`, `/sessoes`, `/progresso/exercicios`, `/progresso/exercicios/{id}`,
`/exercicios/{id}/historico` e `/ultima-execucao` (as rotas por-id já checavam o
dono). Disponibilidade de exercício avaliada pelo aluno-alvo (decisão do PO:
educador vê os exercícios próprios do aluno). Testes incluem 404 sem vínculo e
com vínculo encerrado.

#### PBI-87 · Observação privada e consentimento LGPD

**História:** Como atleta, quero poder marcar uma observação como privada (o
educador não vê) e dar consentimento antes de qualquer acesso do educador, para
proteger dados sensíveis.

**Critérios de aceite (preliminares)**
- Flag de privacidade na observação da sessão (**mudança de banco** + migration).
  Observação privada não vai para o educador (API) nem para o PDF.
- Tabela `consentimento (usuario_id, versao_termo, aceito_em)` (MER 3.13); o
  acesso do educador só é liberado após o aceite do termo pelo aluno.
**Depende de:** PBI-85. **Prioridade:** alta (bloqueia o acesso real do educador).

**Status:** ✅ **backend completo na `main`** (duas partes).
- Parte 1 (#124): `sessao.observacao_privada` (migration `ObservacaoPrivadaEConsentimento`),
  gravada no POST/PUT `/sessoes` (`observacaoPrivada`, padrão false) e **ocultada
  do educador** (logado ≠ atleta) no detalhe, histórico e progresso; tabela
  `consentimento` criada (estrutura + entidade + índice único por usuário/versão).
- Parte 2 (**PBI-88a**): **consentimento gravado no aceite do convite** (decisão
  do PO, opção 1: aceitar o convite é o ato de consentir). O `POST
  /vinculos/{id}/aceitar` registra o consentimento da versão vigente do termo na
  mesma transação do vínculo ATIVO (idempotente). **Sem gate global** no
  `IControleAcesso` — o vínculo ATIVO já é a prova do consentimento, então nada
  do que já estava na main (PBI-85/86) quebra. O texto do termo e a tela de
  aceite entram com as telas do educador (PBI-88).

#### PBI-88 · Telas do educador (lista de alunos, treino/progresso, montar ficha)

A PBI-88 foi **fatiada** em entregas menores (PRs: 87 e 88a #124/#125, 88b #126, 88c #127, 88d #128 back e #129 front):
- **88a** ✅ backend do consentimento no aceite (ver Status da PBI-87 acima).
- **88b** ✅ **telas do educador no app** (front): seção "Educador" no Perfil com
  gate por papel (quem não é educador vê "Ativar modo educador"; quem é vê "Meus
  alunos" e "Convidar aluno"; "Convites recebidos" para todos, com contagem de
  pendentes). Feature `features/educador/` no padrão da casa (repository +
  comandos + models + telas), invalidação via `Mudanca.vinculos`. Aceitar um
  convite passa pela **tela do termo de consentimento** (texto provisório)
  antes de efetivar; recusar encerra. Telas empilhadas a partir do Perfil
  (`/perfil/alunos`, `/perfil/convites`). 324 testes verdes; analyze 0.
- **88c** ✅ **ver treino e progresso do aluno** (front): tocar num aluno abre a
  `AlunoDetalheScreen` com a **evolução por exercício** (seletor + gráfico
  reusando `grafico_exercicio`) e as **sessões recentes** (30 dias), tocar numa
  sessão abre o detalhe existente (que já aplica o acesso por vínculo e oculta a
  observação privada). Providers próprios do educador por `atletaId` (consome a
  PBI-86 com `?atletaId=`), sem tocar nas telas do atleta. 327 testes; analyze 0.
- **88d** — montar ficha para o aluno; fecha a **PBI-48**. Fatiada em back e front:
  - **88d-back** ✅ **backend**: `POST /planos` aceita `atletaId` no corpo e cria o
    plano do aluno com `autor = educador` (nova sobrecarga
    `CriarPlanoNomeadoAsync(usuarioLogado, atleta, nome)` que passa pelo
    `IControleAcesso`). As fichas reusam `POST /planos/{id}/treinos`. A regra de
    somente-leitura virou "quem escreve é o autor" (`autor_id != usuarioLogado`,
    antes `!= atleta_id`): o educador edita o plano que montou; o aluno só lê/treina
    (403); sem vínculo o acesso responde 404, nunca 403 (MAS 11.3). Sem mudança de
    banco. Unitários + integração cobrindo os três casos (criar+ficha 201, sem
    vínculo 404, autor edita × aluno 403). 54 unitários verdes; build 0/0.
  - **88d-front** ✅ **UI do educador montando a ficha**: no detalhe do aluno
    (PBI-88c), um cartão "Planos e fichas" abre a `AlunoPlanosScreen` (planos do
    aluno + "Criar plano", que grava com autor = educador). Abrir um plano leva à
    `AlunoPlanoDetalheScreen` (fichas + "Nova ficha"); tocar numa ficha reusa o
    editor do atleta (`FichasScreen` por `treinoId`: adicionar exercícios e
    definir alvos), que o backend autoriza pelo vínculo — sem parametrizar as
    telas do atleta. `FichasRepository` ganhou `atletaId` opcional em
    `criarPlano`/`listarPlanos`/`obterDetalhePlano`; providers-família próprios do
    aluno (`planosDoAlunoProvider`, `planoDoAlunoDetalheProvider`) entram no mapa
    de invalidação (`Mudanca.planos`), sem mexer nos providers do atleta logado.
    Rotas empilhadas sob `/perfil/alunos/aluno/planos`. 332 testes verdes
    (327 + 5); analyze 0. **Fecha a PBI-48.**

> **Termo de consentimento:** o texto exibido na tela de aceite é **provisório**
> (marcado no código); o conteúdo jurídico final será definido com o PO antes do
> lançamento do modo educador.

**História:** Como educador, quero telas para ver meus alunos, o treino e a
evolução de cada um e montar ficha para eles, para acompanhar de verdade pelo app.

**Critérios de aceite (preliminares)**
- O app escolhe as telas pelo papel (`usuario_papel`); quem é só atleta não vê
  nada de educador. Troca/contexto de papel para quem tem os dois.
- Lista de alunos; abrir aluno mostra treino e progresso (consome a PBI-86).
- Montar ficha para o aluno grava o plano com `autor = educador` (fecha a PBI-48,
  cujo lado do aluno — ler/copiar plano do professor — já existe).
**Depende de:** PBI-85, PBI-86, PBI-87. Inclui a **PBI-48**.

#### PBI-89 · Exportar progresso em PDF

**História:** Como atleta, quero exportar meus treinos e evoluções em PDF; e como
educador, quero exportar os de um aluno — para registrar/compartilhar o
acompanhamento. **(Decisão do PO: vale para os dois.)**

**Critérios de aceite**
- `GET /api/v1/progresso/pdf?de=&ate=&atletaId=` gera o PDF com as **evoluções por
  exercício** e as **sessões** do período. Observação privada do aluno não entra.
  Vale para o próprio atleta e, com `atletaId`, para o educador com vínculo ATIVO
  (regra 11.3; sem acesso → 404). Sem `de`/`ate`, os últimos **90 dias**
  (configurável pelos parâmetros).

**Status (89-back):** ✅ **backend** feito. Endpoint devolve `application/pdf`
(`Results.File`), primeiro binário da API. PDF gerado com **QuestPDF** (licença
Community) na Infrastructure, atrás da porta `IGeradorRelatorioPdf` (Application);
`ServicoRelatorio` reusa `ServicoProgresso` e `ServicoSessao`, então acesso e
privacidade já vêm tratados. Build 0/0; 54 unitários verdes + 3 testes do gerador
(geram `%PDF`); integração (`ProgressoPdfEndpointTests`) cobre atleta 200, educador
com vínculo, sem vínculo 404 e sem token 401 (roda no CI).

**Status (89-front):** ✅ **front** feito. Botão "Exportar PDF" (ícone download)
no AppBar da aba **Progresso** (atleta, usa o período selecionado) e da tela do
aluno (educador, passa o `atletaId`). `ProgressoRepository.baixarProgressoPdf`
busca os bytes (Dio `responseType: bytes`); o download é disparado no navegador
por um helper com import condicional (`package:web`: Blob + link `<a download>`),
com stub que lança fora do web — os testes (VM) compilam sem tocar em APIs de
navegador. `flutter analyze` 0; suíte 334 verde (+2 testes do botão).

**PBI-89 concluída (back + front).** Com ela, o **épico E7 (modo educador) está
completo**: papel, vínculo/convite/consentimento, telas do educador, ver dados do
aluno, montar plano/ficha e exportar o progresso em PDF.

**Depende de:** PBI-86, PBI-87. **Prioridade:** média.

### Épico E12 · Corpo e medidas (pedido do PO, 09/11)

> O atleta registra peso e medidas do corpo no ritmo dele, vê a evolução num gráfico,
> calcula a taxa metabólica basal e decide, com um cadeado, se o educador pode ver.

Protótipos: canvas "Telas App de Treino", telas 22 a 29 (Clara e Escura). **Substitui** o
desenho antigo "perfil corporal" (peso único em `usuario`): peso virou medida com histórico
e o gráfico e o compartilhamento entraram no escopo; seis PBIs pequenas (91 a 96).

**Decisões do épico (a confirmar com o PO na revisão):**
1. Perfil não ganha campos: ganha o bloco "Corpo" com duas linhas, "Dados corporais" e "Medidas corporais".
2. 12 tipos de medida, nenhuma obrigatória: peso, pescoço, ombros, peito, cintura, quadril, braço D/E, coxa D/E, panturrilha D/E. Para salvar um dia basta um valor.
3. Peso tem histórico (tipo `PESO`, kg). A TMB usa sempre o peso mais recente.
4. Tudo começa **trancado**. Dados corporais e medidas são destrancados separadamente; destrancado, todo educador com vínculo ativo vê, só leitura. Trancar corta o acesso na hora.
5. TMB: Mifflin-St Jeor, no backend, só para 18 anos ou mais.
6. Uma medição por dia: salvar de novo no mesmo dia atualiza.
7. Fora do PDF do progresso, mesmo compartilhado.

**Regras de dados e privacidade (valem nas seis):** só o dono lê e grava, sob `/me`; o educador só
lê, por rotas próprias `/alunos/{atletaId}/...` (PBI-95); nenhum valor corporal em log, mensagem de
erro ou `GET /me`; `DELETE /me` apaga tudo (cascata). Os textos "Só você vê" e de compartilhamento
dependem do texto jurídico do termo de consentimento (hoje provisório).

| PBI | Título | Camada | Depende de | Status |
|---|---|---|---|---|
| PBI-91 | Medidas corporais: banco e API | back | — | ✅ na `main` (PR #137) |
| PBI-92 | Medidas corporais no app (Perfil, lista, registrar) | front | 91 | ✅ na `main` (PR #138) |
| PBI-93 | Dados corporais e TMB (`PerfilCorporal`) | back + front | 91, 92 | ✅ feito (ver abaixo) |
| PBI-94 | Gráfico de evolução da medida | back + front | 91, 92 | ✅ feito (ver abaixo) |
| PBI-95 | Compartilhamento com o educador: back (`CompartilhamentoCorporal`) | back | 91, 93 | ⏳ (aguarda perguntas 1 e 2) |
| PBI-96 | Compartilhamento: cadeado e visão do educador | front | 92, 93, 94, 95 | ⏳ (aguarda perguntas 1 e 2) |

#### PBI-91 · Medidas corporais: banco e API
**História:** Como atleta, quero que o app guarde as minhas medidas por dia, para consultar e comparar depois.
**Critérios de aceite**
1. `PUT` com dois tipos cria só esses dois registros; os outros tipos continuam sem registro.
2. `PUT` no mesmo dia atualiza, sem criar duplicata.
3. A variação de cada tipo compara com a medição anterior dele, mesmo que as outras medidas tenham sido feitas em outras datas.
4. Dia sem nenhum valor, data futura, tipo inválido e valor fora da faixa respondem 400.
5. Usuário B não enxerga nem altera as medidas do A. Sem token, 401.
6. `DELETE /me` apaga as medidas.

**Status:** ✅ na `main` (PR #137). Migration `MedidaCorporal` (tabela `medida_corporal`, MER 3.15; `CHECK` de tipo e `valor > 0`, único `(usuario_id, data, tipo)`, cascata do usuário); `GET /me/medidas`, `GET|PUT|DELETE /me/medidas/{data}` (MAS 12); `ServicoMedidas` com `MontarUltimas` (variação por tipo), `SalvarMedidasValidator` (erro na chave do tipo, sem repetir o valor) e `TipoMedida` como fonte única dos 12 tipos e das faixas. Build 0/0; 84 unitários verdes (+22); integração (`MedidaEndpointTests`: upsert, remoção por nulo, dia vazio 400, variação com lacunas, `DELETE` do dia, validações, 401, outro usuário, `DELETE /me`, esquema) roda no CI. A data usa o dia UTC do servidor, sem a tolerância de "amanhã" do registro de treino.
**Fora do escopo:** front, gráfico, compartilhamento, TMB.

#### PBI-92 · Medidas corporais no app
**História:** Como atleta, quero registrar e consultar minhas medidas pelo Perfil, sem lotar a tela.
**Escopo:** bloco "Corpo" no Perfil (entre Conta e Tema) com "Dados corporais" (a linha só entra com a PBI-93) e "Medidas corporais" (resumo "Última em 05/11 · cintura 84,0 cm" ou "Nenhuma medida ainda"); tela "Medidas corporais" (tela 24: "Registrar medidas", cartão "Últimas medidas" com valor, unidade e variação com seta e sinal, nunca só cor, "Sem registro", nota "A variação compara com a medição anterior de cada medida.", histórico por dia); tela "Registrar medidas" (tela 25: dia da medição, hoje por padrão, passado sim, futuro não; grupos Corpo todo, Tronco, Braços e Pernas; todos opcionais; campos **vazios** com a ajuda "última: 84,0"; vírgula ou ponto; aberta pelo histórico vem preenchida e ganha "Excluir medição" com confirmação); salvar sem valor avisa "Preencha ao menos uma medida"; `mostrarAviso`/`mostrarErro` (PBI-75); escrita por `MedidasComandos` e `Mudanca.medidas` em `invalidarDerivados`; estados carregando, erro com "Tentar de novo" e vazio; 44 px; 360 px e fonte 1,3x nos dois temas; rótulos falados ("Cintura, em centímetros"; "caiu 1,5 centímetro").
**Status:** ✅ na `main` (PR #138). Pasta `features/medidas/`: modelos (`TipoMedida` com os 12 tipos e as faixas do back), repositório (`/me/medidas`), `MedidasComandos` e `Mudanca.medidas` (invalida resumo e dia aberto). Perfil: bloco **CORPO** entre o educador e o Tema, com uma linha "Medidas corporais" e o resumo ("Última em 05/11 · cintura 84,0 cm" ou "Nenhuma medida ainda"); sem campos novos no Perfil e sem a linha "Dados corporais" (vem com a PBI-93). Rotas filhas do Perfil `/perfil/medidas` e, em tela cheia, `/perfil/medidas/registrar`. Tela "Medidas corporais": "Registrar medidas", últimas medidas dos 12 tipos com valor, unidade e variação com seta e sinal (`Igual` quando zero), "Sem registro", a nota da variação e o histórico por dia. Tela "Registrar medidas": dia (hoje; passado sim, futuro não), grupos Corpo todo/Tronco/Braços/Pernas, campos vazios com a ajuda "última: 84,0", vírgula ou ponto, erro no próprio campo, "Salvar medidas" e "Cancelar"; aberta pelo histórico vem preenchida, o dia não muda, esvaziar um campo remove só aquela medida e há "Excluir medição" com confirmação. Salvar sem valor avisa "Preencha ao menos uma medida". Linha de cada tipo ainda sem toque (o gráfico é da PBI-94). Widget compartilhado novo `CampoData` (`shared/`). Cada linha da lista é um item próprio para o leitor de tela, com a variação por extenso ("caiu 1,5 centímetros"). `flutter analyze` 0; 390 testes verdes, 27 novos em `medidas_test.dart`. O Perfil ficou mais alto: dois testes dele passaram a usar tela alta.

#### PBI-93 · Dados corporais e TMB
**História:** Como atleta, quero informar sexo, nascimento, altura e peso para ver quantas calorias meu corpo gasta em repouso.
**Escopo:** migration `PerfilCorporal` (`usuario.sexo` M/F, `data_nascimento`, `altura_cm` 100 a 250; peso vem da medida `PESO` mais recente); função pura de domínio Mifflin-St Jeor (`10×kg + 6,25×cm − 5×idade + s`, s = +5 M / −161 F, arredondado; nula faltando dado ou com menos de 18; conferência: M, 31, 180 cm, 78,0 kg = 1.755; F, 31, 165 cm, 60,0 kg = 1.315); `GET|PUT|DELETE /me/perfil-corporal` (o `PUT` com `pesoKg` grava a medida de hoje; o `DELETE` não apaga o histórico de peso; `GET /me` não muda); tela 23 com os três estados do cartão (calculada, incompleta, menor de idade).
**Status:** ✅ back + front feitos. **Back:** migration `PerfilCorporal` (`usuario.sexo` char(1), `data_nascimento`, `altura_cm`, com `CHECK` de sexo e de altura; MER 3.1 e regra 16); `CalculoTmb` no domínio (função pura, Mifflin-St Jeor; conferências 1.755 e 1.315); `ServicoPerfilCorporal`; `GET|PUT|DELETE /me/perfil-corporal` (MAS 12). O peso vem de `IRepositorioMedida.UltimoValorAsync`; o `PUT` com `pesoKg` grava a medida PESO no mesmo `SaveChanges`; o `DELETE` preserva o histórico de peso; `GET /me` não muda (teste confere as chaves). Acréscimo ao desenho: o `PUT` aceita `dataPeso` opcional, porque à noite no Brasil o "hoje" do servidor (UTC) já é amanhã e o peso cairia no dia errado. Build 0/0; 109 unitários (+25: fórmula, idades 17/18, 29/02, validador); integração (`PerfilCorporalEndpointTests`: ida e volta, TMB M e F, menor de idade, dado faltando, peso criado/atualizado/com data, histórico intacto sem `pesoKg`, peso novo muda a TMB, peso mais recente por data, limpar, 400, 401, outro usuário, `GET /me`, `DELETE /me`, `CHECK` do banco) roda no CI. **Front:** linha "Dados corporais" no Perfil ("78 kg · 180 cm · TMB 1.755 kcal por dia" ou "Preencha para calcular sua TMB"), rota `/perfil/dados-corporais` e tela com a linha "Só você vê estes dados.", sexo (grupo "Sexo, para o cálculo", dá para desmarcar), nascimento (seletor limitado a 10 a 100 anos, idade na ajuda), altura, peso e o cartão **Taxa metabólica basal** nos três estados (calculada, incompleta, menor de idade) com o número da API (sem conta no app); "Salvar" e "Limpar dados corporais" com confirmação (o histórico de peso fica). **O peso só é enviado quando o campo muda**, para salvar a altura não criar um ponto de peso falso. `Mudanca.perfilCorporal` e `Mudanca.medidas` agora também atualizam os dados corporais, e vice-versa. `CampoData` passou a quebrar linha em vez de estourar com fonte grande. `flutter analyze` 0; 417 testes verdes, 27 novos em `dados_corporais_test.dart`.

#### PBI-94 · Gráfico de evolução da medida
**História:** Como atleta, quero ver num gráfico como cada medida e o meu peso mudaram.
**Escopo:** `GET /me/medidas/{tipo}/evolucao?de=&ate=` (`pontos`, `primeira`, `ultima`, `variacao`; vazio não é erro); tela 26 com filtros 30 dias, 90 dias (padrão), 1 ano e Tudo; eixo **não começa do zero**; ponto único sem linha; toque no ponto com alvo de 44 px; rótulo falado com início, fim e variação e lista "Registros do período" como alternativa em texto; reaproveitar o gráfico de `progresso_screen.dart` (fl_chart 1.0.0).
**Status:** ✅ back + front feitos. **Back:** `GET /me/medidas/{tipo}/evolucao?de=&ate=` (MAS 12): pontos em ordem de data, limites inclusive, `primeira`/`ultima`/`variacao` (última − primeira), período sem registro = lista vazia, tipo inválido e `de` > `ate` = 400, só o dono. `ServicoMedidas.MontarEvolucao` é função estática testável. Sem migration. 114 unitários (+5); integração (`MedidaEvolucaoEndpointTests`: ordem, peso em kg, só o tipo pedido, limites inclusive, um ponto, vazio, 400, 401, outro usuário) roda no CI. **Front:** a linha de uma medida **com registro** abre a tela de evolução (rota `/perfil/medidas/evolucao`, empilhada; a linha "Sem registro" continua sem ação e sem seta); título da medida, filtros "30 dias", "90 dias" (padrão), "1 ano" e "Tudo", três cartões (Primeira, Última, Variação com seta e sinal), gráfico de linha com **eixo que não parte do zero** (faixa dos dados + folga, mesmo com valores iguais), eixo X por dia real, ponto único só como ponto, toque no ponto com alvo de 44 px (tooltip e linha "05/11/2026 · 84,0 cm") e a lista **Registros do período** em texto, do mais recente ao mais antigo. Estados: carregando e erro ("Tentar de novo") dentro da mesma caixa de altura fixa, e "Sem registros neste período". Reaproveita `CaixaGrafico` e `MensagemGrafico` do gráfico de exercício; a `LineChart` é própria (o do exercício é por sessão e tem observação). O peso usa a mesma tela, em kg. O gráfico tem rótulo falado ("Cintura de 87,0 centímetros em 10/08 para 84,0 centímetros em 05/11, queda de 3,0 centímetros"). `Mudanca.medidas` e `Mudanca.perfilCorporal` atualizam o gráfico aberto (salvar um peso nos dados corporais também). `flutter analyze` 0; 438 testes verdes, 21 novos (19 em `medida_evolucao_test.dart`).

#### PBI-95 · Compartilhamento com o educador: back
**História:** Como atleta, quero decidir se o meu educador vê meus dados e medidas corporais.
**Escopo:** migration `CompartilhamentoCorporal` (`usuario.dados_corporais_compartilhados_em` e `medidas_compartilhadas_em`; nulo = trancado); `GET|PUT /me/compartilhamento-corporal`; para o educador, `GET /alunos/{atletaId}/corpo` (seções trancadas voltam nulas) e `GET /alunos/{atletaId}/medidas/{tipo}/evolucao` (403 `corpo-nao-compartilhado` se trancado). Ordem: sem vínculo ATIVO, 404 (MAS 11.3); depois o gate, 403. Vínculo encerrado, recusado ou pendente não vê nada. O educador nunca grava; o PDF segue sem dado corporal. **TMB (PBI-98):** o cadeado de "Dados corporais" cobre também a TMB; o educador com acesso vê o valor efetivo e se ele foi informado pelo atleta (`tmbManual`). Teste da matriz educador (ATIVO, PENDENTE, ENCERRADO, sem vínculo) × cadeado.
**Status:** ⏳ aguarda as perguntas 1 e 2.

#### PBI-96 · Compartilhamento: cadeado e visão do educador
**História:** Como atleta, quero um cadeado simples para liberar ou trancar o meu corpo; como educador, quero ver o corpo do aluno quando ele liberar.
**Escopo:** selo "Privado"/"Compartilhado" nas telas 23, 24 e 26; tela "Compartilhar" (tela 27) com dois interruptores, lista de quem vê e aviso de que sem vínculo ativo ninguém vê; **destrancar pede confirmação, trancar não**; para o educador, linha "Corpo" na tela do aluno, tela 28 (somente leitura, dados e últimas medidas, evolução sem edição; a TMB mostra o valor efetivo com o selo "Informada pelo aluno" quando for o caso, PBI-98) e tela 29 (trancado, seções independentes); 403 na evolução cai no estado trancado.
**Status:** ⏳ aguarda as perguntas 1 e 2.

#### PBI-97 · Campo de data: toque no campo inteiro e digitação com barras automáticas (pedido do PO, 11/11)
**História:** Como atleta, quero tocar em qualquer ponto do campo de data para escolher o dia, e poder digitar a data sem me preocupar com as barras, para não ficar procurando ano e mês no calendário. Só front. Pedido ao testar a "Data de nascimento" em Dados corporais (PBI-93).
**Critérios de aceite**
1. Tocar em qualquer ponto do campo (borda, rótulo, texto ou ícone) abre o seletor, no iPhone Safari e no Chrome.
2. Digitar `26051995` no seletor resulta em `26/05/1995` sem digitar barra, e confirmar grava a data.
3. Digitar `26/05/1995` com as barras continua funcionando.
4. Apagar e corrigir no meio da data não trava a máscara.
5. Data inexistente ou fora da faixa mostra erro e não grava.
6. Campo vazio mostra `dd/mm/aaaa`.
7. As quatro telas (nascimento, dia da medição, dia em que treinou no registro e no resumo) se comportam igual.
8. 360 px e fonte 1,3x, nos dois temas; alvo de 44 px; o leitor de tela anuncia o valor e que dá para trocar.

**Status:** ✅ feito (front), com uma ressalva: o item 1 foi verificado no Chrome, **não no Safari do iPhone** (não há como rodá-lo aqui) e precisa de conferência do PO depois do deploy.
- **Causa do toque (reproduzida no Chrome com a árvore de semântica ligada):** o nó de semântica do campo cobre o campo todo (358×48 px no teste), mas **não tinha a ação "tocar"**. O `Semantics(excludeSemantics: true)` do ``CampoData`` (PBI-92) escondia o ``InkWell`` e não tinha ``onTap`` próprio. O toque por ponteiro funcionava no Chrome (7 de 7 pontos), mas um clique entregue ao nó de semântica (o caminho de leitor de tela e de navegadores que entregam o toque ao nó) **não fazia nada** (contador 0 → 0). Os campos antigos do registro e do resumo não tinham esse ``Semantics`` e por isso funcionavam. Correção: ``onTap`` no próprio nó. Depois dela, o clique de semântica passa a abrir (0 → 1) e cada toque por ponteiro continua abrindo uma vez só (sem disparo duplo). Além disso, o seletor ignora uma segunda abertura enquanto já há um aberto.
- **Causa da digitação:** o `showDatePicker` do SDK não serve. O app não tem locale pt-BR (``DefaultMaterialLocalizations``, inglês), então o campo de digitação dele lê **mm/dd/aaaa** (``26/05/1995`` seria "mês 26") e o ``InputDatePickerFormField`` não aceita ``inputFormatters``. Por isso foi construído um **seletor próprio** (``escolherData``): diálogo com calendário (o ``CalendarDatePicker`` do SDK) e campo de texto com máscara, com botão sempre à vista para alternar. Lê dd/mm/aaaa, teclado numérico, erro sem fechar (data que não existe, incompleta, fora da faixa) e OK/Cancelar.
- **Máscara** (``MascaraDataFormatter``): só dígitos; a barra entra sozinha ao completar dia e mês de quem digita; para no ano completo (8 dígitos, o resto é cortado); colar com ou sem barras dá o mesmo (``2605`` colado vira ``26/05``); apagar a barra leva o dígito anterior (``26/`` vira ``2``) e apagar um dígito não recoloca a barra; colar por cima de uma data inteira troca tudo.
- **Um componente só:** ``CampoData`` (``shared/``) substitui as duas cópias privadas ``_CampoData`` (registro de treino e resumo). Vazio mostra ``dd/mm/aaaa`` em cor de dica; rótulo falado "Data de nascimento: 26/05/1995. Toque para trocar" (vazio: "sem data. Toque para escolher"); altura mínima de 44 px.
- **Telas:** nascimento abre direto em digitação (faixa de 10 a 100 anos); dia da medição (não futuro) e dia em que treinou (até amanhã, como hoje) abrem no calendário. Faixas inalteradas.
- **E2E:** ``fluxo_pbi26_test.dart`` não toca no campo de data; sem impacto.
- ``flutter analyze`` 0; 491 testes verdes, 53 novos (``campo_data_test.dart`` e os das telas).
**Fora do escopo:** mudar o formato de exibição, seletor com visual novo, internacionalização de formato de data.
#### PBI-98 · TMB calculada que o atleta pode editar (pedido do PO, 12/11)
**História:** Como atleta, quero que a taxa metabólica basal apareça calculada sozinha, mas poder trocar pelo valor que eu sei (bioimpedância, nutricionista ou outro método), para não ficar preso à estimativa da fórmula.
**Regra:** a calculada continua sendo a padrão e acompanha peso, altura, nascimento e sexo. Enquanto houver valor informado, ele vale em todo o app; o atleta volta ao cálculo quando quiser; o informado não some quando os dados mudam.
**Critérios de aceite**
1. Com os dados completos, a TMB aparece calculada sozinha, como hoje.
2. "Editar", informar 1.800 e salvar mostra 1.800 com o selo "Informada por você" e a linha "Calculada: 1.755".
3. Mudar o peso ou a altura depois não muda o 1.800, mas atualiza a linha "Calculada".
4. "Usar o cálculo" volta ao número calculado e o selo some.
5. Sem dados completos, ainda dá para informar; aparece sem a linha "Calculada".
6. Fora de 800 a 5.000, vazio ou não inteiro é recusado com mensagem e nada é gravado.
7. O resumo do Perfil e o cartão mostram sempre o mesmo valor.
8. "Limpar dados corporais" apaga sexo, nascimento, altura e a TMB informada, e mantém o histórico de peso.
9. 360 px e fonte 1,3x, nos dois temas.

**Status:** ✅ back + front feitos. **Back:** migration ``TmbManual`` (``usuario.tmb_manual_kcal`` smallint nula, ``CHECK`` 800 a 5000; MER 3.1 e regra 17); ``CalculoTmb.ValorEfetivo`` e ``ManualNaFaixa`` no domínio (a ``ResultadoTmb`` já separava valor e motivo, então a fórmula não mudou); ``GET /me/perfil-corporal`` devolve ``tmbKcal`` efetivo, ``tmbCalculadaKcal`` e ``tmbManual`` (o único consumidor de ``tmbKcal`` é o app; o PDF não usa a TMB); ``PUT|DELETE /me/perfil-corporal/tmb-manual`` (rota própria, MAS 12); ``DefinirTmbManualValidator`` com o valor em ``decimal`` para o quebrado virar 400 com mensagem; ""Limpar dados corporais"" limpa o informado. Build 0/0; 129 unitários (+15); integração (``TmbManualEndpointTests``: ida e volta, efetivo/calculado/manual, sobrevive a mudar os quatro dados, ``DELETE`` volta ao automático, 400 nas faixas e no quebrado, sem dados completos, menor de idade, limpar, 401, outro usuário, ``DELETE /me``, ``CHECK`` do banco) roda no CI. **Front:** o cartão ganhou ""Editar"" (lápis, 44 px) em todos os estados; diálogo ""TMB, em kcal por dia"" já preenchido, só dígitos, com ""Salvar"", ""Usar o cálculo"" (só com valor informado) e ""Cancelar"", erro ""Use um valor entre 800 e 5.000 kcal.""; estados calculada, informada (selo ""Informada por você"" e ""Calculada: 1.755 kcal"" quando há cálculo), informada sem cálculo e sem valor nenhum. Salvar a TMB não envia nem apaga o que está digitado no formulário. Resumo do Perfil: ""TMB informada 1.800 kcal por dia"". O texto de ""Limpar dados corporais"" avisa que a TMB informada também sai. Rótulo falado ""Taxa metabólica basal, 1.800 kcal por dia, informada por você. Calculada, 1.755"" e o botão ""Editar"". ``flutter analyze`` 0; 509 testes verdes (+18). **Ordem das migrations:** ``TmbManual`` vem antes da ``CompartilhamentoCorporal`` (PBI-95, ainda não feita); o cadeado de dados corporais passa a cobrir a TMB (anotado nas PBIs 95 e 96).
**Fora do escopo:** outras fórmulas, histórico e gráfico da TMB, gasto total e metas, aviso quando o informado se afasta do calculado.

#### PBI-100 · Bug: a ficha mostra o valor antigo depois de salvar os alvos (relato do PO, 12/11)
**Relato:** depois de salvar as séries de um exercício, a ficha continua mostrando "1 série"; voltando ao plano e reabrindo a ficha, aparece o valor certo.
**Critérios de aceite**
1. Salvar 4 séries e voltar à ficha mostra "4 séries" na hora.
2. Vale também para volume, carga, descanso e instrução.
3. O plano continua certo.
4. Chrome, Safari do iPhone e modo educador.
5. Reabrir, recarregar a página e rede lenta.

**Status:** 🟡 **não reproduzido**; entregue endurecimento e testes de regressão. **Investigação:** as quatro hipóteses do PO foram testadas. (1) Cache: a API fica direto no `fly.dev`, sem CDN, e a resposta de produção não trazia `Cache-Control`, `ETag` nem `Last-Modified`; não havia causa provada, mas também nada impedia o navegador de guardar a resposta. (2) Corrida: o `PUT .../alvos` só responde 204 depois do `SaveChanges`, e o app só relê depois do 204. (3) `watch` perdido (pausa do Riverpod 3 com a ficha por baixo da tela de alvos): a ficha relê e mostra o valor novo em widget test, no app inteiro com o go_router de verdade e em Chrome real contra a stack real (Postgres, API e Auth Emulator). (4) Outro provider: a tela de alvos é aberta de um único ponto e invalida `Mudanca.planos`, que cobre `fichaDetalheProvider`. **Feito:** a API responde **toda** requisição com `Cache-Control: no-store` e `Pragma: no-cache` (`SemCacheMiddleware`; MAS 12). Dado de saúde não deve ir para cache, e isso elimina a hipótese 1 em qualquer navegador, inclusive o Safari. **Testes:** integração `SemCacheEndpointTests` (PUT dos alvos seguido do GET da ficha, três vezes, com séries, descanso e instrução; `no-store` nas leituras, no 204, 404, 400 e 401); widget `pbi100_ficha_defasada_test.dart` (ficha sozinha, rede lenta de 300 ms, plano por baixo também observando a ficha) e `pbi100_fluxo_app_test.dart` (app inteiro, a releitura vem depois do PUT e já traz 4); E2E `alvos_ficha_pbi100_test.dart` (1 → 4 → 5 séries no Chrome) no job `e2e` do CI. A `PostgresFixture` aceita `TESTES_POSTGRES` (Postgres local, banco único por execução, apagado no fim) para rodar a integração sem Docker; no CI segue o Testcontainers. Build 0/0; 129 unitários; 232 de integração; `flutter analyze` 0; 513 testes do front (+4). **Falta:** conferir no Safari do iPhone, que não havia aqui. Se o bug continuar depois do deploy, saber em qual navegador e se foi no modo educador, e capturar a aba Rede (Web Inspector do Mac ligado ao iPhone) no momento de salvar. A próxima medida seria reler a ficha à força (`ref.refresh`) ao voltar da tela de alvos; não foi feita agora porque esconderia um problema que não se provou.
**Fora do escopo:** atualização otimista e mudança na estratégia de invalidação (PBI-70).

### Épico E13 · Exercícios conjugados (pedido do PO, 12/11)

O PO monta fichas em que alguns exercícios são feitos juntos, alternando, com um descanso só depois de cada rodada. Ficha real (Mobilidade de ombro): (1) 2x25" prancha lateral + 4x15 elevação pélvica, sem descanso; (2) 3x20" adução com a bola + 3x15 agachamento livre, 30" de descanso; (3) 3x10 subida no caixote unilateral, 30"; (4) 3x12 afundo, 40"; (5) 2x30" isometria + 10 panturrilha no leg. **Regras:** o bloco tem 2 a 4 exercícios da mesma ficha, sempre vizinhos; tem tantas rodadas quanto o maior número de séries entre os membros, e cada um participa até a sua última série (item 1: rodadas 3 e 4 só com a elevação); a unidade continua por exercício; o descanso é do bloco (0 a 600 s, ou nenhum) e dispara uma vez por rodada; exercício sozinho continua igual. **Interpretações (o PO pode corrigir):** "Mobilidade de ombro" é o nome da ficha; o item 5 não tem descanso e a panturrilha acompanha as 2 séries da isometria; a ordem dentro da rodada é a da ficha; "Rodada feita" marca com os valores pré-preenchidos; o descanso vale também depois da última rodada. **Fora do épico:** séries por lado, montar bloco no treino ao vivo ou no treino livre, circuito por tempo, mais de 4 exercícios, descanso entre exercícios da mesma rodada, cronômetro automático das séries de tempo. A PBI-99 não foi registrada aqui (o documento dela não chegou).

#### PBI-101 · Bloco conjugado na ficha (modelo, API e editor)
**História:** Como atleta (ou educador, na ficha do aluno), quero juntar dois ou mais exercícios da ficha num bloco, com um descanso só, para a ficha refletir como eu realmente treino.
**Critérios de aceite**
1. Dá para montar a ficha do PO inteira: itens 1, 2 e 5 como blocos e 3 e 4 avulsos.
2. O item 1 mostra "4 rodadas" e "sem descanso"; o item 2, "3 rodadas" e "descanso 30 s".
3. Mudar o descanso do bloco vale para todos os membros; o descanso do membro não aparece nem é editável.
4. Tirar um exercício de um bloco de dois desfaz o bloco, e o outro fica avulso com o descanso que o bloco tinha.
5. Reordenar move o bloco inteiro; os membros nunca ficam separados.
6. Excluir um membro, excluir a ficha e duplicar o plano mantêm os blocos consistentes.
7. O educador monta o mesmo bloco na ficha do aluno.
8. Fichas existentes continuam iguais, sem bloco.

**Status:** ✅ back + front feitos. **Modelo:** tabela própria `bloco_exercicio` (`treino_id`, `descanso_seg` com `CHECK` 0 a 600) e `treino_exercicio.bloco_id` nula (`SET NULL`); a ficha apagada leva os blocos (cascata). O descanso fica num lugar só; as rodadas são calculadas. O validador dos alvos aceita qualquer descanso ≥ 0, sem teto; o limite de 600 vale só para o bloco, para não recusar dado que já existe. **Back:** `RegrasBloco` no domínio (rodadas, contiguidade, agrupar na posição do primeiro); `POST /treinos/{id}/blocos`, `PUT|DELETE /treinos/{id}/blocos/{blocoId}` e `PUT .../membros` (a lista é a ordem dentro do bloco; quem sai fica avulso logo depois dele, com o descanso do bloco; menos de 2 desfaz); `GET /treinos/{id}` com `blocoId` por exercício e a lista `blocos`; reordenar responde 400 se separar um bloco; remover um membro de um bloco de dois desfaz; nos alvos de um membro o descanso enviado é ignorado; duplicar o plano copia os blocos. As rotas do educador são as mesmas (o `IControleAcesso` libera pelo vínculo); outro usuário, 404. Build 0/0; 140 unitários (+11, `RegrasBlocoTests`); 251 de integração (+19, `BlocoConjugadoEndpointTests`: a ficha do PO, juntar não vizinhos, descanso e limites, desfazer, adicionar, reordenar e tirar membros, excluir membro, reordenar que separa, 400 nos limites, bloco de outra ficha, outro usuário em todas as rotas, educador, cascata, duplicar, ficha antiga sem bloco). **Front:** o bloco é um cartão só com barra lateral, "Conjugado · 4 rodadas · descanso 30 s" (ou "sem descanso"), a alça que arrasta o bloco inteiro, "Descanso" e "Desfazer bloco" (com confirmação) e os exercícios empilhados com o resumo sem o descanso. "Juntar com o de baixo" (elo, 44 px) no avulso abre o sheet "Descanso depois de cada rodada" (segundos ou "Sem descanso", 0 a 600) e "JUNTAR"; acima de um bloco, o avulso entra nele; o bloco com menos de 4 também junta o avulso de baixo. Cada membro tem um menu com "Mover para cima/baixo", "Tirar do bloco" e "Remover da ficha". No membro, o editor de alvos troca o campo de descanso por "O descanso é definido no bloco.". Escrita pelos comandos com `invalidarDerivados(Mudanca.planos)`; os 4 métodos novos entraram no teste de arquitetura. Rótulo falado "Bloco conjugado, 4 rodadas, descanso 30 segundos, 2 exercícios". A contagem do plano continua por exercício. `flutter analyze` 0; 530 testes verdes (+17, `bloco_conjugado_ficha_test.dart`: a ficha do PO nos dois temas, rótulo falado, juntar com descanso e sem descanso, limite de 600, entrar num bloco, bloco cheio, tirar do bloco, mover, descanso, desfazer, editor de alvos do membro e do avulso, 360 px com fonte 1,3x, ficha antiga). **Sem protótipo:** o cartão segue o design system; o PO confere no PR.
**Fora do escopo:** treino ao vivo com bloco (PBI-102) e histórico e cópias (PBI-103); duplicar **ficha** (a rota não existe; só duplicar plano).

#### PBI-102 · Treino ao vivo com bloco: um "feito" e um descanso por rodada
**História:** Como atleta, quero marcar a rodada do bloco como feita de uma vez e ter um descanso só, para não dar dois toques e esperar dois cronômetros.
**O que construir:** rascunho do treino (`GET /treinos/{id}/rascunho-sessao` e `ExercicioEdicao`) com o bloco e a posição; tela 14 com o bloco num cartão só e "2 de 4 rodadas"; tela do bloco com "Rodada 2 de 4", os exercícios da rodada com os campos de série e o botão "Rodada feita" (o check por série continua); descanso uma vez, quando a última série da rodada fica marcada, com o descanso do bloco (nada se for nulo ou 0); desmarcar cancela o descanso que estiver correndo; rodadas desiguais mostram só quem participa; "Concluir bloco"; treino livre e exercício adicionado no meio continuam avulsos. **Gravar:** uma série por exercício, como hoje; o descanso do bloco só na última série da rodada. Para a PBI-103 reconstruir o bloco sem depender da ficha atual: `serie_executada.bloco` e `serie_executada.posicao_no_bloco` (`smallint` nulos), na migration desta PBI. **Rascunho local:** os campos novos entram opcionais (rascunho antigo abre como hoje; hoje um campo obrigatório ausente apaga o rascunho sem aviso) e a rodada atual é calculada pelas marcações, não gravada.
**Critérios de aceite:** como no documento do PO (item 2 dispara 30 s e passa à rodada 2; itens 1 e 5 avançam sem cronômetro; rodadas 3 e 4 do item 1 só com a elevação; uma série marcada não dispara, a segunda sim; "Continuar treino" volta na mesma rodada; histórico e gráfico por exercício iguais; 360 px, fonte 1,3x, dois temas, 44 px; leitor de tela "Rodada 2 de 4, adução com a bola e agachamento livre").
**Notas:** o registro de uma vez (`TREINO_AO_VIVO` desligado) mostra os membros separados, como hoje. O E2E novo roda com a flag ligada, num drive próprio.
**Status:** ✅ back + front feitos. **Back:** migration `SerieBloco` (`serie_executada.bloco` e `posicao_no_bloco`, `smallint` nulas, `CHECK` "os dois juntos, posição 1 a 4"); `POST|PUT /sessoes` aceitam e gravam os dois por série (validador com regras separadas) e o detalhe devolve; `GET /treinos/{id}/rascunho-sessao` traz `blocoId` por exercício e a lista `blocos` (a mesma montagem da ficha). Build 0/0; 140 unitários; 259 de integração (+8, `SessaoBlocoEndpointTests`: rascunho com e sem bloco, sessão do item 2 com uma série por exercício ligada ao exercício certo e o descanso só no último da rodada, editar mantém o bloco, 400 nos quatro casos de bloco incompleto ou fora da faixa). **Front:** `bloco_ao_vivo.dart` com as regras sem tela (grupos da tela 14, rodadas = maior número de séries, séries da rodada, rodada fechada, rodada atual pelas marcações, descanso só se > 0, descanso ao salvar, rótulo falado). Tela 14 com o cartão "CONJUGADO", os nomes, a barra por rodada e "2 de 4 rodadas". Tela do bloco nova (`BlocoAoVivoScreen`, rota `/fichas/ao-vivo/bloco`): "Rodada 2 de 4" com setas de rodada, "Descanso de 30 s depois de cada rodada" (ou "Sem descanso entre as rodadas"), os exercícios da rodada com os steppers e o check de 44 px, "RODADA FEITA", "Concluir bloco" (ou "Concluir e ir ao resumo"). O descanso dispara quando a última série da rodada fica marcada; desmarcar uma série de rodada fechada encerra o descanso. As setas e o "Concluir" contam o bloco como um item só, também na tela do exercício avulso. **Rascunho local:** `blocoId` por exercício e o descanso de cada bloco, opcionais (rascunho antigo abre como avulso); a rodada atual não é gravada, sai das marcações. **Salvar:** o Resumo manda cópias das séries com o descanso do bloco só na última feita de cada rodada (as outras vazias) e o repositório numera os blocos da sessão e as posições. Leitor de tela: "Rodada 2 de 3, adução com a bola e agachamento livre". `flutter analyze` 0; 552 testes verdes (+22, `bloco_ao_vivo_test.dart`: regras, rascunho com bloco e rascunho antigo, tela 14, itens 1, 2 e 5, uma série não dispara e a segunda sim, desmarcar cancela, "Concluir bloco", bloco no fim, seta do avulso para o bloco, rótulo falado, 360 px com fonte 1,3x nos dois temas). **E2E:** `bloco_ao_vivo_pbi102_test.dart` (ficha com dois exercícios criados na hora num bloco de 30 s → play → "Iniciar treino agora" → duas rodadas → salvar, conferindo na API bloco, posições e descanso) entrou no job `e2e` com `TREINO_AO_VIVO=true`; os três E2E passaram localmente no Chrome contra a stack real, num banco limpo. **Atenção:** rodados de novo sobre o mesmo banco, o do bloco e o da PBI-26 falharam uma vez; no CI o banco nasce limpo e cada alvo roda uma vez (mais o retry).
**Fora do escopo:** o detalhe da sessão agrupado e o histórico (PBI-103).

#### PBI-103 · Bloco no histórico, nas cópias e na visão do educador
**História:** Como atleta e como educador, quero ver no histórico e nas cópias o que foi feito junto, para o bloco não "desmanchar" fora do treino.
**O que construir:** detalhe da sessão com os membros agrupados rodada a rodada e o descanso uma vez; histórico e progresso por exercício sem mudança de número; educador vê a ficha e a sessão do aluno agrupadas; sessões antigas como hoje. Duplicar o plano já copia os blocos (PBI-101); "Salvar como ficha" fica avulso.
**Critérios de aceite:** a sessão do item 2 mostra adução e agachamento em 3 rodadas com "descanso 30 s"; o gráfico de carga do agachamento tem os mesmos pontos que teria avulso; sessão antiga abre igual.
**Status:** ⏳ a fazer (depende da PBI-102).
---

## 10. Perguntas em aberto que bloqueiam PBIs

| Pergunta | Bloqueia | Com quem |
|---|---|---|
| A zona é definida por frequência cardíaca, pace ou percepção de esforço? | PBI-27 a PBI-29 | Vinicius |
| Rodada a mais ou incompleta no intervalado: como aparece no feedback? | PBI-29 | Vinicius |
| Lista de membros e músculos está boa para o uso de vocês e para reabilitação? **Não bloqueia** (a lista entrou; ajuste por migration) | PBI-31 | Vinicius |
| Nome definitivo do app | PBI-04 (domínio) | Vitor e Vinicius |
| Trocar a métrica: (a) por série no registro ou (b) no alvo da ficha? Recomendação: (a) | PBI-34 | PO |
| Gráfico só de repetições: melhor série (implementado) ou total da sessão? | PBI-73 | PO |
| Texto jurídico do termo de consentimento (hoje provisório) | PBI-87 / abrir ao público | PO |
| E12: compartilhar com todos os educadores com vínculo ativo ou escolher por educador? Recomendação: todos, por enquanto | PBI-95, 96 | PO |
| E12: o educador vê os dados corporais (sexo, idade, altura, peso, TMB) ou só as medidas? O cadeado separa os dois, padrão trancado | PBI-95, 96 | PO |
| E12: o PDF do progresso leva as medidas quando compartilhadas? Recomendação: não agora | futura | PO |
| E12: a lista de 12 medidas atende? Pescoço e ombros podem sair | PBI-91, 92 | PO |
| E12: os textos de privacidade (Só você vê e o aviso de compartilhamento) passam pelo texto jurídico do termo | PBI-92, 96 | PO |

---

## 11. Proposta de Sprints (proposta inicial; o que de fato entrou, PR por PR, está no [HISTORICO](HISTORICO-DE-ALTERACOES.md))

Sprints de uma semana, com review no fim de semana usando o app no celular do PO. O Sprint Goal e a seleção final saem da Sprint Planning; abaixo é só um ponto de partida para a conversa.

| Sprint | Sprint Goal sugerido | PBIs |
|---|---|---|
| 1 | O app está publicado e o atleta entra com a própria conta | 01, 02, 03, 04, 06, 07, 08 |
| 2 | O atleta monta suas fichas com alvos | 10, 11, 12, 13, 14 |
| 3 | O atleta registra o primeiro treino de verdade | 15, 16, 17, 18 |
| 4 | O atleta vê a evolução e entende cada queda | 20, 21, 22, 23, 31, 32 |
| 5 | MVP pronto para uso diário | 05, 09, 19, 24, 25, 37, 26 |

A Sprint 1 é a mais pesada em infraestrutura e a de maior risco. Se não couber, o corte natural é deixar o login com Google (parte da PBI-08) para a Sprint 2 e manter o resto, porque publicar logo é o que libera o feedback do PO.
