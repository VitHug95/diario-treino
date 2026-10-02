# Product Backlog

**Projeto:** Diário de Treino (nome provisório)
**Versão:** 0.1, antes da primeira Sprint
**Documentos relacionados:** [MAS.md](docs/MAS.md), [MER.md](docs/MER.md), [README.md](README.md), protótipo no canvas "Telas App de Treino"

---

## 1. Product Goal

> O atleta registra o treino quando puder e entende a própria evolução sem perder o motivo de cada dia fora da curva.

O incremento 1 entrega isso para o modo atleta (musculação e isometria). O incremento 2 acrescenta cardio. O modo educador vem depois, sobre a estrutura que já nasce pronta.

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
- não tem pergunta em aberto que bloqueie (seção 9);
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
- Usuário sem plano vê a tela de primeiro acesso (tela 6) em vez da tela inicial.
- Botão "Montar minhas fichas" leva para as fichas.
- Botão "Registrar sem ficha" leva para o treino livre.
- Depois que existe ao menos uma ficha ou sessão, a tela não aparece mais.

**Depende de:** PBI-08. O destino do segundo botão depende de PBI-19.

### Épico E2: Catálogo de exercícios

#### PBI-10 · Buscar exercício no catálogo
**História:** Como atleta, quero encontrar rápido o exercício que fiz, para montar a ficha ou registrar o treino sem digitar tudo.

**Critérios de aceite**
- Lista o catálogo global mais os exercícios criados pelo próprio usuário.
- Busca por nome sem diferenciar maiúsculas e acentos.
- Filtro por modalidade: Todos, Força, Isometria, Cardio.
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
**Em aberto:** métrica de força (maior carga ou volume total). Ver seção 9.

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

#### PBI-25 · Perfil e conta
**História:** Como atleta, quero ver meus dados, sair da conta e poder excluí-la, para ter controle sobre o que fica guardado.

**Critérios de aceite**
- Tela de Perfil com nome, e-mail e opção de tema.
- Sair encerra a sessão no Firebase e volta ao login.
- Excluir conta pede confirmação digitada, apaga os dados no banco e o usuário no Firebase.
- Exclusão coberta por teste de integração.

**Depende de:** PBI-08.

#### PBI-26 · Teste E2E do fluxo principal
**História:** Como time, queremos um teste automatizado do caminho mais importante, para publicar sem medo de quebrar o que já funciona.

**Critérios de aceite**
- Suíte Robot Framework com Browser library rodando contra o app web.
- Cenário: entrar, registrar um treino da ficha A com observação, abrir o progresso e ver o ponto com a observação.
- Roda no CI antes do deploy, com um usuário de teste próprio.

**Depende de:** PBI-21.

---

## 7. Incremento 2: Cardio

> Só entra em refinamento depois da resposta do Vinicius sobre como a zona é definida (seção 9).

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

## 8. Épicos futuros (ainda não refinados)

Estão aqui para dar visão do caminho. Nenhum atende a Definition of Ready ainda.

| Épico | Itens previstos |
|---|---|
| **E7 · Modo educador** | Papel de educador; convite e aceite de vínculo; lista de alunos; ver treino e progresso do aluno; montar ficha para o aluno; exportar progresso em PDF; termo de consentimento LGPD; alerta de aluno sem registrar ou com observações de dor seguidas |
| **E8 · Inteligência no feedback** | Tags rápidas na observação; recorde pessoal e 1RM estimado; sugestão de aumento de carga |
| **E9 · Corrida avançada** | Faixas de zona por atleta; importação de arquivo do relógio ou Strava |
| **E10 · Lojas** | Publicação na Google Play; avaliação de custo e processo da App Store |
| **E11 · Conforto no registro** | Cronômetro de descanso dentro do registro |

---

## 9. Perguntas em aberto que bloqueiam PBIs

| Pergunta | Bloqueia | Com quem |
|---|---|---|
| O gráfico de força usa maior carga da sessão ou volume total (carga × repetições)? | PBI-20 | Vinicius |
| A zona é definida por frequência cardíaca, pace ou percepção de esforço? | PBI-27 a PBI-29 | Vinicius |
| Rodada a mais ou incompleta no intervalado: como aparece no feedback? | PBI-29 | Vinicius |
| O aluno pode esconder uma observação do educador? | E7 | Vinicius |
| Nome definitivo do app | PBI-04 (domínio) | Vitor e Vinicius |

---

## 10. Proposta de Sprints

Sprints de uma semana, com review no fim de semana usando o app no celular do PO. O Sprint Goal e a seleção final saem da Sprint Planning; abaixo é só um ponto de partida para a conversa.

| Sprint | Sprint Goal sugerido | PBIs |
|---|---|---|
| 1 | O app está publicado e o atleta entra com a própria conta | 01, 02, 03, 04, 06, 07, 08 |
| 2 | O atleta monta suas fichas com alvos | 10, 11, 12, 13, 14 |
| 3 | O atleta registra o primeiro treino de verdade | 15, 16, 17, 18 |
| 4 | O atleta vê a evolução e entende cada queda | 20, 21, 22, 23 |
| 5 | MVP pronto para uso diário | 05, 09, 19, 24, 25, 26 |

A Sprint 1 é a mais pesada em infraestrutura e a de maior risco. Se não couber, o corte natural é deixar o login com Google (parte da PBI-08) para a Sprint 2 e manter o resto, porque publicar logo é o que libera o feedback do PO.
