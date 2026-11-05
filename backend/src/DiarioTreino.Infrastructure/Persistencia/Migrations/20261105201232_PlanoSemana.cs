using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class PlanoSemana : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "plano_dia_semana",
                columns: table => new
                {
                    plano_id = table.Column<Guid>(type: "uuid", nullable: false),
                    dia_semana = table.Column<short>(type: "smallint", nullable: false),
                    treino_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_plano_dia_semana", x => new { x.plano_id, x.dia_semana });
                    table.CheckConstraint("ck_plano_dia_semana_dia", "dia_semana BETWEEN 1 AND 7");
                    table.ForeignKey(
                        name: "FK_plano_dia_semana_plano_treino_plano_id",
                        column: x => x.plano_id,
                        principalTable: "plano_treino",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_plano_dia_semana_treino_treino_id",
                        column: x => x.treino_id,
                        principalTable: "treino",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_plano_dia_semana_treino",
                table: "plano_dia_semana",
                column: "treino_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "plano_dia_semana");
        }
    }
}
