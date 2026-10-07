using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioTreino.Infrastructure.Persistencia.Migrations
{
    /// <inheritdoc />
    public partial class HabilitaUnaccent : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Extensão usada na busca de exercícios sem diferenciar acentos
            // (PBI-10): unaccent('Tríceps') => 'Triceps'.
            migrationBuilder.Sql("CREATE EXTENSION IF NOT EXISTS unaccent;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP EXTENSION IF EXISTS unaccent;");
        }
    }
}
