-- PBI-106 · Tira a foto da carteira do CREF de um educador, em base64.
--
-- A foto é documento com dado pessoal: salve num lugar seu, confira e apague o
-- arquivo depois. Nunca coloque no repositório.
--
-- No PowerShell:
--
--   psql "$env:DATABASE_URL" -At -v email='pessoa@exemplo.com' -f docs/scripts/foto-cref.sql > foto.b64
--   [IO.File]::WriteAllBytes("$PWD\foto-cref.jpg", [Convert]::FromBase64String((Get-Content foto.b64 -Raw)))
--   Remove-Item foto.b64
--
-- (Se o tipo for image/png, salve como .png.) Sem linha de saída, o e-mail não
-- tem foto.

SELECT encode(f.conteudo, 'base64')
FROM educador_cref_foto f
JOIN usuario u ON u.id = f.usuario_id
WHERE u.email = lower(:'email');
