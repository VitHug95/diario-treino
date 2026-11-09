using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class MedidaCorporal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "medida_corporal",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    usuario_id = table.Column<Guid>(type: "uuid", nullable: false),
                    data = table.Column<DateOnly>(type: "date", nullable: false),
                    tipo = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    valor = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    criado_em = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_medida_corporal", x => x.id);
                    table.CheckConstraint("ck_medida_corporal_tipo", "tipo IN ('PESO','PESCOCO','OMBROS','PEITO','CINTURA','QUADRIL','BRACO_D','BRACO_E','COXA_D','COXA_E','PANTURRILHA_D','PANTURRILHA_E')");
                    table.CheckConstraint("ck_medida_corporal_valor", "valor > 0");
                    table.ForeignKey(
                        name: "FK_medida_corporal_usuario_usuario_id",
                        column: x => x.usuario_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_medida_corporal_usuario_tipo_data",
                table: "medida_corporal",
                columns: new[] { "usuario_id", "tipo", "data" },
                descending: new[] { false, false, true });

            migrationBuilder.CreateIndex(
                name: "ux_medida_corporal_usuario_data_tipo",
                table: "medida_corporal",
                columns: new[] { "usuario_id", "data", "tipo" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "medida_corporal");
        }
    }
}
