*** Settings ***
Documentation    Keywords de alto nível do fluxo principal do Diário de Treino.
...              O app é Flutter web com a árvore de semântica ligada (ADR-07).
...              Botões são mirados por PAPEL (role=button[name=...]) e não por
...              texto cru: o Flutter renderiza o rótulo duas vezes (um <span>
...              visível e um <flt-semantics role=button>), e um seletor por
...              texto bateria nos dois (strict mode). Campos usam o aria-label.
...              Se algum seletor precisar de ajuste, é só aqui.
Library          Browser
Library          String
Library          Collections


*** Variables ***
${BASE_URL}         http://localhost:8000
# Timeout curto: um seletor certo aparece em poucos segundos; 45s só prolongava
# a falha. Com 15s cada ciclo de CI falha rápido e com screenshot/diagnóstico.
${TIMEOUT}          15s
# Espera inicial maior só para o Flutter web montar a árvore de semântica.
${TIMEOUT_BOOT}     40s
# Senha fixa do usuário de teste; o email é único por execução (ver suíte).
${SENHA}            Teste@12345
# Vira TRUE no fim de "Cadastrar e entrar". O teardown só tenta limpar a conta
# se o cadastro realmente aconteceu — evita gastar os ~105s de timeout quando o
# teste falha antes de ter conta pra excluir.
${CADASTRADO}       ${FALSE}


*** Keywords ***
Digitar no campo
    [Documentation]    Campo de texto do Flutter web vem como input disabled até
    ...                receber foco. Focar liga o input; o resto é digitado pelo
    ...                teclado. Fill Text puro falha no input disabled, por isso
    ...                não é usado aqui.
    ...                Nota de versão: nesta Browser Library o keyword Click NÃO
    ...                aceita force; quem aceita force é o Fill Text. Para focar
    ...                usamos Focus (dispara o foco do Flutter e habilita o input).
    [Arguments]    ${seletor}    ${texto}
    Focus    ${seletor}
    Keyboard Key    press    Control+a
    Keyboard Input    insertText    ${texto}

Abrir o app
    [Documentation]    Abre o navegador e carrega o app; espera o login montar.
    New Browser    chromium    headless=True
    New Context    viewport={'width': 1280, 'height': 900}
    New Page    ${BASE_URL}
    Set Browser Timeout    ${TIMEOUT}
    # O Flutter web demora a montar a árvore de semântica; espera o botão entrar.
    Wait For Elements State    role=button[name="ENTRAR"]    visible    timeout=${TIMEOUT_BOOT}

Diagnosticar a tela
    [Documentation]    Em falha, tira screenshot e lista os botões/campos
    ...                visíveis (nome acessível), para ajustar seletor com dado,
    ...                não no chute. Chamado no teardown do teste.
    Run Keyword And Ignore Error    Take Screenshot    fullPage=True
    ${botoes}=    Run Keyword And Ignore Error
    ...    Get Elements    role=button
    Log    Botões na tela (para conferir os nomes acessíveis): ${botoes}
    ${txt}=    Run Keyword And Ignore Error    Get Text    body
    Log    Texto visível no body: ${txt}

Gerar email de teste
    [Documentation]    Email único por execução, para cada rodada começar limpa.
    ${sufixo}=    Generate Random String    10    [LOWER][NUMBERS]
    RETURN    e2e-${sufixo}@teste.local

Cadastrar e entrar
    [Documentation]    Cria uma conta nova pela tela de cadastro (passando pelo
    ...                Auth Emulator) e entra.
    [Arguments]    ${email}
    Click    role=button[name="Criar conta"]
    Wait For Elements State    role=button[name="CRIAR CONTA"]    visible
    Digitar no campo    [aria-label="Nome"]    Atleta E2E
    Digitar no campo    [aria-label="E-mail"]    ${email}
    Digitar no campo    [aria-label="Senha"]    ${SENHA}
    Click    role=button[name="CRIAR CONTA"]
    # Depois do cadastro, o usuário sem ficha/sessão cai no primeiro acesso.
    Wait For Elements State
    ...    role=button[name="Registrar sem ficha"]    visible    timeout=${TIMEOUT}
    # A partir daqui existe conta no Postgres/emulador: libera a limpeza no teardown.
    Set Suite Variable    ${CADASTRADO}    ${TRUE}

Registrar um treino livre
    [Documentation]    Treino livre: adiciona um exercício do catálogo, marca
    ...                como feito, preenche uma série e finaliza.
    Click    role=button[name="Registrar sem ficha"]
    Wait For Elements State    text="Treino livre"    visible
    Click    role=button[name="Adicionar exercício"]
    Wait For Elements State    [aria-label="Buscar por nome"]    visible
    Digitar no campo    [aria-label="Buscar por nome"]    Supino
    Wait For Elements State    text="Supino reto com barra"    visible    timeout=${TIMEOUT}
    Click    text="Supino reto com barra"
    # O exercício volta como sugestão; "Marcar" liga o realizado e abre a série.
    Wait For Elements State    text="Marcar"    visible    timeout=${TIMEOUT}
    Click    text="Marcar"
    Wait For Elements State    text="Realizado"    visible
    Digitar no campo    (//input[@aria-label="Carga"])[1]    30
    Digitar no campo    (//input[@aria-label="Repetições"])[1]    10
    Click    role=button[name="FINALIZAR TREINO"]
    Wait For Elements State    text="Treino registrado"    visible    timeout=${TIMEOUT}

Ver o progresso do exercício
    [Documentation]    Vai para a aba Progresso e confirma que o exercício
    ...                registrado aparece (seletor do gráfico).
    Click    role=button[name="Ver progresso"]
    Wait For Elements State    text="Progresso"    visible    timeout=${TIMEOUT}
    Wait For Elements State    text="Supino reto com barra"    visible    timeout=${TIMEOUT}

Excluir a conta de teste
    [Documentation]    Limpeza: abre o Perfil e exclui a conta — hard delete no
    ...                Postgres (DELETE /me) e remoção no emulador. Só tenta se o
    ...                cadastro aconteceu (${CADASTRADO}); sem isso não há conta
    ...                pra excluir e o teardown gastaria timeouts à toa. Falha
    ...                aqui não derruba o teste.
    Run Keyword If    ${CADASTRADO}
    ...    Run Keyword And Ignore Error    Limpar conta pelo perfil

Limpar conta pelo perfil
    # Timeout curto (3s): a conta existe e já estamos logados, as telas da
    # limpeza aparecem rápido. Encurta a falha quando algo nelas der errado.
    Go To    ${BASE_URL}
    # Timeout curto nas esperas (Click desta versão não aceita timeout; só o
    # Wait For Elements State aceita). Cada Click é guardado pela espera logo
    # acima, então o tempo total da limpeza fica limitado por elas.
    # O perfil é alcançado pelo ícone de usuário no cabeçalho da Início.
    Wait For Elements State    role=button[name="Perfil"]    visible    timeout=3s
    Click    role=button[name="Perfil"]
    Wait For Elements State    role=button[name="Excluir conta"]    visible    timeout=3s
    Click    role=button[name="Excluir conta"]
    Wait For Elements State    [aria-label="EXCLUIR"]    visible    timeout=3s
    Digitar no campo    [aria-label="EXCLUIR"]    EXCLUIR
    # O diálogo tem outro botão "Excluir conta"; pega o último (o do diálogo).
    Click    role=button[name="Excluir conta"] >> nth=-1

Fechar o app
    Close Browser
