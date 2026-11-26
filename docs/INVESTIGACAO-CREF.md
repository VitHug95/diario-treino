# PBI-105 · Investigação das consultas públicas de CREF

Status: **decisão tomada: seguir só em parte** (PO, 26/11). Primeira
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
4. **No nacional,** no navegador: aceita CPF? Cobre SP, RJ e RS?
5. **Com o PO:** a lista de categorias que habilitam. Só `BACHAREL` foi visto; o
   sistema CONFEF tem outras (por exemplo licenciado e provisionado), e o PO decide
   quais valem para usar o modo educador.
6. **Com o PO:** o texto sobre o CPF ser enviado ao CREF (risco 1).

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
- **Nacional:** só entra se mostrar a situação. Se não mostrar, os 15 estados
  fora da lista (SP, RJ e RS entre eles) **não habilitam** até alguém levantar a
  consulta regional de cada um. Contornar bloqueio de navegador não é opção.
- **Regras de uso:** uma consulta por tentativa do usuário (duas chamadas HTTP:
  abrir e enviar o formulário), no máximo 5 tentativas por usuário em 24 h,
  tempo limite de 10 s, sem novas tentativas automáticas, no máximo 2 consultas
  ao mesmo site ao mesmo tempo, `User-Agent` com o nome do app e um contato.

**O que ainda impede a parte do adaptador real** (o resto da PBI-106 não depende
disto): o formato da resposta. Sem uma página de resultado de verdade não dá para
escrever o leitor nem as fixtures. O que basta, sem dado de terceiro:

1. Na consulta do CREF6/MG, o PO busca **Profissional + CPF/CNPJ** com o próprio
   CPF e salva a página do resultado (Ctrl+S, "página completa").
2. Repete com um **CPF válido inventado** (resultado "não encontrado").
3. Repete na **nacional** com o próprio CPF (para ver se há situação).

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
