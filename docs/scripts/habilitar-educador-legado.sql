-- PBI-106 · Habilita um educador sem consulta ao CREF (origem LEGADO).
--
-- Uso único, decisão do PO (26/11): só o Vinicius. O e-mail entra como
-- parâmetro, para não ficar no repositório:
--
--   psql "$DATABASE_URL" -v email='pessoa@exemplo.com' -f docs/scripts/habilitar-educador-legado.sql
--
-- Concede o papel EDUCADOR (se faltar) e grava a linha LEGADO, sem UF, número,
-- situação nem CPF. Rodar de novo não duplica nada. A última consulta mostra o
-- resultado: se não voltar linha, o e-mail não existe no banco.
--
-- Também serve de emergência (site do CREF fora do ar ou mudado) para liberar
-- um educador conhecido, com decisão do PO registrada.

BEGIN;

INSERT INTO usuario_papel (usuario_id, papel)
SELECT id, 'EDUCADOR' FROM usuario WHERE email = lower(:'email')
ON CONFLICT DO NOTHING;

INSERT INTO educador_cref (usuario_id, origem)
SELECT id, 'LEGADO' FROM usuario WHERE email = lower(:'email')
ON CONFLICT (usuario_id) DO NOTHING;

COMMIT;

SELECT u.email, c.origem
FROM usuario u
JOIN educador_cref c ON c.usuario_id = u.id
WHERE u.email = lower(:'email');
