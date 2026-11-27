-- PBI-106 · Revoga a habilitação de um educador (registro que não bateu).
--
--   psql "$DATABASE_URL" -v email='pessoa@exemplo.com' -f docs/scripts/revogar-educador.sql
--
-- Apaga o registro do CREF (e a foto, em cascata) e tira o papel EDUCADOR. Não
-- apaga vínculos, planos nem dados dos alunos: com a validação ligada, o
-- educador fica travado até enviar um registro válido. Rodar de novo não faz
-- nada. A última consulta deve voltar vazia.

BEGIN;

DELETE FROM educador_cref
WHERE usuario_id = (SELECT id FROM usuario WHERE email = lower(:'email'));

DELETE FROM usuario_papel
WHERE papel = 'EDUCADOR'
  AND usuario_id = (SELECT id FROM usuario WHERE email = lower(:'email'));

COMMIT;

SELECT u.email, p.papel
FROM usuario u
JOIN usuario_papel p ON p.usuario_id = u.id
WHERE u.email = lower(:'email') AND p.papel = 'EDUCADOR';
