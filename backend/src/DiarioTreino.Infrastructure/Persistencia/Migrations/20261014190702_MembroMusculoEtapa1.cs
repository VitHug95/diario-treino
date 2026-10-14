using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class MembroMusculoEtapa1 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "membro_id",
                table: "exercicio",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "musculo_id",
                table: "exercicio",
                type: "smallint",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "membro",
                columns: table => new
                {
                    id = table.Column<short>(type: "smallint", nullable: false),
                    codigo = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    nome = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    ordem = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_membro", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "musculo",
                columns: table => new
                {
                    id = table.Column<short>(type: "smallint", nullable: false),
                    membro_id = table.Column<short>(type: "smallint", nullable: false),
                    codigo = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    nome = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_musculo", x => x.id);
                    table.UniqueConstraint("AK_musculo_id_membro_id", x => new { x.id, x.membro_id });
                    table.ForeignKey(
                        name: "FK_musculo_membro_membro_id",
                        column: x => x.membro_id,
                        principalTable: "membro",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000005"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000006"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000011"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000012"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000013"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000014"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000015"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000016"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000017"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000018"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000019"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-00000000001a"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-00000000001b"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)1, (short)1 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000005"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000006"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000007"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000008"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000009"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)2 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000a"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)3 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000b"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)2, (short)3 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000c"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22222222-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)13 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22222222-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000005"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000006"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000007"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000008"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000009"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)3, (short)4 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33333333-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33333333-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { null, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)5 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)5 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)5 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)5 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000005"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)5 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000006"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)5 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000007"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)6 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000008"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)6 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000009"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)6 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000a"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)6 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000b"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)6 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000c"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)6 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000d"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)6 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000e"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)7 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000f"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)4, (short)7 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000005"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000006"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000007"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000008"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)8 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000009"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)9 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000a"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)9 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000b"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)9 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000c"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)10 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000d"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)10 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000e"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)10 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000f"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)12 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000010"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)12 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000011"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)11 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000012"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)5, (short)11 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)13 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)13 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)13 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)13 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000006"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)14 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000007"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)14 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000008"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)14 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000009"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)15 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-00000000000a"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)6, (short)15 });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000005"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000006"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000007"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000008"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)7, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000001"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)8, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000002"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)8, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000003"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)8, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000004"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)8, null });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000005"),
                columns: new[] { "membro_id", "musculo_id" },
                values: new object[] { (short)8, null });

            migrationBuilder.InsertData(
                table: "membro",
                columns: new[] { "id", "codigo", "nome", "ordem" },
                values: new object[,]
                {
                    { (short)1, "PEITO", "Peito", (short)1 },
                    { (short)2, "COSTAS", "Costas", (short)2 },
                    { (short)3, "OMBROS", "Ombros", (short)3 },
                    { (short)4, "BRACOS", "Braços", (short)4 },
                    { (short)5, "PERNAS", "Pernas", (short)5 },
                    { (short)6, "CORE", "Core", (short)6 },
                    { (short)7, "CARDIO", "Cardio", (short)7 },
                    { (short)8, "MOBILIDADE", "Mobilidade", (short)8 }
                });

            migrationBuilder.InsertData(
                table: "musculo",
                columns: new[] { "id", "codigo", "membro_id", "nome" },
                values: new object[,]
                {
                    { (short)1, "PEITORAL", (short)1, "Peitoral" },
                    { (short)2, "DORSAL", (short)2, "Dorsal" },
                    { (short)3, "TRAPEZIO", (short)2, "Trapézio" },
                    { (short)4, "DELTOIDE", (short)3, "Deltoide" },
                    { (short)5, "BICEPS", (short)4, "Bíceps" },
                    { (short)6, "TRICEPS", (short)4, "Tríceps" },
                    { (short)7, "ANTEBRACO", (short)4, "Antebraço" },
                    { (short)8, "QUADRICEPS", (short)5, "Quadríceps" },
                    { (short)9, "POSTERIORES_COXA", (short)5, "Posteriores de coxa" },
                    { (short)10, "GLUTEOS", (short)5, "Glúteos" },
                    { (short)11, "PANTURRILHA", (short)5, "Panturrilha" },
                    { (short)12, "ADUTORES", (short)5, "Adutores" },
                    { (short)13, "ABDOMEN", (short)6, "Abdômen" },
                    { (short)14, "OBLIQUOS", (short)6, "Oblíquos" },
                    { (short)15, "LOMBAR", (short)6, "Lombar" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_exercicio_membro_id",
                table: "exercicio",
                column: "membro_id");

            migrationBuilder.CreateIndex(
                name: "IX_exercicio_musculo_id_membro_id",
                table: "exercicio",
                columns: new[] { "musculo_id", "membro_id" });

            migrationBuilder.CreateIndex(
                name: "IX_membro_codigo",
                table: "membro",
                column: "codigo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_musculo_codigo",
                table: "musculo",
                column: "codigo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_musculo_membro_id",
                table: "musculo",
                column: "membro_id");

            migrationBuilder.AddForeignKey(
                name: "FK_exercicio_membro_membro_id",
                table: "exercicio",
                column: "membro_id",
                principalTable: "membro",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_exercicio_musculo_musculo_id_membro_id",
                table: "exercicio",
                columns: new[] { "musculo_id", "membro_id" },
                principalTable: "musculo",
                principalColumns: new[] { "id", "membro_id" },
                onDelete: ReferentialAction.Restrict);

            // ───────── Conversão dos exercícios PRÓPRIOS dos usuários ─────────
            // Os globais já receberam membro_id/musculo_id pelo UpdateData acima
            // (vêm do seed). Aqui classificamos os exercícios criados por
            // usuários (criado_por_id IS NOT NULL) a partir do texto livre
            // grupo_muscular, sem acento e sem caixa (função unaccent já
            // habilitada por migration anterior). O que não casar com nenhum
            // músculo nem com o nome/código de um membro vira "resíduo" e é
            // apagado junto das dependências (decisão do PO: tudo é teste).
            migrationBuilder.Sql(
                """
                -- 1) Classifica pelo nome do músculo (define membro + músculo).
                UPDATE exercicio e
                SET musculo_id = m.id, membro_id = m.membro_id
                FROM musculo m
                WHERE e.criado_por_id IS NOT NULL
                  AND e.membro_id IS NULL
                  AND lower(unaccent(e.grupo_muscular)) = lower(unaccent(m.nome));

                -- 2) Classifica pelo membro (nome ou código), sem músculo.
                --    Cobre "peito", "costas", "pernas", "core", "cardio", etc.
                UPDATE exercicio e
                SET membro_id = mb.id
                FROM membro mb
                WHERE e.criado_por_id IS NOT NULL
                  AND e.membro_id IS NULL
                  AND lower(unaccent(e.grupo_muscular)) IN (lower(unaccent(mb.nome)), lower(mb.codigo));

                -- 3) Cardio sem grupo vai para o membro Cardio; isometria sem
                --    grupo (mobilidade/alongamento) vai para Mobilidade.
                UPDATE exercicio e SET membro_id = 7
                WHERE e.criado_por_id IS NOT NULL AND e.membro_id IS NULL
                  AND e.grupo_muscular IS NULL AND e.modalidade = 'CARDIO';
                UPDATE exercicio e SET membro_id = 8
                WHERE e.criado_por_id IS NOT NULL AND e.membro_id IS NULL
                  AND e.grupo_muscular IS NULL AND e.modalidade = 'ISOMETRIA';

                -- 4) Resíduo = exercício próprio que não casou com nada. Apaga as
                --    dependências antes do exercício (FKs Restrict de
                --    treino_exercicio e serie_executada para exercicio).
                CREATE TEMPORARY TABLE _residuo AS
                SELECT id FROM exercicio
                WHERE criado_por_id IS NOT NULL AND membro_id IS NULL;

                -- Séries executadas do exercício resíduo.
                DELETE FROM serie_executada
                WHERE exercicio_id IN (SELECT id FROM _residuo);

                -- Sessões que ficaram sem nenhuma série (vazias) após o passo acima.
                DELETE FROM sessao s
                WHERE NOT EXISTS (
                    SELECT 1 FROM serie_executada se WHERE se.sessao_id = s.id);

                -- Itens de ficha (prescrição) do exercício resíduo
                -- (etapa_prescrita cai em cascata sob treino_exercicio).
                DELETE FROM treino_exercicio
                WHERE exercicio_id IN (SELECT id FROM _residuo);

                -- Enfim, os exercícios resíduo.
                DELETE FROM exercicio
                WHERE id IN (SELECT id FROM _residuo);

                DROP TABLE _residuo;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_exercicio_membro_membro_id",
                table: "exercicio");

            migrationBuilder.DropForeignKey(
                name: "FK_exercicio_musculo_musculo_id_membro_id",
                table: "exercicio");

            migrationBuilder.DropTable(
                name: "musculo");

            migrationBuilder.DropTable(
                name: "membro");

            migrationBuilder.DropIndex(
                name: "IX_exercicio_membro_id",
                table: "exercicio");

            migrationBuilder.DropIndex(
                name: "IX_exercicio_musculo_id_membro_id",
                table: "exercicio");

            migrationBuilder.DropColumn(
                name: "membro_id",
                table: "exercicio");

            migrationBuilder.DropColumn(
                name: "musculo_id",
                table: "exercicio");
        }
    }
}
