using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class PlanosVariosEmUso : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 1) Coluna nova (default false). A ordem importa: a coluna precisa
            //    existir antes do UPDATE e do novo índice.
            migrationBuilder.AddColumn<bool>(
                name: "em_uso",
                table: "plano_treino",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            // 2) Dados antigos (CA 8): o plano que era ativo de cada atleta vira
            //    o plano EM USO, para a Início seguir seguir o mesmo plano de
            //    antes. O índice antigo (um ativo por atleta) garante no máximo
            //    um em_uso=true por atleta, então o novo índice único não quebra.
            migrationBuilder.Sql("UPDATE plano_treino SET em_uso = ativo;");

            // 3) Troca os índices: sai o filtro por "ativo", entra por "em_uso".
            migrationBuilder.DropIndex(
                name: "ux_plano_atleta_ativo",
                table: "plano_treino");

            migrationBuilder.CreateIndex(
                name: "ux_plano_atleta_em_uso",
                table: "plano_treino",
                column: "atleta_id",
                unique: true,
                filter: "em_uso");

            // 4) Invariante: um plano em uso é sempre um plano ativo.
            migrationBuilder.AddCheckConstraint(
                name: "ck_plano_treino_em_uso_ativo",
                table: "plano_treino",
                sql: "NOT em_uso OR ativo");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ux_plano_atleta_em_uso",
                table: "plano_treino");

            migrationBuilder.DropCheckConstraint(
                name: "ck_plano_treino_em_uso_ativo",
                table: "plano_treino");

            migrationBuilder.DropColumn(
                name: "em_uso",
                table: "plano_treino");

            migrationBuilder.CreateIndex(
                name: "ux_plano_atleta_ativo",
                table: "plano_treino",
                column: "atleta_id",
                unique: true,
                filter: "ativo");
        }
    }
}
