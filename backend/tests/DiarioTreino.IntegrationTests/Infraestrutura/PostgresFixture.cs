using DiarioTreino.Infrastructure.Persistencia;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Testcontainers.PostgreSql;

namespace DiarioTreino.IntegrationTests.Infraestrutura;

/// <summary>
/// Sobe um Postgres real em container (Testcontainers) e aplica as migrations do
/// zero. Compartilhado entre os testes da coleção para subir o container uma vez.
///
/// Sem Docker (ex.: Windows sem o Docker Desktop rodando), dá para apontar para um
/// Postgres local pela variável <c>TESTES_POSTGRES</c> (connection string de um
/// usuário que pode criar banco). Cada execução cria um banco novo, com nome
/// único, aplica as migrations do zero e apaga o banco no fim. No CI a variável
/// não existe e vale o container.
/// </summary>
public sealed class PostgresFixture : IAsyncLifetime
{
    private const string VariavelLocal = "TESTES_POSTGRES";

    private readonly string? _servidorLocal = Environment.GetEnvironmentVariable(VariavelLocal);
    private readonly string _bancoLocal = $"diariotreino_testes_{Guid.NewGuid():n}";

    // Criado só no InitializeAsync e só sem a variável: o Build() do
    // Testcontainers já procura o Docker e falha quando ele não existe.
    private PostgreSqlContainer? _container;

    private bool UsaLocal => !string.IsNullOrWhiteSpace(_servidorLocal);

    public string ConnectionString => UsaLocal
        ? new NpgsqlConnectionStringBuilder(_servidorLocal) { Database = _bancoLocal }.ConnectionString
        : (_container ?? throw new InvalidOperationException("Container não iniciado."))
            .GetConnectionString();

    public async Task InitializeAsync()
    {
        if (UsaLocal)
        {
            await ExecutarNoServidorAsync($"CREATE DATABASE \"{_bancoLocal}\"");
        }
        else
        {
            _container = new PostgreSqlBuilder("postgres:17-alpine")
                .WithDatabase("diariotreino")
                .WithUsername("postgres")
                .WithPassword("postgres")
                .Build();
            await _container.StartAsync();
        }

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

    public async Task DisposeAsync()
    {
        if (UsaLocal)
        {
            NpgsqlConnection.ClearAllPools();
            await ExecutarNoServidorAsync($"DROP DATABASE IF EXISTS \"{_bancoLocal}\" WITH (FORCE)");
        }
        else if (_container is not null)
        {
            await _container.DisposeAsync();
        }
    }

    private async Task ExecutarNoServidorAsync(string sql)
    {
        var servidor = new NpgsqlConnectionStringBuilder(_servidorLocal) { Database = "postgres" };
        await using var conexao = new NpgsqlConnection(servidor.ConnectionString);
        await conexao.OpenAsync();
        await using var comando = new NpgsqlCommand(sql, conexao);
        await comando.ExecuteNonQueryAsync();
    }
}

[CollectionDefinition(Nome)]
public sealed class PostgresCollection : ICollectionFixture<PostgresFixture>
{
    public const string Nome = "postgres";
}