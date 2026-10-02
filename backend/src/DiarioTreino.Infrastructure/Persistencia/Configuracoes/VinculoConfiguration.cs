using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Vinculos;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class VinculoConfiguration : IEntityTypeConfiguration<Vinculo>
{
    public void Configure(EntityTypeBuilder<Vinculo> builder)
    {
        builder.ToTable("vinculo", t =>
        {
            t.HasCheckConstraint(
                "ck_vinculo_status",
                $"status IN ('{StatusVinculo.Pendente}','{StatusVinculo.Ativo}','{StatusVinculo.Encerrado}')");
            t.HasCheckConstraint("ck_vinculo_educador_diferente_aluno", "educador_id <> aluno_id");
        });

        builder.HasKey(v => v.Id);
        builder.Property(v => v.Id).HasColumnName("id");
        builder.Property(v => v.EducadorId).HasColumnName("educador_id").IsRequired();
        builder.Property(v => v.AlunoId).HasColumnName("aluno_id").IsRequired();
        builder.Property(v => v.Status).HasColumnName("status").HasMaxLength(20).IsRequired();
        builder.Property(v => v.Inicio).HasColumnName("inicio");
        builder.Property(v => v.Fim).HasColumnName("fim");

        // Índice único parcial: não existem dois vínculos abertos entre as mesmas pessoas.
        builder.HasIndex(v => new { v.EducadorId, v.AlunoId })
            .IsUnique()
            .HasFilter($"status IN ('{StatusVinculo.Pendente}','{StatusVinculo.Ativo}')")
            .HasDatabaseName("ux_vinculo_aberto");

        // Regra de acesso do educador (MER 4).
        builder.HasIndex(v => v.AlunoId)
            .HasFilter($"status = '{StatusVinculo.Ativo}'")
            .HasDatabaseName("ix_vinculo_aluno_ativo");

        builder.HasOne<Domain.Identidade.Usuario>()
            .WithMany()
            .HasForeignKey(v => v.EducadorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne<Domain.Identidade.Usuario>()
            .WithMany()
            .HasForeignKey(v => v.AlunoId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
