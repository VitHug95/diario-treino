using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class BlocoConjugado : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "bloco_id",
                table: "treino_exercicio",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "bloco_exercicio",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    treino_id = table.Column<Guid>(type: "uuid", nullable: false),
                    descanso_seg = table.Column<short>(type: "smallint", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_bloco_exercicio", x => x.id);
                    table.CheckConstraint("ck_bloco_exercicio_descanso", "descanso_seg IS NULL OR descanso_seg BETWEEN 0 AND 600");
                    table.ForeignKey(
                        name: "FK_bloco_exercicio_treino_treino_id",
                        column: x => x.treino_id,
                        principalTable: "treino",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_treino_exercicio_bloco",
                table: "treino_exercicio",
                column: "bloco_id");

            migrationBuilder.CreateIndex(
                name: "ix_bloco_exercicio_treino",
                table: "bloco_exercicio",
                column: "treino_id");

            migrationBuilder.AddForeignKey(
                name: "FK_treino_exercicio_bloco_exercicio_bloco_id",
                table: "treino_exercicio",
                column: "bloco_id",
                principalTable: "bloco_exercicio",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_treino_exercicio_bloco_exercicio_bloco_id",
                table: "treino_exercicio");

            migrationBuilder.DropTable(
                name: "bloco_exercicio");

            migrationBuilder.DropIndex(
                name: "ix_treino_exercicio_bloco",
                table: "treino_exercicio");

            migrationBuilder.DropColumn(
                name: "bloco_id",
                table: "treino_exercicio");
        }
    }
}
