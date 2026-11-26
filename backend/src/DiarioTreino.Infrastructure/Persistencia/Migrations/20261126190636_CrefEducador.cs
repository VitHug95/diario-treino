using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class CrefEducador : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "educador_cref",
                columns: table => new
                {
                    usuario_id = table.Column<Guid>(type: "uuid", nullable: false),
                    uf = table.Column<string>(type: "char(2)", nullable: true),
                    numero = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    situacao = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    categoria = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    origem = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    consultado_em = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_educador_cref", x => x.usuario_id);
                    table.CheckConstraint("ck_educador_cref_automatica_completa", "origem = 'LEGADO' OR (uf IS NOT NULL AND numero IS NOT NULL AND situacao IS NOT NULL AND categoria IS NOT NULL AND consultado_em IS NOT NULL)");
                    table.CheckConstraint("ck_educador_cref_origem", "origem IN ('AUTOMATICA','LEGADO')");
                    table.ForeignKey(
                        name: "FK_educador_cref_usuario_usuario_id",
                        column: x => x.usuario_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "educador_cref_tentativa",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    usuario_id = table.Column<Guid>(type: "uuid", nullable: false),
                    em = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    resultado = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_educador_cref_tentativa", x => x.id);
                    table.CheckConstraint("ck_educador_cref_tentativa_resultado", "resultado IN ('HABILITADO','RECUSADO','NAO_ENCONTRADO','INDISPONIVEL')");
                    table.ForeignKey(
                        name: "FK_educador_cref_tentativa_usuario_usuario_id",
                        column: x => x.usuario_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ux_educador_cref_uf_numero",
                table: "educador_cref",
                columns: new[] { "uf", "numero" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_educador_cref_tentativa_usuario_em",
                table: "educador_cref_tentativa",
                columns: new[] { "usuario_id", "em" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "educador_cref");

            migrationBuilder.DropTable(
                name: "educador_cref_tentativa");
        }
    }
}
