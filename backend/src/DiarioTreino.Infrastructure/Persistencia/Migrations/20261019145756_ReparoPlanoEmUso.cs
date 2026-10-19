using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class ReparoPlanoEmUso : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Reparo de dados (PBI-77). Antes da correção, quem excluía todos os
            // planos (que viram ativo=false por terem histórico) e criava um
            // novo acabava com um plano ativo mas NENHUM em uso: a Início mostra
            // "Crie seu plano" apesar do plano existir. Aqui, para cada atleta
            // com plano ativo e nenhum em uso, marcamos como em uso o plano
            // ATIVO com a sessão mais recente (empate: início mais novo; depois
            // o id, só para determinismo) — mesmo critério do ExcluirPlanoAsync.
            //
            // Idempotente: só toca atletas sem nenhum em_uso. Respeita o índice
            // único parcial ux_plano_atleta_em_uso (um por atleta) e o CHECK
            // ck_plano_treino_em_uso_ativo (só marca plano ativo).
            migrationBuilder.Sql(@"
                WITH sem_em_uso AS (
                    SELECT p.atleta_id
                    FROM plano_treino p
                    GROUP BY p.atleta_id
                    HAVING bool_or(p.em_uso) = false
                       AND bool_or(p.ativo) = true
                ),
                escolhido AS (
                    SELECT DISTINCT ON (p.atleta_id) p.id
                    FROM plano_treino p
                    JOIN sem_em_uso s ON s.atleta_id = p.atleta_id
                    LEFT JOIN treino t ON t.plano_id = p.id
                    LEFT JOIN sessao se ON se.treino_id = t.id
                    WHERE p.ativo = true
                    GROUP BY p.atleta_id, p.id, p.inicio
                    ORDER BY p.atleta_id,
                             MAX(se.data) DESC NULLS LAST,
                             p.inicio DESC,
                             p.id
                )
                UPDATE plano_treino
                SET em_uso = true
                WHERE id IN (SELECT id FROM escolhido);
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Reparo de dados não é revertido: desmarcar em_uso devolveria o
            // atleta ao estado quebrado. Sem operação no Down (de propósito).
        }
    }
}
