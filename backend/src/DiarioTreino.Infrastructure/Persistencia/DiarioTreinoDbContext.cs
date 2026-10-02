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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(DiarioTreinoDbContext).Assembly);
    }
}
