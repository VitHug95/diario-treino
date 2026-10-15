*** Settings ***
Documentation    Keywords de alto nível do fluxo principal do Diário de Treino.
...              O app é Flutter web com a árvore de semântica ligada (ADR-07),
...              então os seletores miram texto/rótulo visível (aria-label), não
...              o DOM interno do Flutter. Se algum seletor precisar de ajuste
...              fino, é aqui — as suítes não conhecem seletor.
Library          Browser
Library          String


*** Variables ***
${BASE_URL}         http://localhost:8000
${TIMEOUT}          45s
# Senha fixa do usuário de teste; o email é único por execução (ver suíte).
${SENHA}            Teste@12345


*** Keywords ***
Abrir o app
    [Documentation]    Abre o navegador e carrega o app; espera o login montar.
    New Browser    chromium    headless=True
    New Context    viewport={'width': 1280, 'height': 900}
    New Page    ${BASE_URL}
    Set Browser Timeout    ${TIMEOUT}
    # O Flutter web demora a montar a árvore de semântica; espera o botão entrar.
    Wait For Elements State    text="ENTRAR"    visible    timeout=${TIMEOUT}

Gerar email de teste
    [Documentation]    Email único por execução, para cada rodada começar limpa.
    ${sufixo}=    Generate Random String    10    [LOWER][NUMBERS]
    RETURN    e2e-${sufixo}@teste.local

Cadastrar e entrar
    [Documentation]    Cria uma conta nova pela tela de cadastro (passando pelo
    ...                Auth Emulator) e entra.
    [Arguments]    ${email}
    Click    text="Criar conta"
    Wait For Elements State    text="CRIAR CONTA"    visible
    Fill Text    [aria-label="Seu nome"]    Atleta E2E
    Fill Text    [aria-label="E-mail"]    ${email}
    Fill Text    [aria-label="Senha"]    ${SENHA}
    Click    text="CRIAR CONTA"
    # Depois do cadastro, o usuário sem ficha/sessão cai no primeiro acesso.
    Wait For Elements State
    ...    text="Registrar sem ficha"    visible    timeout=${TIMEOUT}

Registrar um treino livre
    [Documentation]    Treino livre: adiciona um exercício do catálogo, marca
    ...                como feito, preenche uma série e finaliza.
    Click    text="Registrar sem ficha"
    Wait For Elements State    text="Treino livre"    visible
    Click    text="Adicionar exercício"
    Wait For Elements State    [aria-label="Buscar por nome"]    visible
    Fill Text    [aria-label="Buscar por nome"]    Supino
    Wait For Elements State    text="Supino reto com barra"    visible    timeout=${TIMEOUT}
    Click    text="Supino reto com barra"
    # O exercício volta como sugestão; "Marcar" liga o realizado e abre a série.
    Wait For Elements State    text="Marcar"    visible    timeout=${TIMEOUT}
    Click    text="Marcar"
    Wait For Elements State    text="Realizado"    visible
    Fill Text    (//input[@aria-label="Carga"])[1]    30
    Fill Text    (//input[@aria-label="Repetições"])[1]    10
    Click    text="FINALIZAR TREINO"
    Wait For Elements State    text="Treino registrado"    visible    timeout=${TIMEOUT}

Ver o progresso do exercício
    [Documentation]    Vai para a aba Progresso e confirma que o exercício
    ...                registrado aparece (seletor do gráfico).
    Click    text="Ver progresso"
    Wait For Elements State    text="Progresso"    visible    timeout=${TIMEOUT}
    Wait For Elements State    text="Supino reto com barra"    visible    timeout=${TIMEOUT}

Excluir a conta de teste
    [Documentation]    Limpeza: abre o Perfil e exclui a conta — hard delete no
    ...                Postgres (DELETE /me) e remoção no emulador. Falha aqui
    ...                não derruba o teste.
    Run Keyword And Ignore Error    Limpar conta pelo perfil

Limpar conta pelo perfil
    Go To    ${BASE_URL}
    Wait For Elements State    text="Perfil"    visible    timeout=${TIMEOUT}
    Click    text="Perfil"
    Wait For Elements State    text="Excluir conta"    visible    timeout=${TIMEOUT}
    Click    text="Excluir conta"
    Wait For Elements State    [aria-label="EXCLUIR"]    visible
    Fill Text    [aria-label="EXCLUIR"]    EXCLUIR
    # O botão de confirmar do diálogo também se chama "Excluir conta": pega o
    # último (o do diálogo, montado por cima).
    Click    (//flt-semantics[contains(@aria-label,"Excluir conta")])[last()]

Fechar o app
    Close Browser
