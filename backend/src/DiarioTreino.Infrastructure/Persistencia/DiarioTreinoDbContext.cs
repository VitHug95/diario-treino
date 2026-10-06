using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Execucao;
using DiarioTreino.Domain.Identidade;
using DiarioTreino.Domain.Planejamento;
using DiarioTreino.Domain.Vinculos;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

/// <summary>
/// Contexto EF Core com todas as tabelas do MER, incluindo as preparadas para o
/// futuro (<see cref="Vinculos"/>). As configurações ficam em classes
/// <c>IEntityTypeConfiguration</c> aplicadas por reflexão.
/// </summary>
public class DiarioTreinoDbContext : DbContext
{
    public DiarioTreinoDbContext(DbContextOptions<DiarioTreinoDbContext> options)
        : base(options)
    {
    }

    public DbSet<Usuario> Usuarios => Set<Usuario>();
    public DbSet<UsuarioPapel> UsuarioPapeis => Set<UsuarioPapel>();
    public DbSet<Vinculo> Vinculos => Set<Vinculo>();
    public DbSet<Metrica> Metricas => Set<Metrica>();
    public DbSet<Exercicio> Exercicios => Set<Exercicio>();
    public DbSet<PlanoTreino> PlanosTreino => Set<PlanoTreino>();
    public DbSet<Treino> Treinos => Set<Treino>();
    public DbSet<TreinoExercicio> TreinoExercicios => Set<TreinoExercicio>();
    public DbSet<EtapaPrescrita> EtapasPrescritas => Set<EtapaPrescrita>();
    public DbSet<Sessao> Sessoes => Set<Sessao>();
    public DbSet<SerieExecutada> SeriesExecutadas => Set<SerieExecutada>();

    /// <summary>
    /// Mapeia a função <c>unaccent</c> do Postgres (extensão habilitada por
    /// migration), para usar em consultas LINQ e buscar sem acento (PBI-10).
    /// </summary>
    public static string Unaccent(string texto) =>
        throw new NotSupportedException("Só pode ser usada em consultas EF.");

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(DiarioTreinoDbContext).Assembly);

        modelBuilder
            .HasDbFunction(typeof(DiarioTreinoDbContext).GetMethod(nameof(Unaccent))!)
            .HasName("unaccent");
    }
}
