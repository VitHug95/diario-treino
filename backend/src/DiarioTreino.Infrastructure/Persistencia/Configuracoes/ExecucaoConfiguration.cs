using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Execucao;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class SessaoConfiguration : IEntityTypeConfiguration<Sessao>
{
    public void Configure(EntityTypeBuilder<Sessao> builder)
    {
        builder.ToTable("sessao", t => t.HasCheckConstraint(
            "ck_sessao_data", "data <= current_date + 1"));

        builder.HasKey(s => s.Id);
        builder.Property(s => s.Id).HasColumnName("id");
        builder.Property(s => s.AtletaId).HasColumnName("atleta_id").IsRequired();
        builder.Property(s => s.TreinoId).HasColumnName("treino_id");
        builder.Property(s => s.RegistradoPorId).HasColumnName("registrado_por_id").IsRequired();
        builder.Property(s => s.Data).HasColumnName("data").IsRequired();
        builder.Property(s => s.DuracaoMin).HasColumnName("duracao_min");
        builder.Property(s => s.Observacao).HasColumnName("observacao");
        builder.Property(s => s.CriadoEm).HasColumnName("criado_em").HasDefaultValueSql("now()").IsRequired();
        builder.Property(s => s.AtualizadoEm).HasColumnName("atualizado_em").HasDefaultValueSql("now()").IsRequired();

        // Sessões do período, tela inicial, progresso (MER 4).
        builder.HasIndex(s => new { s.AtletaId, s.Data })
            .IsDescending(false, true)
            .HasDatabaseName("ix_sessao_atleta_data");

        builder.HasOne<Domain.Identidade.Usuario>()
            .WithMany()
            .HasForeignKey(s => s.AtletaId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<Domain.Identidade.Usuario>()
            .WithMany()
            .HasForeignKey(s => s.RegistradoPorId)
            .OnDelete(DeleteBehavior.Restrict);

        // treino_id nulo = sessão montada na hora; não cascata (histórico preservado).
        builder.HasOne<Domain.Planejamento.Treino>()
            .WithMany()
            .HasForeignKey(s => s.TreinoId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(s => s.Series)
            .WithOne(se => se.Sessao!)
            .HasForeignKey(se => se.SessaoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class SerieExecutadaConfiguration : IEntityTypeConfiguration<SerieExecutada>
{
    public void Configure(EntityTypeBuilder<SerieExecutada> builder)
    {
        builder.ToTable("serie_executada", t =>
        {
            t.HasCheckConstraint("ck_serie_executada_volume", "volume >= 0");
            t.HasCheckConstraint(
                "ck_serie_executada_tipo",
                $"tipo IN ('{TipoEtapa.Esforco}','{TipoEtapa.Recuperacao}')");
        });

        builder.HasKey(se => se.Id);
        builder.Property(se => se.Id).HasColumnName("id");
        builder.Property(se => se.SessaoId).HasColumnName("sessao_id").IsRequired();
        builder.Property(se => se.ExercicioId).HasColumnName("exercicio_id").IsRequired();
        builder.Property(se => se.TreinoExercicioId).HasColumnName("treino_exercicio_id");
        builder.Property(se => se.Rodada).HasColumnName("rodada").IsRequired();
        builder.Property(se => se.Ordem).HasColumnName("ordem").IsRequired();
        builder.Property(se => se.Tipo).HasColumnName("tipo").HasMaxLength(20).IsRequired();
        builder.Property(se => se.IntensidadeMetricaId).HasColumnName("intensidade_metrica_id").IsRequired();
        builder.Property(se => se.Intensidade).HasColumnName("intensidade").HasPrecision(9, 2);
        builder.Property(se => se.VolumeMetricaId).HasColumnName("volume_metrica_id").IsRequired();
        builder.Property(se => se.Volume).HasColumnName("volume").HasPrecision(9, 2).IsRequired();
        builder.Property(se => se.DescansoSeg).HasColumnName("descanso_seg");

        // Detalhe da sessão (MER 4).
        builder.HasIndex(se => se.SessaoId).HasDatabaseName("ix_serie_executada_sessao");
        // Última execução do exercício e evolução por exercício (MER 4).
        builder.HasIndex(se => new { se.ExercicioId, se.SessaoId })
            .HasDatabaseName("ix_serie_executada_exercicio_sessao");

        builder.HasOne(se => se.Exercicio)
            .WithMany()
            .HasForeignKey(se => se.ExercicioId)
            .OnDelete(DeleteBehavior.Restrict);

        // Liga ao prescrito; ao remover o prescrito, mantém a série (SET NULL).
        builder.HasOne(se => se.TreinoExercicio)
            .WithMany()
            .HasForeignKey(se => se.TreinoExercicioId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasOne<Domain.Catalogo.Metrica>()
            .WithMany()
            .HasForeignKey(se => se.IntensidadeMetricaId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<Domain.Catalogo.Metrica>()
            .WithMany()
            .HasForeignKey(se => se.VolumeMetricaId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
