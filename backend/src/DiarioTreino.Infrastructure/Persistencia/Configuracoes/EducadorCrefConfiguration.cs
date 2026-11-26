using DiarioTreino.Domain.Educador;
using DiarioTreino.Domain.Identidade;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

/// <summary>Habilitação do educador pelo CREF (PBI-106, MER 3.16).</summary>
public sealed class EducadorCrefConfiguration : IEntityTypeConfiguration<EducadorCref>
{
    public void Configure(EntityTypeBuilder<EducadorCref> builder)
    {
        builder.ToTable("educador_cref", t =>
        {
            t.HasCheckConstraint(
                "ck_educador_cref_origem",
                $"origem IN ('{OrigemCref.Automatica}','{OrigemCref.Legado}')");
            // Consulta automática tem tudo preenchido; só o LEGADO pode vir vazio.
            t.HasCheckConstraint(
                "ck_educador_cref_automatica_completa",
                $"origem = '{OrigemCref.Legado}' OR (uf IS NOT NULL AND numero IS NOT NULL "
                + "AND situacao IS NOT NULL AND categoria IS NOT NULL AND consultado_em IS NOT NULL)");
        });

        builder.HasKey(e => e.UsuarioId);
        builder.Property(e => e.UsuarioId).HasColumnName("usuario_id");
        builder.Property(e => e.Uf).HasColumnName("uf").HasColumnType("char(2)");
        builder.Property(e => e.Numero).HasColumnName("numero").HasMaxLength(20);
        builder.Property(e => e.Situacao).HasColumnName("situacao").HasMaxLength(30);
        builder.Property(e => e.Categoria).HasColumnName("categoria").HasMaxLength(30);
        builder.Property(e => e.Origem).HasColumnName("origem").HasMaxLength(20).IsRequired();
        builder.Property(e => e.ConsultadoEm).HasColumnName("consultado_em");

        // O mesmo registro não habilita duas contas. Os NULL do LEGADO não colidem.
        builder.HasIndex(e => new { e.Uf, e.Numero })
            .IsUnique()
            .HasDatabaseName("ux_educador_cref_uf_numero");

        builder.HasOne<Usuario>().WithOne().HasForeignKey<EducadorCref>(e => e.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

/// <summary>Tentativas de verificação (PBI-106), só para o limite. Sem CPF, número ou nome.</summary>
public sealed class TentativaCrefConfiguration : IEntityTypeConfiguration<TentativaCref>
{
    public void Configure(EntityTypeBuilder<TentativaCref> builder)
    {
        var resultados = string.Join(",", ResultadoCref.Todos.Select(r => $"'{r}'"));
        builder.ToTable("educador_cref_tentativa", t =>
            t.HasCheckConstraint("ck_educador_cref_tentativa_resultado", $"resultado IN ({resultados})"));

        builder.HasKey(t => t.Id);
        builder.Property(t => t.Id).HasColumnName("id");
        builder.Property(t => t.UsuarioId).HasColumnName("usuario_id").IsRequired();
        builder.Property(t => t.Em).HasColumnName("em").IsRequired();
        builder.Property(t => t.Resultado).HasColumnName("resultado").HasMaxLength(30).IsRequired();

        builder.HasIndex(t => new { t.UsuarioId, t.Em }).HasDatabaseName("ix_educador_cref_tentativa_usuario_em");

        builder.HasOne<Usuario>().WithMany().HasForeignKey(t => t.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
