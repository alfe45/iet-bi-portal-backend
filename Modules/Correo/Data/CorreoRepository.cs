using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Modules.Correo.Models;

namespace iet_bi_portal_backend.Modules.Correo.Data;

/// <summary>Destinatarios del correo a una sección (Profesor Regular CU12).</summary>
public class CorreoRepository(NpgsqlDataSource db)
{
    /// <summary>Estudiantes sin retiro de la sección (cedulas null o vacío = todos). Errores: NF006, AD003, NF009 (cédula
    /// no matriculada o retirada), CO003 (nadie a quien enviar).</summary>
    public Task<List<DestinatarioCorreo>> DestinatariosAsync(Guid idUsuario, int anio, int nivel, int numero, List<string>? cedulas) =>
        db.ListarAsync(
            "SELECT cedula, nombre_estudiante, email::text, nombre_profesor, email_profesor::text " +
            "FROM academico.fn_profesor_destinatarios_correo($1, $2::integer, $3::integer, $4::integer, $5::text[])",
            r => new DestinatarioCorreo(r.GetString(0), r.GetString(1), r.GetString(2), r.GetString(3), r.GetString(4)),
            idUsuario, anio, nivel, numero, cedulas?.ToArray());
}
