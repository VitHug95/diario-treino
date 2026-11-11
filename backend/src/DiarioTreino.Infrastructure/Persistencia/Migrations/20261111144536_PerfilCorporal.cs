using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class PerfilCorporal : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "altura_cm",
                table: "usuario",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "data_nascimento",
                table: "usuario",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "sexo",
                table: "usuario",
                type: "character(1)",
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_usuario_altura_cm",
                table: "usuario",
                sql: "altura_cm BETWEEN 100 AND 250");

            migrationBuilder.AddCheckConstraint(
                name: "ck_usuario_sexo",
                table: "usuario",
                sql: "sexo IN ('M','F')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_usuario_altura_cm",
                table: "usuario");

            migrationBuilder.DropCheckConstraint(
                name: "ck_usuario_sexo",
                table: "usuario");

            migrationBuilder.DropColumn(
                name: "altura_cm",
                table: "usuario");

            migrationBuilder.DropColumn(
                name: "data_nascimento",
                table: "usuario");

            migrationBuilder.DropColumn(
                name: "sexo",
                table: "usuario");
        }
    }
}
