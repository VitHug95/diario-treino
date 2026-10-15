# Treino ao vivo (Release 2) — Requisitos

> Épico "Treino ao vivo, série por série" (pós-MVP), **Release 2**: TV-3, TV-4,
> TV-5, TV-6. Fonte: PDF do épico (p. 8-17). Uma branch só
> (`feat/treino-ao-vivo-r2`), com o botão "Iniciar treino agora" **atrás de uma
> flag** (`treinoAoVivoHabilitado`) até o fluxo fechar ponta a ponta — as PBIs
> sozinhas não fecham um treino.
>
> **Decisões do PO:** rascunho local no aparelho (shared_preferences), vira
> sessão só ao salvar; check por série; tag é só identificação (TV-1); gráfico
> por maior carga (PBI-20); descanso sem padrão — **quando a ficha não informa
> descanso, fica nulo** (o timer de descanso não dispara).
>
> **Definição de pronto (vale para todas):** critérios de aceite + cenários
> Robot no CI; unit/integração das regras novas; tema claro/escuro, contraste
> ≥ 4,5:1, toque 44px, largura máx 600px no web; semântica em todo interativo
> (botões "anterior/próximo" obrigatórios, cronômetro com `role=timer`/
> liveRegion); observação do dia nunca em log; MER/MAS atualizados quando mexer
> em modelo/regra (aqui: nenhuma mudança de banco).
>
> **Riscos técnicos (do PDF):** timers no Flutter web — cronômetro e descanso
> **sempre calculados por horário de início/fim**, nunca tique a tique;
> vibração/som limitados no navegador (não prometer); gesto de deslizar é frágil
> no Robot → botões anterior/próximo obrigatórios; limpar o cache apaga o
> rascunho (limitação aceita).

---

## TV-3 — Iniciar treino e treino em andamento

**História:** Como atleta, quero iniciar o treino da ficha na academia e
acompanhar quanto já fiz, sem medo de perder o que marquei se fechar o app.

### Critérios de aceite
1. **Duas entradas** — na ficha, "Iniciar treino agora" e "Registrar treino já
   feito"; o segundo abre o registro atual (comportamento de hoje).
2. **Iniciar** — "Iniciar treino agora" abre o treino em andamento (tela 14) com
   o cronômetro em 00:00 e todas as séries pendentes.
3. **Cronômetro confiável** — iniciado às 19:04, app em segundo plano, volta às
   19:42 → mostra 38 min (cálculo por horário de início, não tique a tique).
4. **Sobrevive a fechar** — treino com 6 séries feitas; fecha e reabre → a Início
   mostra "Treino em andamento" com 6 feitas; "Continuar treino" volta ao estado.
5. **Finalizar com pendência** — 8 séries pendentes em 3 exercícios → aviso com
   os números; "Finalizar mesmo assim" abre o resumo (TV-6).
6. **Finalizar sem pendência** — todas feitas → resumo direto, sem aviso.
7. **Sair** — a seta abre: Finalizar agora / Continuar depois / Descartar treino
   / Cancelar; "Continuar depois" volta à Início com o cartão; "Descartar" apaga
   o rascunho.
8. **Outra ficha** — com rascunho aberto, iniciar outra ficha pergunta antes
   (continuar o aberto ou descartar e iniciar o novo).
9. **Sem servidor** — nenhuma chamada de gravação à API até salvar no resumo.

---

## TV-4 — Tela do exercício, série por série

**História:** Como atleta, quero concluir uma série de cada vez com poucos
toques, vendo o que fiz da última vez, para registrar sem atrapalhar o treino.

### Critérios de aceite
1. **Série ativa** — exercício com 2 de 4 feitas: ao abrir, a série 3 está ativa
   com "Última vez" e a 4 pendente com a sugestão.
2. **Steppers por métrica** — carga ±2,5 (35→37,5); reps ±1; tempo ±5; zona ±1
   (1–5); distância ±100. Peso corporal não tem stepper de intensidade. Tocar no
   número permite digitar.
3. **Completar** — "Completar série" marca feita, a próxima fica ativa e o
   contador da tela 14 atualiza; dispara o descanso (TV-5) quando houver.
4. **Reabrir** — tocar numa série feita a torna ativa de novo com os valores.
5. **Adicionar e remover** — "Adicionar série" copia a última; série não feita
   pode ser removida.
6. **Navegação** — "Exercício anterior/próximo" com pontos de posição; no último,
   "próximo" desabilitado. Deslizar também funciona, mas os botões são
   obrigatórios (acessibilidade/Robot).
7. **Histórico** — aba Histórico mostra as 3 últimas sessões do exercício; a com
   observação mostra a nota em laranja.
8. **Evolução** — aba Evolução mostra o mesmo gráfico da aba Progresso, filtrado
   no exercício (mesma regra PBI-20).
9. **Sem histórico** — exercício nunca registrado: sugestão vem do alvo da ficha
   e as abas mostram estado vazio explicativo.

### API
- Novo `GET /api/v1/exercicios/{id}/historico?limite=3` (leitura): as N últimas
  sessões do atleta com aquele exercício (séries + data + observação), com a
  regra do `IControleAcesso` (recurso de outro usuário / inexistente → 404).

---

## TV-5 — Descanso automático

**História:** Como atleta, quero que o descanso comece sozinho quando concluo
uma série, para não precisar de outro cronômetro.

### Critérios de aceite
1. **Abre sozinho** — exercício com descanso de 90 s: completar série abre a
   barra em 01:30 e começa a descer. **Sem descanso na ficha, a barra não abre.**
2. **Ajustes** — +15 aumenta 15 s; −15 diminui sem passar de zero.
3. **Pular** — fecha a barra; o descanso gravado é o tempo decorrido até ali.
4. **Segundo plano** — descanso de 90 s, sai 60 s e volta → faltam ~30 s
   (cálculo por horário de fim).
5. **Troca de exercício** — descanso correndo continua ao navegar.
6. **Fim** — ao zerar, a barra muda de estado e vibra onde o navegador permitir
   (iPhone fica só no visual).
7. **Nova série** — completar outra série reinicia o timer com o descanso do
   exercício.

### Registro
- O `descanso_seg` da série gravada é o tempo efetivo do timer (início até zerar
  ou Pular). Aparece editável no resumo (TV-6). Usa o campo que já existe.

---

## TV-6 — Resumo ao finalizar

**História:** Como atleta, quero revisar o treino antes de salvar, corrigir data/
duração e escrever a observação do dia, para o gráfico contar a história certa.

### Critérios de aceite
1. **Números** — 9 de 14 séries feitas: o resumo mostra 9/14 e o volume somando
   carga × reps das séries feitas com carga (peso corporal e tempo não entram).
2. **Status por exercício** — "Completo", "Incompleto N/M" ou "Não realizado".
3. **Duração** — cronômetro em 52:20 → duração vem como 52, editável.
4. **Data retroativa** — mudar a data para ontem e salvar → a sessão aparece no
   gráfico no dia de ontem.
5. **Só o que foi feito** — ao salvar, o detalhe da sessão tem só as séries
   feitas, com tag e descanso.
6. **Rascunho limpo** — depois de salvar, a Início não mostra mais "Treino em
   andamento".
7. **Voltar ao treino** — volta à tela 14 sem perder nada.
8. **Falha de rede** — mantém o rascunho, mostra o erro, "Tentar de novo" salva
   quando a rede volta.

### API/Banco
- Nenhuma mudança: usa o `POST /sessoes` que já existe, com `marcador` (TV-1) e
  `descanso_seg` (TV-5) por série.

---

## Fora de escopo (do épico)
- Calculadora de anilhas; compartilhar resumo; recordes pessoais; som ao fim do
  descanso; notificação com o app fechado; sincronizar rascunho entre aparelhos;
  imagens/vídeos dos exercícios.
