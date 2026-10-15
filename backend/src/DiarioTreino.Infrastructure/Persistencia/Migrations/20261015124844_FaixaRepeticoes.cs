using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class FaixaRepeticoes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "volume_alvo_max",
                table: "etapa_prescrita",
                type: "numeric(9,2)",
                precision: 9,
                scale: 2,
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_etapa_prescrita_volume_max",
                table: "etapa_prescrita",
                sql: "volume_alvo_max IS NULL OR volume_alvo_max >= volume_alvo");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_etapa_prescrita_volume_max",
                table: "etapa_prescrita");

            migrationBuilder.DropColumn(
                name: "volume_alvo_max",
                table: "etapa_prescrita");
        }
    }
}
