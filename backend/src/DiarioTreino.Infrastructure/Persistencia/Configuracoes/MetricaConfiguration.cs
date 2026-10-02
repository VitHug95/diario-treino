using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class MetricaConfiguration : IEntityTypeConfiguration<Metrica>
{
    public void Configure(EntityTypeBuilder<Metrica> builder)
    {
        builder.ToTable("metrica", t => t.HasCheckConstraint(
            "ck_metrica_eixo",
            $"eixo IN ('{EixoMetrica.Intensidade}','{EixoMetrica.Volume}')"));

        builder.HasKey(m => m.Id);
        // smallint; id atribuído pela aplicação (tabela de referência).
        builder.Property(m => m.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(m => m.Codigo).HasColumnName("codigo").HasMaxLength(30).IsRequired();
        builder.Property(m => m.Nome).HasColumnName("nome").HasMaxLength(60).IsRequired();
        builder.Property(m => m.Unidade).HasColumnName("unidade").HasMaxLength(20).IsRequired();
        builder.Property(m => m.Eixo).HasColumnName("eixo").HasMaxLength(20).IsRequired();

        builder.HasIndex(m => m.Codigo).IsUnique();

        // Seed da carga inicial (MER 3.4).
        builder.HasData(
            new Metrica { Id = MetricaCodigos.CargaKg, Codigo = "CARGA_KG", Nome = "Carga", Unidade = "kg", Eixo = EixoMetrica.Intensidade },
            new Metrica { Id = MetricaCodigos.PesoCorporal, Codigo = "PESO_CORPORAL", Nome = "Peso corporal", Unidade = "-", Eixo = EixoMetrica.Intensidade },
            new Metrica { Id = MetricaCodigos.Zona, Codigo = "ZONA", Nome = "Zona", Unidade = "1 a 5", Eixo = EixoMetrica.Intensidade },
            new Metrica { Id = MetricaCodigos.Repeticoes, Codigo = "REPETICOES", Nome = "Repetições", Unidade = "rep", Eixo = EixoMetrica.Volume },
            new Metrica { Id = MetricaCodigos.TempoSeg, Codigo = "TEMPO_SEG", Nome = "Tempo", Unidade = "s", Eixo = EixoMetrica.Volume },
            new Metrica { Id = MetricaCodigos.DistanciaM, Codigo = "DISTANCIA_M", Nome = "Distância", Unidade = "m", Eixo = EixoMetrica.Volume });
    }
}
