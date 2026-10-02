using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "metrica",
                columns: table => new
                {
                    id = table.Column<short>(type: "smallint", nullable: false),
                    codigo = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    nome = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    unidade = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    eixo = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_metrica", x => x.id);
                    table.CheckConstraint("ck_metrica_eixo", "eixo IN ('INTENSIDADE','VOLUME')");
                });

            migrationBuilder.CreateTable(
                name: "usuario",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    firebase_uid = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    nome = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    email = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: false),
                    ativo = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    criado_em = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_usuario", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "exercicio",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    nome = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    grupo_muscular = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    modalidade = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    intensidade_metrica_padrao_id = table.Column<short>(type: "smallint", nullable: false),
                    volume_metrica_padrao_id = table.Column<short>(type: "smallint", nullable: false),
                    criado_por_id = table.Column<Guid>(type: "uuid", nullable: true),
                    ativo = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_exercicio", x => x.id);
                    table.CheckConstraint("ck_exercicio_modalidade", "modalidade IN ('FORCA','ISOMETRIA','CARDIO')");
                    table.ForeignKey(
                        name: "FK_exercicio_metrica_intensidade_metrica_padrao_id",
                        column: x => x.intensidade_metrica_padrao_id,
                        principalTable: "metrica",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_exercicio_metrica_volume_metrica_padrao_id",
                        column: x => x.volume_metrica_padrao_id,
                        principalTable: "metrica",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_exercicio_usuario_criado_por_id",
                        column: x => x.criado_por_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "plano_treino",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    autor_id = table.Column<Guid>(type: "uuid", nullable: false),
                    atleta_id = table.Column<Guid>(type: "uuid", nullable: false),
                    nome = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    inicio = table.Column<DateOnly>(type: "date", nullable: false),
                    fim = table.Column<DateOnly>(type: "date", nullable: true),
                    ativo = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_plano_treino", x => x.id);
                    table.ForeignKey(
                        name: "FK_plano_treino_usuario_atleta_id",
                        column: x => x.atleta_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_plano_treino_usuario_autor_id",
                        column: x => x.autor_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "usuario_papel",
                columns: table => new
                {
                    usuario_id = table.Column<Guid>(type: "uuid", nullable: false),
                    papel = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_usuario_papel", x => new { x.usuario_id, x.papel });
                    table.CheckConstraint("ck_usuario_papel_papel", "papel IN ('ATLETA','EDUCADOR')");
                    table.ForeignKey(
                        name: "FK_usuario_papel_usuario_usuario_id",
                        column: x => x.usuario_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "vinculo",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    educador_id = table.Column<Guid>(type: "uuid", nullable: false),
                    aluno_id = table.Column<Guid>(type: "uuid", nullable: false),
                    status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    inicio = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    fim = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vinculo", x => x.id);
                    table.CheckConstraint("ck_vinculo_educador_diferente_aluno", "educador_id <> aluno_id");
                    table.CheckConstraint("ck_vinculo_status", "status IN ('PENDENTE','ATIVO','ENCERRADO')");
                    table.ForeignKey(
                        name: "FK_vinculo_usuario_aluno_id",
                        column: x => x.aluno_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_vinculo_usuario_educador_id",
                        column: x => x.educador_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "treino",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    plano_id = table.Column<Guid>(type: "uuid", nullable: false),
                    nome = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    descricao = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    ordem = table.Column<short>(type: "smallint", nullable: false),
                    ativo = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_treino", x => x.id);
                    table.ForeignKey(
                        name: "FK_treino_plano_treino_plano_id",
                        column: x => x.plano_id,
                        principalTable: "plano_treino",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "sessao",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    atleta_id = table.Column<Guid>(type: "uuid", nullable: false),
                    treino_id = table.Column<Guid>(type: "uuid", nullable: true),
                    registrado_por_id = table.Column<Guid>(type: "uuid", nullable: false),
                    data = table.Column<DateOnly>(type: "date", nullable: false),
                    duracao_min = table.Column<short>(type: "smallint", nullable: true),
                    observacao = table.Column<string>(type: "text", nullable: true),
                    criado_em = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    atualizado_em = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_sessao", x => x.id);
                    table.CheckConstraint("ck_sessao_data", "data <= current_date + 1");
                    table.ForeignKey(
                        name: "FK_sessao_treino_treino_id",
                        column: x => x.treino_id,
                        principalTable: "treino",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_sessao_usuario_atleta_id",
                        column: x => x.atleta_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_sessao_usuario_registrado_por_id",
                        column: x => x.registrado_por_id,
                        principalTable: "usuario",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "treino_exercicio",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    treino_id = table.Column<Guid>(type: "uuid", nullable: false),
                    exercicio_id = table.Column<Guid>(type: "uuid", nullable: false),
                    ordem = table.Column<short>(type: "smallint", nullable: false),
                    rodadas = table.Column<short>(type: "smallint", nullable: false),
                    descanso_alvo_seg = table.Column<short>(type: "smallint", nullable: true),
                    observacao = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_treino_exercicio", x => x.id);
                    table.CheckConstraint("ck_treino_exercicio_rodadas", "rodadas > 0");
                    table.ForeignKey(
                        name: "FK_treino_exercicio_exercicio_exercicio_id",
                        column: x => x.exercicio_id,
                        principalTable: "exercicio",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_treino_exercicio_treino_treino_id",
                        column: x => x.treino_id,
                        principalTable: "treino",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "etapa_prescrita",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    treino_exercicio_id = table.Column<Guid>(type: "uuid", nullable: false),
                    ordem = table.Column<short>(type: "smallint", nullable: false),
                    tipo = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    intensidade_metrica_id = table.Column<short>(type: "smallint", nullable: false),
                    intensidade_alvo = table.Column<decimal>(type: "numeric(9,2)", precision: 9, scale: 2, nullable: true),
                    volume_metrica_id = table.Column<short>(type: "smallint", nullable: false),
                    volume_alvo = table.Column<decimal>(type: "numeric(9,2)", precision: 9, scale: 2, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_etapa_prescrita", x => x.id);
                    table.CheckConstraint("ck_etapa_prescrita_tipo", "tipo IN ('ESFORCO','RECUPERACAO')");
                    table.ForeignKey(
                        name: "FK_etapa_prescrita_metrica_intensidade_metrica_id",
                        column: x => x.intensidade_metrica_id,
                        principalTable: "metrica",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_etapa_prescrita_metrica_volume_metrica_id",
                        column: x => x.volume_metrica_id,
                        principalTable: "metrica",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_etapa_prescrita_treino_exercicio_treino_exercicio_id",
                        column: x => x.treino_exercicio_id,
                        principalTable: "treino_exercicio",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "serie_executada",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    sessao_id = table.Column<Guid>(type: "uuid", nullable: false),
                    exercicio_id = table.Column<Guid>(type: "uuid", nullable: false),
                    treino_exercicio_id = table.Column<Guid>(type: "uuid", nullable: true),
                    rodada = table.Column<short>(type: "smallint", nullable: false),
                    ordem = table.Column<short>(type: "smallint", nullable: false),
                    tipo = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    intensidade_metrica_id = table.Column<short>(type: "smallint", nullable: false),
                    intensidade = table.Column<decimal>(type: "numeric(9,2)", precision: 9, scale: 2, nullable: true),
                    volume_metrica_id = table.Column<short>(type: "smallint", nullable: false),
                    volume = table.Column<decimal>(type: "numeric(9,2)", precision: 9, scale: 2, nullable: false),
                    descanso_seg = table.Column<short>(type: "smallint", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_serie_executada", x => x.id);
                    table.CheckConstraint("ck_serie_executada_tipo", "tipo IN ('ESFORCO','RECUPERACAO')");
                    table.CheckConstraint("ck_serie_executada_volume", "volume >= 0");
                    table.ForeignKey(
                        name: "FK_serie_executada_exercicio_exercicio_id",
                        column: x => x.exercicio_id,
                        principalTable: "exercicio",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_serie_executada_metrica_intensidade_metrica_id",
                        column: x => x.intensidade_metrica_id,
                        principalTable: "metrica",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_serie_executada_metrica_volume_metrica_id",
                        column: x => x.volume_metrica_id,
                        principalTable: "metrica",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_serie_executada_sessao_sessao_id",
                        column: x => x.sessao_id,
                        principalTable: "sessao",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_serie_executada_treino_exercicio_treino_exercicio_id",
                        column: x => x.treino_exercicio_id,
                        principalTable: "treino_exercicio",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.InsertData(
                table: "metrica",
                columns: new[] { "id", "codigo", "eixo", "nome", "unidade" },
                values: new object[,]
                {
                    { (short)1, "CARGA_KG", "INTENSIDADE", "Carga", "kg" },
                    { (short)2, "PESO_CORPORAL", "INTENSIDADE", "Peso corporal", "-" },
                    { (short)3, "ZONA", "INTENSIDADE", "Zona", "1 a 5" },
                    { (short)10, "REPETICOES", "VOLUME", "Repetições", "rep" },
                    { (short)11, "TEMPO_SEG", "VOLUME", "Tempo", "s" },
                    { (short)12, "DISTANCIA_M", "VOLUME", "Distância", "m" }
                });

            migrationBuilder.InsertData(
                table: "exercicio",
                columns: new[] { "id", "ativo", "criado_por_id", "grupo_muscular", "intensidade_metrica_padrao_id", "modalidade", "nome", "volume_metrica_padrao_id" },
                values: new object[,]
                {
                    { new Guid("11111111-0000-0000-0000-000000000001"), true, null, "peito", (short)1, "FORCA", "Supino reto", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000002"), true, null, "peito", (short)1, "FORCA", "Supino inclinado", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000003"), true, null, "peito", (short)1, "FORCA", "Crucifixo", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000004"), true, null, "tríceps", (short)1, "FORCA", "Tríceps corda", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000005"), true, null, "pernas", (short)1, "FORCA", "Agachamento livre", (short)10 },
                    { new Guid("11111111-0000-0000-0000-000000000006"), true, null, "costas", (short)1, "FORCA", "Remada curvada", (short)10 },
                    { new Guid("22222222-0000-0000-0000-000000000001"), true, null, "core", (short)2, "ISOMETRIA", "Prancha", (short)11 },
                    { new Guid("22222222-0000-0000-0000-000000000002"), true, null, "pernas", (short)2, "ISOMETRIA", "Agachamento isométrico", (short)11 },
                    { new Guid("33333333-0000-0000-0000-000000000001"), true, null, null, (short)3, "CARDIO", "Corrida", (short)11 },
                    { new Guid("33333333-0000-0000-0000-000000000002"), true, null, null, (short)3, "CARDIO", "Bicicleta", (short)11 }
                });

            migrationBuilder.CreateIndex(
                name: "IX_etapa_prescrita_intensidade_metrica_id",
                table: "etapa_prescrita",
                column: "intensidade_metrica_id");

            migrationBuilder.CreateIndex(
                name: "IX_etapa_prescrita_treino_exercicio_id",
                table: "etapa_prescrita",
                column: "treino_exercicio_id");

            migrationBuilder.CreateIndex(
                name: "IX_etapa_prescrita_volume_metrica_id",
                table: "etapa_prescrita",
                column: "volume_metrica_id");

            migrationBuilder.CreateIndex(
                name: "IX_exercicio_criado_por_id",
                table: "exercicio",
                column: "criado_por_id");

            migrationBuilder.CreateIndex(
                name: "IX_exercicio_intensidade_metrica_padrao_id",
                table: "exercicio",
                column: "intensidade_metrica_padrao_id");

            migrationBuilder.CreateIndex(
                name: "IX_exercicio_volume_metrica_padrao_id",
                table: "exercicio",
                column: "volume_metrica_padrao_id");

            migrationBuilder.CreateIndex(
                name: "IX_metrica_codigo",
                table: "metrica",
                column: "codigo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_plano_treino_autor_id",
                table: "plano_treino",
                column: "autor_id");

            migrationBuilder.CreateIndex(
                name: "ux_plano_atleta_ativo",
                table: "plano_treino",
                column: "atleta_id",
                unique: true,
                filter: "ativo");

            migrationBuilder.CreateIndex(
                name: "ix_serie_executada_exercicio_sessao",
                table: "serie_executada",
                columns: new[] { "exercicio_id", "sessao_id" });

            migrationBuilder.CreateIndex(
                name: "IX_serie_executada_intensidade_metrica_id",
                table: "serie_executada",
                column: "intensidade_metrica_id");

            migrationBuilder.CreateIndex(
                name: "ix_serie_executada_sessao",
                table: "serie_executada",
                column: "sessao_id");

            migrationBuilder.CreateIndex(
                name: "IX_serie_executada_treino_exercicio_id",
                table: "serie_executada",
                column: "treino_exercicio_id");

            migrationBuilder.CreateIndex(
                name: "IX_serie_executada_volume_metrica_id",
                table: "serie_executada",
                column: "volume_metrica_id");

            migrationBuilder.CreateIndex(
                name: "ix_sessao_atleta_data",
                table: "sessao",
                columns: new[] { "atleta_id", "data" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_sessao_registrado_por_id",
                table: "sessao",
                column: "registrado_por_id");

            migrationBuilder.CreateIndex(
                name: "IX_sessao_treino_id",
                table: "sessao",
                column: "treino_id");

            migrationBuilder.CreateIndex(
                name: "ix_treino_plano_ordem",
                table: "treino",
                columns: new[] { "plano_id", "ordem" });

            migrationBuilder.CreateIndex(
                name: "IX_treino_exercicio_exercicio_id",
                table: "treino_exercicio",
                column: "exercicio_id");

            migrationBuilder.CreateIndex(
                name: "ix_treino_exercicio_treino_ordem",
                table: "treino_exercicio",
                columns: new[] { "treino_id", "ordem" });

            migrationBuilder.CreateIndex(
                name: "IX_usuario_email",
                table: "usuario",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_usuario_firebase_uid",
                table: "usuario",
                column: "firebase_uid",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_vinculo_aluno_ativo",
                table: "vinculo",
                column: "aluno_id",
                filter: "status = 'ATIVO'");

            migrationBuilder.CreateIndex(
                name: "ux_vinculo_aberto",
                table: "vinculo",
                columns: new[] { "educador_id", "aluno_id" },
                unique: true,
                filter: "status IN ('PENDENTE','ATIVO')");

            // Índice único por catálogo (MER 3.5): evita nome repetido no mesmo
            // catálogo. Usa expressão (lower + coalesce), que o EF não modela.
            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX ux_exercicio_nome_catalogo
                ON exercicio (lower(nome), coalesce(criado_por_id, '00000000-0000-0000-0000-000000000000'::uuid));
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP INDEX IF EXISTS ux_exercicio_nome_catalogo;");

            migrationBuilder.DropTable(
                name: "etapa_prescrita");

            migrationBuilder.DropTable(
                name: "serie_executada");

            migrationBuilder.DropTable(
                name: "usuario_papel");

            migrationBuilder.DropTable(
                name: "vinculo");

            migrationBuilder.DropTable(
                name: "sessao");

            migrationBuilder.DropTable(
                name: "treino_exercicio");

            migrationBuilder.DropTable(
                name: "exercicio");

            migrationBuilder.DropTable(
                name: "treino");

            migrationBuilder.DropTable(
                name: "metrica");

            migrationBuilder.DropTable(
                name: "plano_treino");

            migrationBuilder.DropTable(
                name: "usuario");
        }
    }
}
