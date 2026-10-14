using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

/// <summary>
/// Músculos de referência (MER 3.4.2 / PBI-31). O nome é idêntico ao valor de
/// <c>grupo_muscular</c> do catálogo, para a conversão da etapa 1 casar por
/// nome. Chave alternativa <c>(id, membro_id)</c> para ser alvo da FK composta
/// de <c>exercicio</c>.
/// </summary>
public sealed class MusculoConfiguration : IEntityTypeConfiguration<Musculo>
{
    public void Configure(EntityTypeBuilder<Musculo> builder)
    {
        builder.ToTable("musculo");

        builder.HasKey(m => m.Id);
        builder.Property(m => m.Id).HasColumnName("id").ValueGeneratedNever();
        builder.Property(m => m.MembroId).HasColumnName("membro_id").IsRequired();
        builder.Property(m => m.Codigo).HasColumnName("codigo").HasMaxLength(30).IsRequired();
        builder.Property(m => m.Nome).HasColumnName("nome").HasMaxLength(40).IsRequired();

        builder.HasIndex(m => m.Codigo).IsUnique();

        // Alvo da FK composta de exercicio (MER 3.5).
        builder.HasAlternateKey(m => new { m.Id, m.MembroId });

        builder.HasOne<Membro>()
            .WithMany()
            .HasForeignKey(m => m.MembroId)
            .OnDelete(DeleteBehavior.Restrict);

        // Seed (MER 3.4.2). Ids agrupados por membro.
        builder.HasData(
            // Peito
            new Musculo { Id = MusculoCodigos.Peitoral, MembroId = MembroCodigos.Peito, Codigo = "PEITORAL", Nome = "Peitoral" },
            // Costas
            new Musculo { Id = MusculoCodigos.Dorsal, MembroId = MembroCodigos.Costas, Codigo = "DORSAL", Nome = "Dorsal" },
            new Musculo { Id = MusculoCodigos.Trapezio, MembroId = MembroCodigos.Costas, Codigo = "TRAPEZIO", Nome = "Trapézio" },
            // Ombros
            new Musculo { Id = MusculoCodigos.Deltoide, MembroId = MembroCodigos.Ombros, Codigo = "DELTOIDE", Nome = "Deltoide" },
            // Braços
            new Musculo { Id = MusculoCodigos.Biceps, MembroId = MembroCodigos.Bracos, Codigo = "BICEPS", Nome = "Bíceps" },
            new Musculo { Id = MusculoCodigos.Triceps, MembroId = MembroCodigos.Bracos, Codigo = "TRICEPS", Nome = "Tríceps" },
            new Musculo { Id = MusculoCodigos.Antebraco, MembroId = MembroCodigos.Bracos, Codigo = "ANTEBRACO", Nome = "Antebraço" },
            // Pernas
            new Musculo { Id = MusculoCodigos.Quadriceps, MembroId = MembroCodigos.Pernas, Codigo = "QUADRICEPS", Nome = "Quadríceps" },
            new Musculo { Id = MusculoCodigos.PosterioresDeCoxa, MembroId = MembroCodigos.Pernas, Codigo = "POSTERIORES_COXA", Nome = "Posteriores de coxa" },
            new Musculo { Id = MusculoCodigos.Gluteos, MembroId = MembroCodigos.Pernas, Codigo = "GLUTEOS", Nome = "Glúteos" },
            new Musculo { Id = MusculoCodigos.Panturrilha, MembroId = MembroCodigos.Pernas, Codigo = "PANTURRILHA", Nome = "Panturrilha" },
            new Musculo { Id = MusculoCodigos.Adutores, MembroId = MembroCodigos.Pernas, Codigo = "ADUTORES", Nome = "Adutores" },
            // Core
            new Musculo { Id = MusculoCodigos.Abdomen, MembroId = MembroCodigos.Core, Codigo = "ABDOMEN", Nome = "Abdômen" },
            new Musculo { Id = MusculoCodigos.Obliquos, MembroId = MembroCodigos.Core, Codigo = "OBLIQUOS", Nome = "Oblíquos" },
            new Musculo { Id = MusculoCodigos.Lombar, MembroId = MembroCodigos.Core, Codigo = "LOMBAR", Nome = "Lombar" });
    }
}
