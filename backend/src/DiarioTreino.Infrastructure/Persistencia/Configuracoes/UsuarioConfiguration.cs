using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Identidade;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class UsuarioConfiguration : IEntityTypeConfiguration<Usuario>
{
    public void Configure(EntityTypeBuilder<Usuario> builder)
    {
        builder.ToTable("usuario");

        builder.HasKey(u => u.Id);
        builder.Property(u => u.Id).HasColumnName("id");
        builder.Property(u => u.FirebaseUid).HasColumnName("firebase_uid").HasMaxLength(128).IsRequired();
        builder.Property(u => u.Nome).HasColumnName("nome").HasMaxLength(120).IsRequired();
        builder.Property(u => u.Email).HasColumnName("email").HasMaxLength(254).IsRequired();
        builder.Property(u => u.Ativo).HasColumnName("ativo").HasDefaultValue(true).IsRequired();
        builder.Property(u => u.CriadoEm).HasColumnName("criado_em")
            .HasDefaultValueSql("now()").IsRequired();

        builder.HasIndex(u => u.FirebaseUid).IsUnique();
        builder.HasIndex(u => u.Email).IsUnique();

        builder.HasMany(u => u.Papeis)
            .WithOne(p => p.Usuario!)
            .HasForeignKey(p => p.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class UsuarioPapelConfiguration : IEntityTypeConfiguration<UsuarioPapel>
{
    public void Configure(EntityTypeBuilder<UsuarioPapel> builder)
    {
        builder.ToTable("usuario_papel", t => t.HasCheckConstraint(
            "ck_usuario_papel_papel",
            $"papel IN ('{Papeis.Atleta}','{Papeis.Educador}')"));

        builder.HasKey(p => new { p.UsuarioId, p.Papel });
        builder.Property(p => p.UsuarioId).HasColumnName("usuario_id");
        builder.Property(p => p.Papel).HasColumnName("papel").HasMaxLength(20).IsRequired();
    }
}
