using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class ExercicioConfiguration : IEntityTypeConfiguration<Exercicio>
{
    public void Configure(EntityTypeBuilder<Exercicio> builder)
    {
        builder.ToTable("exercicio", t => t.HasCheckConstraint(
            "ck_exercicio_modalidade",
            $"modalidade IN ('{Modalidade.Forca}','{Modalidade.Isometria}','{Modalidade.Cardio}')"));

        builder.HasKey(e => e.Id);
        builder.Property(e => e.Id).HasColumnName("id");
        builder.Property(e => e.Nome).HasColumnName("nome").HasMaxLength(80).IsRequired();
        builder.Property(e => e.MembroId).HasColumnName("membro_id");
        builder.Property(e => e.MusculoId).HasColumnName("musculo_id");
        builder.Property(e => e.Modalidade).HasColumnName("modalidade").HasMaxLength(20).IsRequired();
        builder.Property(e => e.IntensidadeMetricaPadraoId).HasColumnName("intensidade_metrica_padrao_id").IsRequired();
        builder.Property(e => e.VolumeMetricaPadraoId).HasColumnName("volume_metrica_padrao_id").IsRequired();
        builder.Property(e => e.CriadoPorId).HasColumnName("criado_por_id");
        builder.Property(e => e.Ativo).HasColumnName("ativo").HasDefaultValue(true).IsRequired();

        builder.HasOne(e => e.IntensidadeMetricaPadrao)
            .WithMany()
            .HasForeignKey(e => e.IntensidadeMetricaPadraoId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(e => e.VolumeMetricaPadrao)
            .WithMany()
            .HasForeignKey(e => e.VolumeMetricaPadraoId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<Domain.Identidade.Usuario>()
            .WithMany()
            .HasForeignKey(e => e.CriadoPorId)
            .OnDelete(DeleteBehavior.Cascade);

        // Membro (PBI-31). Nulo = ainda não classificado. Restrict: não apaga
        // exercício ao mexer na tabela de referência.
        builder.HasOne(e => e.Membro)
            .WithMany()
            .HasForeignKey(e => e.MembroId)
            .OnDelete(DeleteBehavior.Restrict);

        // Músculo via FK composta (musculo_id, membro_id) → musculo(id, membro_id),
        // garantindo que o músculo pertence ao membro escolhido (MER 3.5).
        builder.HasOne(e => e.Musculo)
            .WithMany()
            .HasForeignKey(e => new { e.MusculoId, e.MembroId })
            .HasPrincipalKey(m => new { m.Id, m.MembroId })
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(e => e.MembroId);

        // O índice único por catálogo usa coalesce(criado_por_id, uuid-zero) e
        // lower(nome); criado via SQL cru na migration (EF não modela expressões).

        builder.HasData(CatalogoGlobalSeed.Exercicios);
    }
}
