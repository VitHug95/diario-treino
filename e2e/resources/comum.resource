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
    Wait For Elements State    role=button[name="ENTRAR"]    visible    timeout=${TIMEOUT}

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
    Fill Text    [aria-label="Seu nome"]    Atleta E2E
    Fill Text    [aria-label="E-mail"]    ${email}
    Fill Text    [aria-label="Senha"]    ${SENHA}
    Click    role=button[name="CRIAR CONTA"]
    # Depois do cadastro, o usuário sem ficha/sessão cai no primeiro acesso.
    Wait For Elements State
    ...    role=button[name="Registrar sem ficha"]    visible    timeout=${TIMEOUT}

Registrar um treino livre
    [Documentation]    Treino livre: adiciona um exercício do catálogo, marca
    ...                como feito, preenche uma série e finaliza.
    Click    role=button[name="Registrar sem ficha"]
    Wait For Elements State    text="Treino livre"    visible
    Click    role=button[name="Adicionar exercício"]
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
    ...                Postgres (DELETE /me) e remoção no emulador. Falha aqui
    ...                não derruba o teste.
    Run Keyword And Ignore Error    Limpar conta pelo perfil

Limpar conta pelo perfil
    Go To    ${BASE_URL}
    # O perfil é alcançado pelo ícone de usuário no cabeçalho da Início.
    Wait For Elements State    role=button[name="Perfil"]    visible    timeout=${TIMEOUT}
    Click    role=button[name="Perfil"]
    Wait For Elements State    role=button[name="Excluir conta"]    visible    timeout=${TIMEOUT}
    Click    role=button[name="Excluir conta"]
    Wait For Elements State    [aria-label="EXCLUIR"]    visible
    Fill Text    [aria-label="EXCLUIR"]    EXCLUIR
    # O diálogo tem outro botão "Excluir conta"; pega o último (o do diálogo).
    Click    role=button[name="Excluir conta"] >> nth=-1

Fechar o app
    Close Browser
