using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DiarioTreino.IntegrationTests;

public sealed class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public HealthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Health_responde_200()
    {
        var client = _factory.CreateClient();

        var resposta = await client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
    }

    [Fact]
    public async Task Health_devolve_cabecalho_de_correlacao()
    {
        var client = _factory.CreateClient();

        var resposta = await client.GetAsync("/health");

        Assert.True(resposta.Headers.Contains("X-Correlation-Id"));
    }
}
