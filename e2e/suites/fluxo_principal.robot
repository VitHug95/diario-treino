*** Settings ***
Documentation     E2E do caminho mais importante (PBI-26): entrar, registrar um
...               treino e ver no gráfico. Roda contra a stack efêmera do CI
...               (Postgres + API + Flutter web + Firebase Auth Emulator), sem
...               tocar a produção. O usuário de teste é criado na hora e
...               excluído no teardown (hard delete via DELETE /me).
Resource          ../resources/comum.resource
Suite Setup       Abrir o app
Suite Teardown    Fechar o app


*** Test Cases ***
Atleta entra, registra um treino e vê no progresso
    [Documentation]    Fluxo feliz de ponta a ponta.
    [Teardown]    Excluir a conta de teste
    ${email}=    Gerar email de teste
    Cadastrar e entrar    ${email}
    Registrar um treino livre
    Ver o progresso do exercício
