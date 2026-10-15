# Post-mortem — "O Release 2 não aparecia em produção" + nota sobre o E2E Robot

> **Status: RESOLVIDO.** Este documento começou como um pedido de análise independente
> enquanto o problema estava em aberto; agora é o registro histórico do caso, com a
> causa raiz confirmada e a solução aplicada. Mantido em `docs/` para referência futura.

---

## Resumo em uma frase

O código do Release 2 (treino ao vivo) estava **correto o tempo todo**; o que impedia de
aparecer em produção era a **publicação**: o Netlify (plano Free) estava com os **deploys
de produção pausados por falta de créditos no mês**, servindo um build antigo. A solução
foi **migrar o front para o Cloudflare (Workers Static Assets)**.

---

## Linha do tempo da investigação (o que parecia × o que era)

1. **Sintoma:** após mergear o Release 2, o site continuava mostrando o fluxo antigo de
   registro, mesmo em janela anônima.
2. **1ª hipótese (parcialmente certa):** a flag `TREINO_AO_VIVO` não estava sendo passada
   no build. → Corrigido no `netlify.toml` (3 iterações) e, por fim, mudando o
   **default da flag para `true`** no código (`app/lib/core/flags.dart`), para não depender
   de `--dart-define` no deploy.
3. **2º bug real encontrado:** a função `_registrar` da tela inicial
   (`app/lib/features/inicio/inicio_screen.dart`) **nunca tinha sido ligada à flag** — só os
   botões da aba Fichas e o "Continuar treino" tinham. → Corrigido (os cartões e o
   "REGISTRAR TREINO" da Início passam a abrir o treino ao vivo).
4. **Evidência que mudou tudo:** mesmo após os merges, o `main.dart.js` publicado continuava
   **idêntico** (byte a byte) e os headers HTTP servidos **não** eram os do `netlify.toml`
   novo. Conclusão: o Netlify **não estava publicando os commits recentes**.
5. **Causa raiz confirmada (pelo usuário, no painel):** o time do Netlify estava
   **"running on operational credits"** — plano **Free (300 créditos/mês)** esgotado no
   ciclo, com **"production deploys paused"**. O site estava congelado em **14/out**, antes
   de todos os merges do Release 2. Nada no código impedia; era billing/infra do Netlify.

> Lição: quando "deployei e não muda nada" persiste mesmo com o código certo, verificar
> **se o deploy realmente rodou/publicou** (painel do host) **antes** de continuar mexendo
> no código. A evidência decisiva (bundle idêntico + headers antigos) apontava "o deploy não
> aconteceu", não "o build está errado".

## Como a causa foi comprovada (fatos reproduzíveis)

Comparação do `main.dart.js` publicado com builds locais do mesmo commit. Marcador: com a
flag ligada, o tree-shaking do Dart mantém o código do treino ao vivo (`fichas/ao-vivo`,
"Completar série"); com a flag desligada, remove tudo.

```bash
curl -s https://<host>/main.dart.js | grep -c 'fichas/ao-vivo'   # publicado = 0 (sem Release 2)
# build local com --dart-define=TREINO_AO_VIVO=true  -> > 0 (com Release 2)
# build local com --dart-define=TREINO_AO_VIVO=false -> 0
```
E os headers do `index.html` publicado vinham `public,max-age=0,must-revalidate` em vez do
`no-cache,no-store` que o `netlify.toml` novo definia → prova de que o deploy no ar era
anterior ao commit das correções.

---

## Solução aplicada (migração Netlify → Cloudflare)

- **Host novo:** Cloudflare Workers (Static Assets). O Flutter web é estático (`build/web`),
  então o Worker serve os arquivos direto da edge. Sem o limite de créditos de deploy que o
  Netlify Free impõe.
- **URL:** `https://diario-treino.vitorhugo-an.workers.dev` (ficou `.workers.dev` em vez de
  `.pages.dev` porque a interface nova da Cloudflare cria "Worker com assets"; funciona igual
  para servir SPA).
- **Config:** `app/wrangler.toml` — `name = "diario-treino"`, `[assets] directory = "build/web"`,
  `not_found_handling = "single-page-application"` (equivale ao redirect `/* -> /index.html`).
- **Deploy automático:** job `deploy-web` em `.github/workflows/ci.yml` — no push para `main`,
  builda o web (`--dart-define=API_BASE_URL=...`) e roda `wrangler deploy`. Secrets no GitHub:
  `CLOUDFLARE_API_TOKEN` (permissão Workers Scripts: Edit) e `CLOUDFLARE_ACCOUNT_ID`.
- **Primeiro deploy:** feito por **upload manual** (drag-and-drop da pasta `build/web` no
  painel do Cloudflare) para colocar no ar na hora; depois automatizado pelo Actions.
- **Netlify removido:** apagados `netlify.toml` (raiz) e `app/netlify.toml`.

### Ajustes de ambiente necessários na migração (senão o app abre mas não funciona)
- **CORS da API (Fly):** liberar a origem nova —
  `flyctl secrets set Cors__OrigensPermitidas__0=https://diario-treino.vitorhugo-an.workers.dev --app diario-treino-api`.
  Confirmado por preflight OPTIONS retornando `access-control-allow-origin` para o domínio novo.
- **Firebase Auth:** adicionar `diario-treino.vitorhugo-an.workers.dev` em
  Authentication → Settings → Authorized domains (projeto `diario-treino-c21b6`), senão o
  login falha por "domínio não autorizado".

---

## Correções de código que entraram no caminho (todas boas, independentes da causa raiz)

- `flags.dart`: `treinoAoVivoHabilitado` default **`true`** (fluxo novo não depende mais de
  `--dart-define` no deploy; o E2E usa `=false` explícito para percorrer a tela antiga).
- `inicio_screen.dart`: `_registrar` respeita a flag (abre o treino ao vivo).
- `app_router.dart`: telas ao vivo empilhadas no **navigator raiz** (tela cheia, sem a barra
  inferior, como os protótipos 14–16).
- `iniciar_treino_ao_vivo.dart`: `Navigator.of(context, rootNavigator: true)` no pop do
  indicador de loading (antes o pop mirava o navigator da aba e o loading ficava preso).
- `widgets_ao_vivo.dart` + `treino_ao_vivo_screen.dart`: `BarraDescansoFixa` no rodapé das
  três abas (protótipo 15).

---

## Pendências conhecidas (não bloqueiam nada)

1. **Integrações Git órfãs no GitHub:** as GitHub Apps "Cloudflare Workers and Pages" e
   "Netlify" ainda ficam instaladas e geram checks de build nos PRs (ex.: "Workers Builds"
   vermelho, "netlify deploy-preview"). Remover em GitHub → Settings (conta) → Applications →
   Installed GitHub Apps. Não afeta o deploy (que vai por API token no Actions).

2. **E2E Robot (PBI-26) — ainda em aberto.** Problema secundário, separado da causa acima.
   - Fato: **não existe pasta `e2e/` versionada** nem job de E2E no `ci.yml`. O relatório
     Robot analisado veio de outro ambiente/branch.
   - Causa identificada: o `app/lib/main.dart` **não conectava ao Firebase Auth Emulator**
     (não havia `useAuthEmulator`), então no CI o app ia para o Firebase real, o cadastro não
     logava, e o app ficava preso em `/cadastro`.
   - Correção já na `main`: `useAuthEmulator` sob a flag `USE_AUTH_EMULATOR`
     (`app/lib/core/flags.dart` + `main.dart`). **Não verificada ponta a ponta** (sem Docker/
     Firebase CLI/runner no ambiente de dev, e sem `e2e/` no repo).
   - Para fechar: trazer/recriar `e2e/` + job de CI (Postgres + API + Auth Emulator + web
     com `--dart-define=USE_AUTH_EMULATOR=true` + Robot); confirmar que o backend aceita o
     token do emulator (`FIREBASE_AUTH_EMULATOR_HOST`?); confirmar `DELETE /me`.
