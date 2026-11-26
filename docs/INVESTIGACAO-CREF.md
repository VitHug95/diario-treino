# PBI-105 · Investigação das consultas públicas de CREF

Status: **em andamento, decisão pendente.** Primeira passada feita em 26/11/2026,
sem nenhuma busca: só leitura do `robots.txt` e da página inicial de cada
consulta. As buscas de teste precisam de uma pessoa com dados próprios (ver
"O que falta").

## 1. O que já se sabe

**Todos os sites são do mesmo sistema.** As páginas regionais e as hospedadas em
`listasconfef.org.br` se identificam como **Spiderware**, com o mesmo caminho
(`/spw/ConsultaCadastral/...`). São páginas ASP.NET WebForms: a busca é um
*postback* que reenvia campos escondidos (`__VIEWSTATE`, `__EVENTVALIDATION`) da
página anterior. Por isso um adaptador só, configurado por UF, deve servir para
todas, como o PO supôs. Também por isso a consulta precisa de duas chamadas (abrir
a página e depois postar o formulário) e quebra se o fornecedor mudar o formulário.

**Formulário (CREF6/MG, lido sem buscar):** "Informe o tipo de pesquisa", "Selecione
o tipo de busca", "Cidade" e "Pesquisar". Nenhum captcha no HTML da página. Pode
haver captcha carregado por script ou só depois da busca; isso só se vê buscando.

**`robots.txt`:**

| Consulta | `robots.txt` | O que significa |
|---|---|---|
| CREF6 (MG) `portal.cref6.org.br` | não existe (404) | Nada proibido por ele; não é permissão |
| CREF3 (SC) `online.crefsc.org.br` | não existe (404) | Idem |
| CREF7 (DF) `web.cref7.org.br` | não existe (404) | Idem |
| CREF14 (GO e TO) `spw.cref14.org.br` | não existe (404) | Idem |
| CREF13 (BA) `spw.cref13.org.br` | existe, gerado pela **Cloudflare** ("content signals") | Não proíbe consulta; o site está atrás da Cloudflare, que pode bloquear acesso por programa com desafio de navegador |
| `listasconfef.org.br` (CREF9, 10, 17, 20 e 22) | não existe (404) | Nada proibido por ele |
| CONFEF nacional `www.confef.org.br/registrados/` | não consegui ler (laço de redirecionamento fora do navegador) | **Pendente.** O laço já sugere proteção contra acesso que não seja de navegador |

**Termos de uso:** nenhuma das páginas de consulta mostra termos de uso ou aviso
sobre acesso automatizado. Ausência de termo **não é permissão**.

**Canal oficial do CONFEF:** a busca na web não achou serviço, API ou convênio
público para sistemas consultarem o registro. Não encontrado não quer dizer que
não exista: **o caminho é perguntar ao CONFEF** pelo canal da Carta de Serviços
ao Usuário (ver "O que falta", item 1).

**Busca por CPF no nacional:** um texto de terceiros diz que a consulta nacional é
por nome ou número de registro. Se for verdade, o nacional **não aceita CPF**, e SP,
RJ e RS (sem consulta regional na lista do PO) **não teriam como ser habilitados
pela regra da PBI-106** (CPF + número). Precisa ser confirmado na tela.

## 2. Riscos já visíveis

1. **CPF de usuário enviado a um site de terceiro.** O CPF é dado pessoal (LGPD).
   Mesmo sem guardá-lo, o app o repassa ao site do CREF. Precisa de base legal e
   de aviso claro (o texto da PBI-106 já avisa que não guardamos; falta dizer que
   ele é enviado ao CREF). Vale passar pelo texto jurídico do termo.
2. **Sem permissão expressa.** Nenhum site autoriza nem proíbe acesso por
   programa. Uma consulta por pedido do próprio usuário, poucas por dia, é
   diferente de varredura, mas o risco de bloqueio (e de reclamação) existe.
3. **Cloudflare (CREF13) e o nacional** podem barrar chamadas que não venham de
   navegador. Contornar isso (simular navegador, resolver desafio) **não** é uma
   opção: seria burlar uma proteção.
4. **Fragilidade:** WebForms com estado escondido quebra a qualquer mudança do
   fornecedor. A PBI-106 já trata isso (`INDISPONIVEL` nunca recusa).

## 3. O que falta (precisa de uma pessoa)

1. **Perguntar ao CONFEF** se há canal oficial para sistemas confirmarem registro
   (serviço, convênio, lista pública). Se houver, ele substitui tudo abaixo.
2. Em **uma** consulta regional (sugestão: CREF6/MG, a do PO), com os dados do
   próprio PO, abrir no navegador e anotar:
   - se há captcha antes ou depois da busca;
   - se existe "Profissional" + "CPF/CNPJ" e "Profissional" + "Num. Registro";
   - o que a busca por CPF devolve (um registro, vários, de outra UF?);
   - o formato do número (prefixo `MG-`, zeros à esquerda);
   - a resposta para um CPF sem registro (pode ser um CPF válido inventado, sem
     dono conhecido; **não** usar CPF de terceiro real).
3. Repetir só a abertura da página (sem buscar) nas outras nove regionais, para
   confirmar o mesmo formulário e captcha.
4. **No nacional,** no navegador: aceita CPF? Cobre SP, RJ e RS?
5. **Com o PO:** a lista de categorias que habilitam. Só `BACHAREL` foi visto; o
   sistema CONFEF tem outras (por exemplo licenciado e provisionado), e o PO decide
   quais valem para usar o modo educador.
6. **Com o PO:** o texto sobre o CPF ser enviado ao CREF (risco 1).

## 4. Decisão

**Pendente.** Recomendação provisória, para o PO avaliar:

- Se o CONFEF tiver canal oficial: **seguir** por ele.
- Se não tiver, e o regional responder por CPF sem captcha: **seguir só em parte**,
  nas UFs com consulta regional que responde, com no máximo uma consulta por
  tentativa do usuário, `User-Agent` identificando o app e um contato, e tempo
  limite curto. UFs sem consulta que responda (provavelmente SP, RJ e RS, e a BA se a
  Cloudflare barrar) ficam no **plano B** (aprovação por administrador) ou sem
  habilitação até haver canal.
- Se o regional tiver captcha ou barrar: **não seguir**, plano B.

A PBI-106 não começa antes desta decisão.
