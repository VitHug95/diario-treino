using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class SerieBloco : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "bloco",
                table: "serie_executada",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "posicao_no_bloco",
                table: "serie_executada",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_serie_executada_bloco",
                table: "serie_executada",
                sql: "(bloco IS NULL AND posicao_no_bloco IS NULL) OR (bloco >= 1 AND posicao_no_bloco BETWEEN 1 AND 4)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_serie_executada_bloco",
                table: "serie_executada");

            migrationBuilder.DropColumn(
                name: "bloco",
                table: "serie_executada");

            migrationBuilder.DropColumn(
                name: "posicao_no_bloco",
                table: "serie_executada");
        }
    }
}
