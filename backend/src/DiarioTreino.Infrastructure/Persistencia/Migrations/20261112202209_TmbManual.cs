using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class TmbManual : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "tmb_manual_kcal",
                table: "usuario",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_usuario_tmb_manual_kcal",
                table: "usuario",
                sql: "tmb_manual_kcal BETWEEN 800 AND 5000");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_usuario_tmb_manual_kcal",
                table: "usuario");

            migrationBuilder.DropColumn(
                name: "tmb_manual_kcal",
                table: "usuario");
        }
    }
}
