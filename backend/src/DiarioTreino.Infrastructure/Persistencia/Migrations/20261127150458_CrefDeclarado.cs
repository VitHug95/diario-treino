using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class CrefDeclarado : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_educador_cref_automatica_completa",
                table: "educador_cref");

            migrationBuilder.DropCheckConstraint(
                name: "ck_educador_cref_origem",
                table: "educador_cref");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "declarado_em",
                table: "educador_cref",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "educador_cref_foto",
                columns: table => new
                {
                    usuario_id = table.Column<Guid>(type: "uuid", nullable: false),
                    conteudo = table.Column<byte[]>(type: "bytea", nullable: false),
                    tipo_conteudo = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    enviada_em = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_educador_cref_foto", x => x.usuario_id);
                    table.CheckConstraint("ck_educador_cref_foto_tamanho", "octet_length(conteudo) BETWEEN 1 AND 5242880");
                    table.CheckConstraint("ck_educador_cref_foto_tipo", "tipo_conteudo IN ('image/jpeg','image/png')");
                    table.ForeignKey(
                        name: "FK_educador_cref_foto_educador_cref_usuario_id",
                        column: x => x.usuario_id,
                        principalTable: "educador_cref",
                        principalColumn: "usuario_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_educador_cref_automatica_completa",
                table: "educador_cref",
                sql: "origem <> 'AUTOMATICA' OR (uf IS NOT NULL AND numero IS NOT NULL AND situacao IS NOT NULL AND categoria IS NOT NULL AND consultado_em IS NOT NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_educador_cref_declarada_completa",
                table: "educador_cref",
                sql: "origem <> 'DECLARADA' OR (uf IS NOT NULL AND numero IS NOT NULL AND declarado_em IS NOT NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_educador_cref_origem",
                table: "educador_cref",
                sql: "origem IN ('AUTOMATICA','LEGADO','DECLARADA')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "educador_cref_foto");

            migrationBuilder.DropCheckConstraint(
                name: "ck_educador_cref_automatica_completa",
                table: "educador_cref");

            migrationBuilder.DropCheckConstraint(
                name: "ck_educador_cref_declarada_completa",
                table: "educador_cref");

            migrationBuilder.DropCheckConstraint(
                name: "ck_educador_cref_origem",
                table: "educador_cref");

            migrationBuilder.DropColumn(
                name: "declarado_em",
                table: "educador_cref");

            migrationBuilder.AddCheckConstraint(
                name: "ck_educador_cref_automatica_completa",
                table: "educador_cref",
                sql: "origem = 'LEGADO' OR (uf IS NOT NULL AND numero IS NOT NULL AND situacao IS NOT NULL AND categoria IS NOT NULL AND consultado_em IS NOT NULL)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_educador_cref_origem",
                table: "educador_cref",
                sql: "origem IN ('AUTOMATICA','LEGADO')");
        }
    }
}
