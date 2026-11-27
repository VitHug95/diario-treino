# PBI-105 · Investigação das consultas públicas de CREF

Status: **decisão tomada: seguir só em parte** (PO, 26/11). A PBI-106 parte 1
(tudo menos o leitor do site) está feita, com a chave `Educador:ExigirCref`
desligada até o leitor existir. Primeira
passada em 26/11/2026, sem nenhuma busca: só o `robots.txt` e a página inicial de
cada consulta. Respostas do PO na seção 4. Falta o formato da página de resultado
(seção 5) para o adaptador real.

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
4. **No nacional,** no navegador: aceita CPF? Mostra a situação? (SP, RJ e RS têm consulta própria, seção 3.1.)
5. **Com o PO:** a lista de categorias que habilitam. Só `BACHAREL` foi visto; o
   sistema CONFEF tem outras (por exemplo licenciado e provisionado), e o PO decide
   quais valem para usar o modo educador.
6. ~~Com o PO: o texto sobre o CPF ser enviado ao CREF (risco 1).~~ Resolvido (26/11): a tela avisa que as informações pessoais são usadas para validar o CREF e pede "Eu permito" / "Eu não permito".

## 3.1 Os 22 CREFs (lista do PO, 26/11)

Endereços informados pelo PO. A coluna "Conferido" é o que se vê ao abrir a página
inicial, **sem buscar nada** (26/11).

| CREF | UF | Consulta | Sistema | Busca por CPF | Conferido |
|---|---|---|---|---|---|
| 1 | RJ (e ES, segundo a lista) | https://cref-rj.implanta.net.br/servicosOnline/Publico/ConsultaInscritos/ | Implanta | **Sim** ("CPF/CNPJ") | Filtros: nº de inscrição, nome, CPF/CNPJ, categoria, área; resultado com "Situação \| Detalhe situação" |
| 2 | RS | https://cref-rs.implanta.net.br/servicosonline/Publico/ConsultaInscritos/ | Implanta | **Sim** ("CPF/CNPJ") | Filtros: nº, nome, CPF/CNPJ, cidade, UF, categoria; resultado com situação |
| 3 | SC | https://online.crefsc.org.br/spw/consultacadastral/Principal.aspx | Spiderware | a confirmar | Página inicial; a busca fica em `TelaConsultaPublicaCompleta.aspx` |
| 4 | SP | https://cref-sp.implanta.net.br/ServicosOnline/Publico/ConsultaInscritos | Implanta | **Não** | Filtros só **nº de inscrição e nome**. Ver nota abaixo |
| 5 | CE | https://listasconfef.org.br/spw/CREF5/ConsultaCadastral/Principal.aspx | Spiderware | a confirmar | Página inicial com "Consulta cadastral" |
| 6 | MG | https://portal.cref6.org.br/spw/ConsultaCadastral/TelaConsultaPublicaCompleta.aspx | Spiderware | sim (PO) | Sem captcha (PO) |
| 7 | DF | https://web.cref7.org.br/spw/consultacadastral/TelaConsultaPublicaCompleta.aspx | Spiderware | a confirmar | |
| 8 | AM, AC, RO, RR | https://online.cref8.org.br/spw/consultacadastral/Principal.aspx | Spiderware | a confirmar | Página inicial com "Consulta cadastral" |
| 9 | PR | https://listasconfef.org.br/spw/CREF9/consultacadastral/principal.aspx | Spiderware | a confirmar | |
| 10 | PB, RN | https://listasconfef.org.br/spw/CREF10/consultacadastral/Principal.aspx | Spiderware | a confirmar | |
| 11 | MS | https://cref11.org.br/ (só o site) | — | — | Falta o endereço da consulta; uma busca na web cita `listasconfef.org.br/spw/CREF11/ConsultaCadastral/Principal.aspx` |
| 12 | PE | https://cref12.org.br/ (só o site) | — | — | Falta o endereço da consulta |
| 13 | BA | https://spw.cref13.org.br/spw/ConsultaCadastral/TelaConsultaPublicaCompleta.aspx | Spiderware | a confirmar | Atrás da Cloudflare |
| 14 | GO, TO | https://spw.cref14.org.br/spw/consultacadastral/Principal.aspx | Spiderware | a confirmar | |
| 15 | PI | https://cref15.org.br/ (só o site) | — | — | Falta o endereço da consulta |
| 16 | RN (segundo a lista) | https://cref16.org.br/ (só o site) | — | — | Falta o endereço; RN também aparece no CREF10 |
| 17 | MT | https://listasconfef.org.br/spw/CREF17/ConsultaCadastral/Principal.aspx | Spiderware | a confirmar | |
| 18 | PA, AP | https://cref18.org.br/ (só o site) | — | — | Falta o endereço da consulta |
| 19 | AL | https://cref19.org.br/ (só o site) | — | — | Falta o endereço da consulta |
| 20 | SE | https://listasconfef.org.br/spw/CREF20/ConsultaCadastral/TelaConsultaPublicaCompleta.aspx | Spiderware | a confirmar | |
| 21 | MA | https://cref21.org.br/ (só o site) | — | — | Falta o endereço da consulta |
| 22 | ES | https://listasconfef.org.br/spw/CREF22/ConsultaCadastral/Principal.aspx | Spiderware | a confirmar | ES também aparece no CREF1 |

**Resumo:** 13 consultas levantadas cobrem 19 UFs (SC, MG, DF, PR, PB, RN, BA, GO,
TO, MT, SE, ES, CE, AM, AC, RO, RR, RJ e RS). **SP** tem consulta, mas sem busca por
CPF. Faltam os endereços de consulta de MS, PE, PI, PA, AP, AL e MA (os sites dos
CREFs 11, 12, 15, 18, 19 e 21 foram informados, mas não a página da consulta).

**SP não segue a regra atual.** A regra da PBI-106 confirma a pessoa pelo par **CPF +
número**: o número de registro é público, e só o CPF prova que quem digita é o dono
do registro. A consulta do CREF4/SP só busca por número ou nome, então daria para
confirmar que o registro está ativo, mas **não que é da pessoa**. Opções para o PO:
1. SP fica sem habilitação automática (vai para o plano B, aprovação por pessoa,
   se um dia for preciso);
2. aceitar só o número em SP, sabendo que qualquer um que saiba um número ativo
   passaria;
3. comparar o nome da conta com o nome do CREF em SP (o PO já descartou essa
   comparação por causa de apelidos).
Recomendação: a opção 1 por enquanto, porque hoje só o PO (MG) e o Vinicius usam o
modo educador.

**Dúvidas da lista:** ES aparece no CREF1 e no CREF22, e RN no CREF10 e no CREF16.
Pelo endereço, o app usa CREF22 para ES e CREF10 para RN; o PO confirma.

O **robots.txt** do Implanta (`cref-sp.implanta.net.br/robots.txt`) existe, mas não
deu para ler o conteúdo fora do navegador; falta alguém abrir e conferir se proíbe
o caminho `/ServicosOnline/Publico/`.

## 4. Respostas do PO (26/11)

1. **Canal oficial:** o CONFEF não tem outro; os registros são validados por estas
   páginas. Item 1 da seção 3 respondido.
2. **CREF6/MG no navegador:** sem captcha.
3. **Nacional:** aceita CPF. Não confirmado se mostra a situação nem se cobre SP,
   RJ e RS. A resposta "aparece ativo se for pelo site do estado" indica que a
   situação talvez só apareça no regional.
4. **Categorias:** vale a situação `ATIVO`; a categoria é guardada, mas **não
   restringe** por ora.
5. **Educadores atuais:** ficam travados até verificar. Só o Vinicius é habilitado
   sem consulta (`LEGADO`, por script de banco de uso único).

**Termos e `robots.txt`:** nenhuma página proíbe nem autoriza acesso por programa
(seção 1). A regra da PBI-105 manda "parar e anotar" nesse caso: está anotado, e
**seguir é uma aceitação de risco do PO**, sabendo que não há canal oficial.

## 5. Decisão

**Seguir só em parte**, confirmada pelo PO em 26/11, que aceita o risco de usar
páginas sem autorização expressa para acesso por programa.

- **Habilitação automática** nas UFs das dez consultas regionais da lista (SC, MG,
  DF, PR, PB, RN, BA, GO, TO, MT, SE e ES), depois de cada uma passar pelo teste do
  formulário (seção 3, item 3). A BA fica de fora se a Cloudflare barrar.
- **RJ e RS:** entram com o segundo leitor (Implanta, seção 3.1), que tem busca por
  CPF, quando houver as páginas de exemplo deles. **SP** fica de fora (a consulta
  não busca por CPF; decisão do PO pendente, seção 3.1).
- **Nacional:** só entra se mostrar a situação. Se não mostrar, as UFs sem
  consulta levantada (MS, PE, PI, PA, AP, AL, MA e SP) **não habilitam** até haver
  uma consulta por CPF para elas.
  Contornar bloqueio de navegador não é opção.
- **Regras de uso:** uma consulta por tentativa do usuário (duas chamadas HTTP:
  abrir e enviar o formulário), no máximo 5 tentativas por usuário em 24 h,
  tempo limite de 10 s, sem novas tentativas automáticas, no máximo 2 consultas
  ao mesmo site ao mesmo tempo, `User-Agent` com o nome do app e um contato.

**O que ainda impede a parte do adaptador real** (o resto da PBI-106 não depende
disto): o formato da resposta. Sem uma página de resultado de verdade não dá para
escrever o leitor nem as fixtures. O que basta, sem dado de terceiro:

1. Na consulta do CREF6/MG, o PO busca **Profissional + CPF/CNPJ** com o próprio
   CPF e salva a página do resultado (Ctrl+S, "página completa").
2. O próprio CPF numa regional Spiderware onde ele não tem registro (por exemplo
   o CREF3/SC), para a página de "não encontrado", sem usar CPF de ninguém.
3. Repete na **nacional** com o próprio CPF (para ver se há situação).
4. **Implanta (RJ e RS):** duas páginas salvas num deles, buscando por CPF: uma
   com registro encontrado e uma de "não encontrado". O "não encontrado" sai do
   próprio CPF do PO (ele é de MG). O encontrado precisa de quem aceitar usar os
   próprios dados (o Vinicius, se for do RJ ou do RS); senão, só o "não
   encontrado".

Os arquivos ficam fora do repositório; daqui saem fixtures **anonimizadas** (nome,
CPF e número trocados por valores fictícios) antes de qualquer commit.

## 6. Contrato do adaptador (para a PBI-106)

```
IConsultaCref.ConsultarPorCpfAsync(uf, cpf, ct) -> ResultadoConsultaCref
  Encontrado(registros: [{ numero, situacao, categoria }])  // nome nunca sai do adaptador
  NaoEncontrado
  Indisponivel                                               // erro, tempo limite, HTML inesperado
```

- Configuração por UF (endereço, tipo de formulário) em `appsettings`, não no
  código. UF sem configuração devolve `Indisponivel` com o motivo "UF sem consulta".
- O adaptador só monta a busca Profissional por CPF; a decisão (número confere,
  situação `ATIVO`) fica no serviço, testável sem HTML.
