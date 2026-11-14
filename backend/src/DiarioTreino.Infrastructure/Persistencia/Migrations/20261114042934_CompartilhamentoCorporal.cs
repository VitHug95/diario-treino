using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class CompartilhamentoCorporal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "dados_corporais_compartilhados_em",
                table: "usuario",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "medidas_compartilhadas_em",
                table: "usuario",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "dados_corporais_compartilhados_em",
                table: "usuario");

            migrationBuilder.DropColumn(
                name: "medidas_compartilhadas_em",
                table: "usuario");
        }
    }
}
