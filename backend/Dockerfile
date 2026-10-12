# Dockerfile da API Diário de Treino (.NET 10). Multi-stage: compila no SDK e
# roda na imagem enxuta de runtime. Contexto de build = pasta backend/.
#
# ATENÇÃO: não testado localmente (Docker bloqueado na máquina de dev). Primeiro
# teste real acontece no deploy (Fly). Prever uma rodada de ajuste.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restaura usando a solução (copiando só os csproj primeiro para cache de layer).
COPY DiarioTreino.slnx ./
COPY Directory.Build.props ./
COPY src/DiarioTreino.Domain/DiarioTreino.Domain.csproj src/DiarioTreino.Domain/
COPY src/DiarioTreino.Application/DiarioTreino.Application.csproj src/DiarioTreino.Application/
COPY src/DiarioTreino.Infrastructure/DiarioTreino.Infrastructure.csproj src/DiarioTreino.Infrastructure/
COPY src/DiarioTreino.Api/DiarioTreino.Api.csproj src/DiarioTreino.Api/
RUN dotnet restore src/DiarioTreino.Api/DiarioTreino.Api.csproj

# Copia o resto e publica.
COPY . ./
RUN dotnet publish src/DiarioTreino.Api/DiarioTreino.Api.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish ./

# O Fly injeta a porta via variável PORT; a API escuta nela (fallback 8080).
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "DiarioTreino.Api.dll"]
