using DiarioTreino.Domain.Corpo;
using DiarioTreino.Domain.Identidade;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class MedidaCorporalConfiguration : IEntityTypeConfiguration<MedidaCorporal>
{
    public void Configure(EntityTypeBuilder<MedidaCorporal> builder)
    {
        // No banco fica só o CHECK geral (valor > 0) e a lista de tipos; a faixa
        // por tipo é validada na aplicação (TipoMedida.Faixa).
        var tipos = string.Join(",", TipoMedida.Todos.Select(t => $"'{t}'"));
        builder.ToTable("medida_corporal", t =>
        {
            t.HasCheckConstraint("ck_medida_corporal_tipo", $"tipo IN ({tipos})");
            t.HasCheckConstraint("ck_medida_corporal_valor", "valor > 0");
        });

        builder.HasKey(m => m.Id);
        builder.Property(m => m.Id).HasColumnName("id");
        builder.Property(m => m.UsuarioId).HasColumnName("usuario_id").IsRequired();
        builder.Property(m => m.Data).HasColumnName("data").IsRequired();
        builder.Property(m => m.Tipo).HasColumnName("tipo").HasMaxLength(24).IsRequired();
        builder.Property(m => m.Valor).HasColumnName("valor").HasPrecision(5, 1).IsRequired();
        builder.Property(m => m.CriadoEm).HasColumnName("criado_em")
            .HasDefaultValueSql("now()").IsRequired();

        // Uma medição por dia e tipo: salvar de novo no mesmo dia atualiza.
        builder.HasIndex(m => new { m.UsuarioId, m.Data, m.Tipo })
            .IsUnique()
            .HasDatabaseName("ux_medida_corporal_usuario_data_tipo");

        // Última medida e evolução por tipo.
        builder.HasIndex(m => new { m.UsuarioId, m.Tipo, m.Data })
            .IsDescending(false, false, true)
            .HasDatabaseName("ix_medida_corporal_usuario_tipo_data");

        // As medidas somem junto com a conta (DELETE /me).
        builder.HasOne<Usuario>()
            .WithMany()
            .HasForeignKey(m => m.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
