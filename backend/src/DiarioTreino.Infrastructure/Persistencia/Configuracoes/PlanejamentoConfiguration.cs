using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Planejamento;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class PlanoTreinoConfiguration : IEntityTypeConfiguration<PlanoTreino>
{
    public void Configure(EntityTypeBuilder<PlanoTreino> builder)
    {
        builder.ToTable("plano_treino", t => t.HasCheckConstraint(
            "ck_plano_treino_em_uso_ativo", "NOT em_uso OR ativo"));

        builder.HasKey(p => p.Id);
        builder.Property(p => p.Id).HasColumnName("id");
        builder.Property(p => p.AutorId).HasColumnName("autor_id").IsRequired();
        builder.Property(p => p.AtletaId).HasColumnName("atleta_id").IsRequired();
        builder.Property(p => p.Nome).HasColumnName("nome").HasMaxLength(80).IsRequired();
        builder.Property(p => p.Inicio).HasColumnName("inicio").IsRequired();
        builder.Property(p => p.Fim).HasColumnName("fim");
        builder.Property(p => p.Ativo).HasColumnName("ativo").HasDefaultValue(true).IsRequired();
        builder.Property(p => p.EmUso).HasColumnName("em_uso").HasDefaultValue(false).IsRequired();

        // No máximo um plano EM USO por atleta (índice único parcial). Substitui
        // o antigo filtro por "ativo": agora "ativo" só marca o plano excluído
        // com histórico, e "em uso" é o que a Início segue (PBI-44).
        builder.HasIndex(p => p.AtletaId)
            .IsUnique()
            .HasFilter("em_uso")
            .HasDatabaseName("ux_plano_atleta_em_uso");

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

        builder.HasMany(te => te.Marcadores)
            .WithOne(m => m.TreinoExercicio!)
            .HasForeignKey(m => m.TreinoExercicioId)
            .OnDelete(DeleteBehavior.Cascade);

        // Bloco conjugado (PBI-101). Desfazer o bloco é sempre feito pela
        // aplicação (que passa o descanso do bloco aos membros); o SET NULL é
        // só a rede de segurança e não briga com a cascata da ficha.
        builder.Property(te => te.BlocoId).HasColumnName("bloco_id");
        builder.HasOne(te => te.Bloco)
            .WithMany(b => b.Membros)
            .HasForeignKey(te => te.BlocoId)
            .OnDelete(DeleteBehavior.SetNull);
        builder.HasIndex(te => te.BlocoId).HasDatabaseName("ix_treino_exercicio_bloco");
    }
}

public sealed class BlocoExercicioConfiguration : IEntityTypeConfiguration<BlocoExercicio>
{
    public void Configure(EntityTypeBuilder<BlocoExercicio> builder)
    {
        builder.ToTable("bloco_exercicio", t => t.HasCheckConstraint(
            "ck_bloco_exercicio_descanso",
            $"descanso_seg IS NULL OR descanso_seg BETWEEN 0 AND {RegrasBloco.DescansoMaximoSeg}"));

        builder.HasKey(b => b.Id);
        builder.Property(b => b.Id).HasColumnName("id");
        builder.Property(b => b.TreinoId).HasColumnName("treino_id").IsRequired();
        builder.Property(b => b.DescansoSeg).HasColumnName("descanso_seg");

        // Bloco é filho da ficha: apagar a ficha apaga os blocos.
        builder.HasOne(b => b.Treino)
            .WithMany()
            .HasForeignKey(b => b.TreinoId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasIndex(b => b.TreinoId).HasDatabaseName("ix_bloco_exercicio_treino");
    }
}

public sealed class RodadaMarcadorConfiguration : IEntityTypeConfiguration<RodadaMarcador>
{
    public void Configure(EntityTypeBuilder<RodadaMarcador> builder)
    {
        builder.ToTable("rodada_marcador", t =>
        {
            t.HasCheckConstraint("ck_rodada_marcador_rodada", "rodada >= 1");
            // CHECK derivado da fonte única do enum (TV-1).
            t.HasCheckConstraint(
                "ck_rodada_marcador_marcador",
                $"marcador IN ({string.Join(",", TagSerie.Todos.Select(m => $"'{m}'"))})");
        });

        // PK composta (treino_exercicio_id, rodada): uma tag por rodada.
        builder.HasKey(m => new { m.TreinoExercicioId, m.Rodada });
        builder.Property(m => m.TreinoExercicioId).HasColumnName("treino_exercicio_id").IsRequired();
        builder.Property(m => m.Rodada).HasColumnName("rodada").IsRequired();
        builder.Property(m => m.Marcador).HasColumnName("marcador").HasMaxLength(20).IsRequired();
    }
}

public sealed class PlanoDiaSemanaConfiguration : IEntityTypeConfiguration<PlanoDiaSemana>
{
    public void Configure(EntityTypeBuilder<PlanoDiaSemana> builder)
    {
        // Semana planejada do plano (PBI-35). Dia ISO: 1 = segunda … 7 = domingo.
        builder.ToTable("plano_dia_semana", t => t.HasCheckConstraint(
            "ck_plano_dia_semana_dia", "dia_semana BETWEEN 1 AND 7"));

        // PK composta (plano_id, dia_semana): no máximo uma ficha por dia.
        builder.HasKey(d => new { d.PlanoId, d.DiaSemana });
        builder.Property(d => d.PlanoId).HasColumnName("plano_id").IsRequired();
        builder.Property(d => d.DiaSemana).HasColumnName("dia_semana").IsRequired();
        builder.Property(d => d.TreinoId).HasColumnName("treino_id").IsRequired();

        // Apagar o plano apaga a semana dele.
        builder.HasOne<PlanoTreino>()
            .WithMany()
            .HasForeignKey(d => d.PlanoId)
            .OnDelete(DeleteBehavior.Cascade);

        // Apagar a ficha de verdade libera os dias dela (o arquivamento, que não
        // apaga a linha de treino, remove os dias na aplicação).
        builder.HasOne<Treino>()
            .WithMany()
            .HasForeignKey(d => d.TreinoId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(d => d.TreinoId).HasDatabaseName("ix_plano_dia_semana_treino");
    }
}

public sealed class EtapaPrescritaConfiguration : IEntityTypeConfiguration<EtapaPrescrita>
{
    public void Configure(EntityTypeBuilder<EtapaPrescrita> builder)
    {
        builder.ToTable("etapa_prescrita", t =>
        {
            t.HasCheckConstraint(
                "ck_etapa_prescrita_tipo",
                $"tipo IN ('{TipoEtapa.Esforco}','{TipoEtapa.Recuperacao}')");
            // Faixa de volume (TV-2): o máximo, se houver, não pode ser menor
            // que o mínimo (volume_alvo).
            t.HasCheckConstraint(
                "ck_etapa_prescrita_volume_max",
                "volume_alvo_max IS NULL OR volume_alvo_max >= volume_alvo");
        });

        builder.HasKey(e => e.Id);
        builder.Property(e => e.Id).HasColumnName("id");
        builder.Property(e => e.TreinoExercicioId).HasColumnName("treino_exercicio_id").IsRequired();
        builder.Property(e => e.Ordem).HasColumnName("ordem").IsRequired();
        builder.Property(e => e.Tipo).HasColumnName("tipo").HasMaxLength(20).IsRequired();
        builder.Property(e => e.IntensidadeMetricaId).HasColumnName("intensidade_metrica_id").IsRequired();
        builder.Property(e => e.IntensidadeAlvo).HasColumnName("intensidade_alvo").HasPrecision(9, 2);
        builder.Property(e => e.VolumeMetricaId).HasColumnName("volume_metrica_id").IsRequired();
        builder.Property(e => e.VolumeAlvo).HasColumnName("volume_alvo").HasPrecision(9, 2);
        builder.Property(e => e.VolumeAlvoMax).HasColumnName("volume_alvo_max").HasPrecision(9, 2);

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
