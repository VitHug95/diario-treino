using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class CatalogoExerciciosCompleto : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Aposenta (ativo=false) os genéricos do seed original que mantiveram
            // o nome. Soft-delete em vez de DELETE: FKs em treino_exercicio e
            // serie_executada são Restrict e já pode haver histórico ligado
            // (regra de dados: nada é apagado fisicamente). O filtro do catálogo
            // (Ativo) os esconde. O EF não detecta a troca de ativo em linhas de
            // HasData cujo nome não mudou, então é feito explicitamente aqui.
            foreach (var id in new[]
            {
                "11111111-0000-0000-0000-000000000002", // Supino inclinado
                "11111111-0000-0000-0000-000000000003", // Crucifixo
                "11111111-0000-0000-0000-000000000006", // Remada curvada
                "22222222-0000-0000-0000-000000000002", // Agachamento isométrico
                "33333333-0000-0000-0000-000000000002", // Bicicleta
                "11111111-0000-0000-0000-000000000004", // Tríceps corda (antigo)
                "33333333-0000-0000-0000-000000000001", // Corrida (antigo)
            })
            {
                migrationBuilder.UpdateData(
                    table: "exercicio",
                    keyColumn: "id",
                    keyValue: new Guid(id),
                    column: "ativo",
                    value: false);
            }

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000001"),
                columns: new[] { "grupo_muscular", "nome" },
                values: new object[] { "Peitoral", "Supino reto com barra" });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000004"),
                column: "nome",
                value: "Tríceps corda (antigo)");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: "Quadríceps");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22222222-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "Abdômen");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33333333-0000-0000-0000-000000000001"),
                column: "nome",
                value: "Corrida (antigo)");

            migrationBuilder.InsertData(
                table: "exercicio",
                columns: new[] { "id", "ativo", "criado_por_id", "grupo_muscular", "intensidade_metrica_padrao_id", "modalidade", "nome", "volume_metrica_padrao_id" },
                values: new object[,]
                {
                    { new Guid("11111111-0000-0000-0000-000000000011"), true, null, "Peitoral", (short)1, "FORCA", "Supino reto com halteres", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000012"), true, null, "Peitoral", (short)1, "FORCA", "Supino inclinado com barra", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000013"), true, null, "Peitoral", (short)1, "FORCA", "Supino inclinado com halteres", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000014"), true, null, "Peitoral", (short)1, "FORCA", "Supino declinado", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000015"), true, null, "Peitoral", (short)1, "FORCA", "Supino na máquina", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000016"), true, null, "Peitoral", (short)1, "FORCA", "Crucifixo reto com halteres", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000017"), true, null, "Peitoral", (short)1, "FORCA", "Crucifixo inclinado", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000018"), true, null, "Peitoral", (short)1, "FORCA", "Peck deck", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000019"), true, null, "Peitoral", (short)1, "FORCA", "Crossover na polia", (short)10 },
                    { new Guid("11111111-0000-0000-0000-00000000001a"), true, null, "Peitoral", (short)2, "FORCA", "Flexão de braço", (short)10 },
                    { new Guid("11111111-0000-0000-0000-00000000001b"), true, null, "Peitoral", (short)2, "FORCA", "Paralelas para peito", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000001"), true, null, "Dorsal", (short)1, "FORCA", "Puxada frontal", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000002"), true, null, "Dorsal", (short)1, "FORCA", "Puxada supinada", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000003"), true, null, "Dorsal", (short)2, "FORCA", "Barra fixa", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000004"), true, null, "Dorsal", (short)1, "FORCA", "Remada curvada com barra", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000005"), true, null, "Dorsal", (short)1, "FORCA", "Remada unilateral com halter, o serrote", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000006"), true, null, "Dorsal", (short)1, "FORCA", "Remada baixa na polia", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000007"), true, null, "Dorsal", (short)1, "FORCA", "Remada cavalinho", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000008"), true, null, "Dorsal", (short)1, "FORCA", "Remada na máquina", (short)10 },
                    { new Guid("22220000-0000-0000-0000-000000000009"), true, null, "Dorsal", (short)1, "FORCA", "Pulldown com braço estendido", (short)10 },
                    { new Guid("22220000-0000-0000-0000-00000000000a"), true, null, "Trapézio", (short)1, "FORCA", "Encolhimento com halteres", (short)10 },
                    { new Guid("22220000-0000-0000-0000-00000000000b"), true, null, "Trapézio", (short)1, "FORCA", "Encolhimento com barra", (short)10 },
                    { new Guid("22220000-0000-0000-0000-00000000000c"), true, null, null, (short)1, "FORCA", "Levantamento terra", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000001"), true, null, "Deltoide", (short)1, "FORCA", "Desenvolvimento com halteres", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000002"), true, null, "Deltoide", (short)1, "FORCA", "Desenvolvimento militar com barra", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000003"), true, null, "Deltoide", (short)1, "FORCA", "Desenvolvimento na máquina", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000004"), true, null, "Deltoide", (short)1, "FORCA", "Elevação lateral com halteres", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000005"), true, null, "Deltoide", (short)1, "FORCA", "Elevação lateral na polia", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000006"), true, null, "Deltoide", (short)1, "FORCA", "Elevação frontal", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000007"), true, null, "Deltoide", (short)1, "FORCA", "Crucifixo invertido", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000008"), true, null, "Deltoide", (short)1, "FORCA", "Face pull", (short)10 },
                    { new Guid("33330000-0000-0000-0000-000000000009"), true, null, "Deltoide", (short)1, "FORCA", "Remada alta", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000001"), true, null, "Bíceps", (short)1, "FORCA", "Rosca direta com barra", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000002"), true, null, "Bíceps", (short)1, "FORCA", "Rosca alternada com halteres", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000003"), true, null, "Bíceps", (short)1, "FORCA", "Rosca martelo", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000004"), true, null, "Bíceps", (short)1, "FORCA", "Rosca scott", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000005"), true, null, "Bíceps", (short)1, "FORCA", "Rosca concentrada", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000006"), true, null, "Bíceps", (short)1, "FORCA", "Rosca na polia", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000007"), true, null, "Tríceps", (short)1, "FORCA", "Tríceps corda", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000008"), true, null, "Tríceps", (short)1, "FORCA", "Tríceps pulley com barra", (short)10 },
                    { new Guid("44440000-0000-0000-0000-000000000009"), true, null, "Tríceps", (short)1, "FORCA", "Tríceps testa", (short)10 },
                    { new Guid("44440000-0000-0000-0000-00000000000a"), true, null, "Tríceps", (short)1, "FORCA", "Tríceps francês", (short)10 },
                    { new Guid("44440000-0000-0000-0000-00000000000b"), true, null, "Tríceps", (short)1, "FORCA", "Tríceps coice", (short)10 },
                    { new Guid("44440000-0000-0000-0000-00000000000c"), true, null, "Tríceps", (short)1, "FORCA", "Supino fechado", (short)10 },
                    { new Guid("44440000-0000-0000-0000-00000000000d"), true, null, "Tríceps", (short)2, "FORCA", "Mergulho no banco", (short)10 },
                    { new Guid("44440000-0000-0000-0000-00000000000e"), true, null, "Antebraço", (short)1, "FORCA", "Rosca de punho", (short)10 },
                    { new Guid("44440000-0000-0000-0000-00000000000f"), true, null, "Antebraço", (short)1, "FORCA", "Rosca inversa", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000002"), true, null, "Quadríceps", (short)1, "FORCA", "Agachamento no smith", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000003"), true, null, "Quadríceps", (short)1, "FORCA", "Leg press 45°", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000004"), true, null, "Quadríceps", (short)1, "FORCA", "Hack machine", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000005"), true, null, "Quadríceps", (short)1, "FORCA", "Cadeira extensora", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000006"), true, null, "Quadríceps", (short)1, "FORCA", "Afundo com halteres", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000007"), true, null, "Quadríceps", (short)1, "FORCA", "Agachamento búlgaro", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000008"), true, null, "Quadríceps", (short)2, "ISOMETRIA", "Agachamento isométrico na parede", (short)11 },
                    { new Guid("55550000-0000-0000-0000-000000000009"), true, null, "Posteriores de coxa", (short)1, "FORCA", "Mesa flexora", (short)10 },
                    { new Guid("55550000-0000-0000-0000-00000000000a"), true, null, "Posteriores de coxa", (short)1, "FORCA", "Cadeira flexora", (short)10 },
                    { new Guid("55550000-0000-0000-0000-00000000000b"), true, null, "Posteriores de coxa", (short)1, "FORCA", "Stiff", (short)10 },
                    { new Guid("55550000-0000-0000-0000-00000000000c"), true, null, "Glúteos", (short)1, "FORCA", "Elevação pélvica", (short)10 },
                    { new Guid("55550000-0000-0000-0000-00000000000d"), true, null, "Glúteos", (short)1, "FORCA", "Glúteo na polia", (short)10 },
                    { new Guid("55550000-0000-0000-0000-00000000000e"), true, null, "Glúteos", (short)1, "FORCA", "Cadeira abdutora", (short)10 },
                    { new Guid("55550000-0000-0000-0000-00000000000f"), true, null, "Adutores", (short)1, "FORCA", "Cadeira adutora", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000010"), true, null, "Adutores", (short)1, "FORCA", "Agachamento sumô", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000011"), true, null, "Panturrilha", (short)1, "FORCA", "Panturrilha em pé", (short)10 },
                    { new Guid("55550000-0000-0000-0000-000000000012"), true, null, "Panturrilha", (short)1, "FORCA", "Panturrilha sentado", (short)10 },
                    { new Guid("66660000-0000-0000-0000-000000000001"), true, null, "Abdômen", (short)2, "FORCA", "Abdominal supra", (short)10 },
                    { new Guid("66660000-0000-0000-0000-000000000002"), true, null, "Abdômen", (short)2, "FORCA", "Elevação de pernas", (short)10 },
                    { new Guid("66660000-0000-0000-0000-000000000003"), true, null, "Abdômen", (short)1, "FORCA", "Abdominal na polia", (short)10 },
                    { new Guid("66660000-0000-0000-0000-000000000004"), true, null, "Abdômen", (short)2, "FORCA", "Roda abdominal", (short)10 },
                    { new Guid("66660000-0000-0000-0000-000000000006"), true, null, "Oblíquos", (short)2, "ISOMETRIA", "Prancha lateral", (short)11 },
                    { new Guid("66660000-0000-0000-0000-000000000007"), true, null, "Oblíquos", (short)2, "FORCA", "Rotação russa", (short)10 },
                    { new Guid("66660000-0000-0000-0000-000000000008"), true, null, "Oblíquos", (short)2, "FORCA", "Abdominal bicicleta", (short)10 },
                    { new Guid("66660000-0000-0000-0000-000000000009"), true, null, "Lombar", (short)2, "FORCA", "Extensão lombar no banco romano", (short)10 },
                    { new Guid("66660000-0000-0000-0000-00000000000a"), true, null, "Lombar", (short)2, "ISOMETRIA", "Superman", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000001"), true, null, null, (short)3, "CARDIO", "Corrida", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000002"), true, null, null, (short)3, "CARDIO", "Esteira", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000003"), true, null, null, (short)3, "CARDIO", "Bicicleta ergométrica", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000004"), true, null, null, (short)3, "CARDIO", "Elíptico", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000005"), true, null, null, (short)3, "CARDIO", "Simulador de escada", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000006"), true, null, null, (short)3, "CARDIO", "Remo ergômetro", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000007"), true, null, null, (short)3, "CARDIO", "Pular corda", (short)11 },
                    { new Guid("77770000-0000-0000-0000-000000000008"), true, null, null, (short)3, "CARDIO", "Caminhada", (short)11 },
                    { new Guid("88880000-0000-0000-0000-000000000001"), true, null, null, (short)2, "ISOMETRIA", "Alongamento de posteriores", (short)11 },
                    { new Guid("88880000-0000-0000-0000-000000000002"), true, null, null, (short)2, "ISOMETRIA", "Alongamento de quadríceps", (short)11 },
                    { new Guid("88880000-0000-0000-0000-000000000003"), true, null, null, (short)2, "ISOMETRIA", "Mobilidade de quadril", (short)11 },
                    { new Guid("88880000-0000-0000-0000-000000000004"), true, null, null, (short)2, "ISOMETRIA", "Mobilidade de ombro", (short)11 },
                    { new Guid("88880000-0000-0000-0000-000000000005"), true, null, null, (short)2, "ISOMETRIA", "Equilíbrio unipodal", (short)11 }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Reativa os genéricos aposentados no Up (soft-delete).
            foreach (var id in new[]
            {
                "11111111-0000-0000-0000-000000000002",
                "11111111-0000-0000-0000-000000000003",
                "11111111-0000-0000-0000-000000000006",
                "22222222-0000-0000-0000-000000000002",
                "33333333-0000-0000-0000-000000000002",
                "11111111-0000-0000-0000-000000000004",
                "33333333-0000-0000-0000-000000000001",
            })
            {
                migrationBuilder.UpdateData(
                    table: "exercicio",
                    keyColumn: "id",
                    keyValue: new Guid(id),
                    column: "ativo",
                    value: true);
            }

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000011"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000012"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000013"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000014"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000015"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000016"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000017"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000018"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000019"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-00000000001a"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-00000000001b"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000001"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000004"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000005"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000006"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000007"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000008"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-000000000009"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000a"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000b"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22220000-0000-0000-0000-00000000000c"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000001"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000004"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000005"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000006"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000007"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000008"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33330000-0000-0000-0000-000000000009"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000001"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000004"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000005"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000006"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000007"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000008"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-000000000009"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000a"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000b"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000c"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000d"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000e"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("44440000-0000-0000-0000-00000000000f"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000004"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000005"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000006"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000007"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000008"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000009"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000a"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000b"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000c"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000d"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000e"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-00000000000f"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000010"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000011"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("55550000-0000-0000-0000-000000000012"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000001"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000004"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000006"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000007"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000008"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-000000000009"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("66660000-0000-0000-0000-00000000000a"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000001"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000004"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000005"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000006"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000007"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("77770000-0000-0000-0000-000000000008"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000001"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000003"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000004"));

            migrationBuilder.DeleteData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("88880000-0000-0000-0000-000000000005"));

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000001"),
                columns: new[] { "grupo_muscular", "nome" },
                values: new object[] { "peito", "Supino reto" });

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000004"),
                column: "nome",
                value: "Tríceps corda");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("11111111-0000-0000-0000-000000000005"),
                column: "grupo_muscular",
                value: "pernas");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("22222222-0000-0000-0000-000000000001"),
                column: "grupo_muscular",
                value: "core");

            migrationBuilder.UpdateData(
                table: "exercicio",
                keyColumn: "id",
                keyValue: new Guid("33333333-0000-0000-0000-000000000001"),
                column: "nome",
                value: "Corrida");
        }
    }
}
