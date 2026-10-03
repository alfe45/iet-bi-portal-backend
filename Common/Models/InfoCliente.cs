namespace iet_bi_portal_backend.Common.Models;

/// <summary>Datos del cliente HTTP (para sesiones y auditoría).</summary>
public record InfoCliente(string? Ip, string? UserAgent);
