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
        builder.Property(e => e.GrupoMuscular).HasColumnName("grupo_muscular").HasMaxLength(40);
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

        // O índice único por catálogo usa coalesce(criado_por_id, uuid-zero) e
        // lower(nome); criado via SQL cru na migration (EF não modela expressões).

        builder.HasData(CatalogoGlobalSeed.Exercicios);
    }
}
