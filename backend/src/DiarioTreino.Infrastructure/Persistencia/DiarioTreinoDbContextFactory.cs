using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace DiarioTreino.Infrastructure.Persistencia;

/// <summary>
/// Fábrica usada só em tempo de design (ex.: <c>dotnet ef migrations add</c>).
/// A string de conexão aqui não precisa apontar para um banco real; serve apenas
/// para o provider Npgsql montar o modelo. Em produção, a conexão vem da
/// configuração da API (variável de ambiente).
/// </summary>
public sealed class DiarioTreinoDbContextFactory : IDesignTimeDbContextFactory<DiarioTreinoDbContext>
{
    public DiarioTreinoDbContext CreateDbContext(string[] args)
    {
        var connectionString =
            Environment.GetEnvironmentVariable("CONNECTIONSTRINGS__DIARIOTREINO")
            ?? "Host=localhost;Port=5432;Database=diariotreino;Username=postgres;Password=postgres";

        var options = new DbContextOptionsBuilder<DiarioTreinoDbContext>()
            .UseNpgsql(connectionString, npgsql => npgsql.MigrationsAssembly(
                typeof(DiarioTreinoDbContextFactory).Assembly.GetName().Name))
            .Options;

        return new DiarioTreinoDbContext(options);
    }
}
