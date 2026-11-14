using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Corpo;
using DiarioTreino.Domain.Identidade;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

public sealed class UsuarioConfiguration : IEntityTypeConfiguration<Usuario>
{
    public void Configure(EntityTypeBuilder<Usuario> builder)
    {
        builder.ToTable("usuario", t =>
        {
            // Nulo passa nos dois CHECKs: os dados corporais são opcionais.
            t.HasCheckConstraint(
                "ck_usuario_sexo",
                $"sexo IN ('{SexoBiologico.Masculino}','{SexoBiologico.Feminino}')");
            t.HasCheckConstraint("ck_usuario_altura_cm", "altura_cm BETWEEN 100 AND 250");
            t.HasCheckConstraint(
                "ck_usuario_tmb_manual_kcal",
                $"tmb_manual_kcal BETWEEN {CalculoTmb.ManualMinimaKcal} AND {CalculoTmb.ManualMaximaKcal}");
        });

        builder.HasKey(u => u.Id);
        builder.Property(u => u.Id).HasColumnName("id");
        builder.Property(u => u.FirebaseUid).HasColumnName("firebase_uid").HasMaxLength(128).IsRequired();
        builder.Property(u => u.Nome).HasColumnName("nome").HasMaxLength(120).IsRequired();
        builder.Property(u => u.Email).HasColumnName("email").HasMaxLength(254).IsRequired();
        builder.Property(u => u.Ativo).HasColumnName("ativo").HasDefaultValue(true).IsRequired();
        builder.Property(u => u.CriadoEm).HasColumnName("criado_em")
            .HasDefaultValueSql("now()").IsRequired();

        builder.Property(u => u.Sexo).HasColumnName("sexo").HasColumnType("character(1)");
        builder.Property(u => u.DataNascimento).HasColumnName("data_nascimento");
        builder.Property(u => u.AlturaCm).HasColumnName("altura_cm");
        builder.Property(u => u.TmbManualKcal).HasColumnName("tmb_manual_kcal");
        // Compartilhamento com o educador (PBI-95): nulo = trancado.
        builder.Property(u => u.DadosCorporaisCompartilhadosEm).HasColumnName("dados_corporais_compartilhados_em");
        builder.Property(u => u.MedidasCompartilhadasEm).HasColumnName("medidas_compartilhadas_em");

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

public sealed class ConsentimentoConfiguration : IEntityTypeConfiguration<Consentimento>
{
    public void Configure(EntityTypeBuilder<Consentimento> builder)
    {
        builder.ToTable("consentimento");

        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).HasColumnName("id");
        builder.Property(c => c.UsuarioId).HasColumnName("usuario_id").IsRequired();
        builder.Property(c => c.VersaoTermo).HasColumnName("versao_termo").HasMaxLength(20).IsRequired();
        builder.Property(c => c.AceitoEm).HasColumnName("aceito_em")
            .HasDefaultValueSql("now()").IsRequired();

        // Um aceite por usuário e versão: re-aceitar a mesma versão não duplica.
        builder.HasIndex(c => new { c.UsuarioId, c.VersaoTermo })
            .IsUnique()
            .HasDatabaseName("ux_consentimento_usuario_versao");

        builder.HasOne(c => c.Usuario!)
            .WithMany()
            .HasForeignKey(c => c.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
