using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class TagDeSerie : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "marcador",
                table: "serie_executada",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "VALIDA");

            migrationBuilder.CreateTable(
                name: "rodada_marcador",
                columns: table => new
                {
                    treino_exercicio_id = table.Column<Guid>(type: "uuid", nullable: false),
                    rodada = table.Column<short>(type: "smallint", nullable: false),
                    marcador = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_rodada_marcador", x => new { x.treino_exercicio_id, x.rodada });
                    table.CheckConstraint("ck_rodada_marcador_marcador", "marcador IN ('VALIDA','AQUECIMENTO','PREPARATORIA','TOP_SET','BACK_OFF','FALHA','DROP_SET','REST_PAUSE','NEGATIVA','PARCIAIS')");
                    table.CheckConstraint("ck_rodada_marcador_rodada", "rodada >= 1");
                    table.ForeignKey(
                        name: "FK_rodada_marcador_treino_exercicio_treino_exercicio_id",
                        column: x => x.treino_exercicio_id,
                        principalTable: "treino_exercicio",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_serie_executada_marcador",
                table: "serie_executada",
                sql: "marcador IN ('VALIDA','AQUECIMENTO','PREPARATORIA','TOP_SET','BACK_OFF','FALHA','DROP_SET','REST_PAUSE','NEGATIVA','PARCIAIS')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "rodada_marcador");

            migrationBuilder.DropCheckConstraint(
                name: "ck_serie_executada_marcador",
                table: "serie_executada");

            migrationBuilder.DropColumn(
                name: "marcador",
                table: "serie_executada");
        }
    }
}
