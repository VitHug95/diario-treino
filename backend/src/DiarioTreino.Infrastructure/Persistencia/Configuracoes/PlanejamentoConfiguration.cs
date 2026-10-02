using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Planejamento;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class PlanoTreinoConfiguration : IEntityTypeConfiguration<PlanoTreino>
{
    public void Configure(EntityTypeBuilder<PlanoTreino> builder)
    {
        builder.ToTable("plano_treino");

        builder.HasKey(p => p.Id);
        builder.Property(p => p.Id).HasColumnName("id");
        builder.Property(p => p.AutorId).HasColumnName("autor_id").IsRequired();
        builder.Property(p => p.AtletaId).HasColumnName("atleta_id").IsRequired();
        builder.Property(p => p.Nome).HasColumnName("nome").HasMaxLength(80).IsRequired();
        builder.Property(p => p.Inicio).HasColumnName("inicio").IsRequired();
        builder.Property(p => p.Fim).HasColumnName("fim");
        builder.Property(p => p.Ativo).HasColumnName("ativo").HasDefaultValue(true).IsRequired();

        // Um plano ativo por atleta (índice único parcial).
        builder.HasIndex(p => p.AtletaId)
            .IsUnique()
            .HasFilter("ativo")
            .HasDatabaseName("ux_plano_atleta_ativo");

        builder.HasOne<Domain.Identidade.Usuario>()
            .WithMany()
            .HasForeignKey(p => p.AutorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<Domain.Identidade.Usuario>()
            .WithMany()
            .HasForeignKey(p => p.AtletaId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(p => p.Treinos)
            .WithOne(t => t.Plano!)
            .HasForeignKey(t => t.PlanoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class TreinoConfiguration : IEntityTypeConfiguration<Treino>
{
    public void Configure(EntityTypeBuilder<Treino> builder)
    {
        builder.ToTable("treino");

        builder.HasKey(t => t.Id);
        builder.Property(t => t.Id).HasColumnName("id");
        builder.Property(t => t.PlanoId).HasColumnName("plano_id").IsRequired();
        builder.Property(t => t.Nome).HasColumnName("nome").HasMaxLength(40).IsRequired();
        builder.Property(t => t.Descricao).HasColumnName("descricao").HasMaxLength(80);
        builder.Property(t => t.Ordem).HasColumnName("ordem").IsRequired();
        builder.Property(t => t.Ativo).HasColumnName("ativo").HasDefaultValue(true).IsRequired();

        builder.HasIndex(t => new { t.PlanoId, t.Ordem }).HasDatabaseName("ix_treino_plano_ordem");

        builder.HasMany(t => t.Exercicios)
            .WithOne(te => te.Treino!)
            .HasForeignKey(te => te.TreinoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class TreinoExercicioConfiguration : IEntityTypeConfiguration<TreinoExercicio>
{
    public void Configure(EntityTypeBuilder<TreinoExercicio> builder)
    {
        builder.ToTable("treino_exercicio", t => t.HasCheckConstraint(
            "ck_treino_exercicio_rodadas", "rodadas > 0"));

        builder.HasKey(te => te.Id);
        builder.Property(te => te.Id).HasColumnName("id");
        builder.Property(te => te.TreinoId).HasColumnName("treino_id").IsRequired();
        builder.Property(te => te.ExercicioId).HasColumnName("exercicio_id").IsRequired();
        builder.Property(te => te.Ordem).HasColumnName("ordem").IsRequired();
        builder.Property(te => te.Rodadas).HasColumnName("rodadas").IsRequired();
        builder.Property(te => te.DescansoAlvoSeg).HasColumnName("descanso_alvo_seg");
        builder.Property(te => te.Observacao).HasColumnName("observacao").HasMaxLength(200);

        builder.HasIndex(te => new { te.TreinoId, te.Ordem })
            .HasDatabaseName("ix_treino_exercicio_treino_ordem");

        builder.HasOne(te => te.Exercicio)
            .WithMany()
            .HasForeignKey(te => te.ExercicioId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(te => te.Etapas)
            .WithOne(e => e.TreinoExercicio!)
            .HasForeignKey(e => e.TreinoExercicioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class EtapaPrescritaConfiguration : IEntityTypeConfiguration<EtapaPrescrita>
{
    public void Configure(EntityTypeBuilder<EtapaPrescrita> builder)
    {
        builder.ToTable("etapa_prescrita", t => t.HasCheckConstraint(
            "ck_etapa_prescrita_tipo",
            $"tipo IN ('{TipoEtapa.Esforco}','{TipoEtapa.Recuperacao}')"));

        builder.HasKey(e => e.Id);
        builder.Property(e => e.Id).HasColumnName("id");
        builder.Property(e => e.TreinoExercicioId).HasColumnName("treino_exercicio_id").IsRequired();
        builder.Property(e => e.Ordem).HasColumnName("ordem").IsRequired();
        builder.Property(e => e.Tipo).HasColumnName("tipo").HasMaxLength(20).IsRequired();
        builder.Property(e => e.IntensidadeMetricaId).HasColumnName("intensidade_metrica_id").IsRequired();
        builder.Property(e => e.IntensidadeAlvo).HasColumnName("intensidade_alvo").HasPrecision(9, 2);
        builder.Property(e => e.VolumeMetricaId).HasColumnName("volume_metrica_id").IsRequired();
        builder.Property(e => e.VolumeAlvo).HasColumnName("volume_alvo").HasPrecision(9, 2);

        builder.HasOne(e => e.IntensidadeMetrica)
            .WithMany()
            .HasForeignKey(e => e.IntensidadeMetricaId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(e => e.VolumeMetrica)
            .WithMany()
            .HasForeignKey(e => e.VolumeMetricaId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
