using DiarioTreino.Infrastructure.Persistencia;
using Microsoft.EntityFrameworkCore;
using Testcontainers.PostgreSql;

namespace DiarioTreino.IntegrationTests.Infraestrutura;

/// <summary>
/// Sobe um Postgres real em container (Testcontainers) e aplica as migrations do
/// zero. Compartilhado entre os testes da coleção para subir o container uma vez.
/// </summary>
public sealed class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:17-alpine")
        .WithDatabase("diariotreino")
        .WithUsername("postgres")
        .WithPassword("postgres")
        .Build();

    public string ConnectionString => _container.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _container.StartAsync();

        // Aplica as migrations do zero, validando que o schema sobe sem erro.
        await using var db = CriarContexto();
        await db.Database.MigrateAsync();
    }

    public DiarioTreinoDbContext CriarContexto()
    {
        var options = new DbContextOptionsBuilder<DiarioTreinoDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;

        return new DiarioTreinoDbContext(options);
    }

    public Task DisposeAsync() => _container.DisposeAsync().AsTask();
}

[CollectionDefinition(Nome)]
public sealed class PostgresCollection : ICollectionFixture<PostgresFixture>
{
    public const string Nome = "postgres";
}
