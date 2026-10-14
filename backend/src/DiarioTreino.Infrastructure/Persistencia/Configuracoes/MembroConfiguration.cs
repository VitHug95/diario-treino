using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

/// <summary>
/// Membros de referência (MER 3.4.1 / PBI-31). Id smallint atribuído pela
/// aplicação, como as demais tabelas de referência.
/// </summary>
public sealed class MembroConfiguration : IEntityTypeConfiguration<Membro>
{
    public void Configure(EntityTypeBuilder<Membro> builder)
    {
        builder.ToTable("membro");

        builder.HasKey(m => m.Id);
        builder.Property(m => m.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(m => m.Codigo).HasColumnName("codigo").HasMaxLength(30).IsRequired();
        builder.Property(m => m.Nome).HasColumnName("nome").HasMaxLength(40).IsRequired();
        builder.Property(m => m.Ordem).HasColumnName("ordem").IsRequired();

        builder.HasIndex(m => m.Codigo).IsUnique();

        // Seed (MER 3.4.1). codigo em ASCII; nome com acento.
        builder.HasData(
            new Membro { Id = MembroCodigos.Peito, Codigo = "PEITO", Nome = "Peito", Ordem = 1 },
            new Membro { Id = MembroCodigos.Costas, Codigo = "COSTAS", Nome = "Costas", Ordem = 2 },
            new Membro { Id = MembroCodigos.Ombros, Codigo = "OMBROS", Nome = "Ombros", Ordem = 3 },
            new Membro { Id = MembroCodigos.Bracos, Codigo = "BRACOS", Nome = "Braços", Ordem = 4 },
            new Membro { Id = MembroCodigos.Pernas, Codigo = "PERNAS", Nome = "Pernas", Ordem = 5 },
            new Membro { Id = MembroCodigos.Core, Codigo = "CORE", Nome = "Core", Ordem = 6 },
            new Membro { Id = MembroCodigos.Cardio, Codigo = "CARDIO", Nome = "Cardio", Ordem = 7 },
            new Membro { Id = MembroCodigos.Mobilidade, Codigo = "MOBILIDADE", Nome = "Mobilidade", Ordem = 8 });
    }
}
