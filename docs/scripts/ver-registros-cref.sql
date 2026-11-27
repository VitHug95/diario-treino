-- PBI-106 · Lista os educadores habilitados e como (sem mostrar a foto).
--
--   psql "$DATABASE_URL" -f docs/scripts/ver-registros-cref.sql
--
-- origem: DECLARADA (número, UF e foto enviados pela tela), LEGADO (script) ou
-- AUTOMATICA (consulta ao site do CREF, ainda desligada). Para conferir um
-- registro declarado, compare o número e a UF com a consulta pública do CREF
-- daquela UF, no navegador, e com a foto (docs/scripts/foto-cref.sql).

SELECT u.email,
       u.nome,
       c.origem,
       c.uf,
       c.numero,
       c.declarado_em,
       f.tipo_conteudo,
       octet_length(f.conteudo) AS tamanho_foto_bytes
FROM educador_cref c
JOIN usuario u ON u.id = c.usuario_id
LEFT JOIN educador_cref_foto f ON f.usuario_id = c.usuario_id
ORDER BY c.declarado_em DESC NULLS LAST, u.email;
