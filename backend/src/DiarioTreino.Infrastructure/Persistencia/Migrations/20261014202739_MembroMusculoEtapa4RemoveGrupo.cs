using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class MembroMusculoEtapa4RemoveGrupo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "grupo_muscular",
                table: "exercicio");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "grupo_muscular",
                table: "exercicio",
                type: "character varying(40)",
                maxLength: 40,
                nullable: true);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: "peito");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: "peito");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: "tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000006"),
                column: "grupo_muscular",
                value: "costas");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000011"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000012"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000013"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000014"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000015"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000016"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000017"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000018"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000019"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-00000000001a"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-00000000001b"),
                column: "grupo_muscular",
                value: "Peitoral");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000006"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000007"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000008"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000009"),
                column: "grupo_muscular",
                value: "Dorsal");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000a"),
                column: "grupo_muscular",
                value: "Trapézio");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000b"),
                column: "grupo_muscular",
                value: "Trapézio");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000c"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22222222-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "Abdômen");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22222222-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: "pernas");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000006"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000007"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000008"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000009"),
                column: "grupo_muscular",
                value: "Deltoide");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33333333-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33333333-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "Bíceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: "Bíceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: "Bíceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: "Bíceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: "Bíceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000006"),
                column: "grupo_muscular",
                value: "Bíceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000007"),
                column: "grupo_muscular",
                value: "Tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000008"),
                column: "grupo_muscular",
                value: "Tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000009"),
                column: "grupo_muscular",
                value: "Tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000a"),
                column: "grupo_muscular",
                value: "Tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000b"),
                column: "grupo_muscular",
                value: "Tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000c"),
                column: "grupo_muscular",
                value: "Tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000d"),
                column: "grupo_muscular",
                value: "Tríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000e"),
                column: "grupo_muscular",
                value: "Antebraço");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000f"),
                column: "grupo_muscular",
                value: "Antebraço");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000006"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000007"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000008"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000009"),
                column: "grupo_muscular",
                value: "Posteriores de coxa");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000a"),
                column: "grupo_muscular",
                value: "Posteriores de coxa");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000b"),
                column: "grupo_muscular",
                value: "Posteriores de coxa");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000c"),
                column: "grupo_muscular",
                value: "Glúteos");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000d"),
                column: "grupo_muscular",
                value: "Glúteos");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000e"),
                column: "grupo_muscular",
                value: "Glúteos");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000f"),
                column: "grupo_muscular",
                value: "Adutores");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000010"),
                column: "grupo_muscular",
                value: "Adutores");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000011"),
                column: "grupo_muscular",
                value: "Panturrilha");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000012"),
                column: "grupo_muscular",
                value: "Panturrilha");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "Abdômen");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: "Abdômen");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: "Abdômen");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: "Abdômen");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000006"),
                column: "grupo_muscular",
                value: "Oblíquos");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000007"),
                column: "grupo_muscular",
                value: "Oblíquos");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000008"),
                column: "grupo_muscular",
                value: "Oblíquos");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000009"),
                column: "grupo_muscular",
                value: "Lombar");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-00000000000a"),
                column: "grupo_muscular",
                value: "Lombar");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000006"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000007"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000008"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000002"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000003"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000004"),
                column: "grupo_muscular",
                value: null);

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: null);
        }
    }
}
