using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Profesores.Models;

namespace iet_bi_portal_backend.Modules.Profesores.Data;

/// <summary>Acceso a las funciones de administración de profesores (CU08 a CU11). Todo por cédula.</summary>
public class ProfesoresRepository(NpgsqlDataSource db)
{
    private const string Columnas =
        "nombre, primer_apellido, segundo_apellido, cedula, numero_celular, fecha_nacimiento, id_usuario, email";

    /// <summary>Devuelve la cédula normalizada. Errores de la DB: AU009, NF001, PR001, PR002.</summary>
    public Task<string> RegistrarAsync(Guid actorId, RegistrarProfesorRequest r) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_registrar_profesor($1, $2, $3::text, $4::text, $5::text, $6::text, $7::text, $8::date)",
            actorId, r.IdUsuario, r.Nombre, r.PrimerApellido, r.SegundoApellido, r.Cedula, r.NumeroCelular, r.FechaNacimiento);

    public Task<ResultadoPaginado<ProfesorAdmin>> ListarAsync(int pagina, int tamanoPagina) =>
        db.ListarPaginadoAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_profesores($1, $2)",
            "SELECT academico.fn_admin_contar_profesores()",
            Leer, pagina, tamanoPagina);

    public Task<ProfesorAdmin?> ObtenerAsync(string cedula) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM academico.fn_admin_obtener_profesor($1::text)", Leer, cedula);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo en JSON (null si no hubo cambios). Error: NF002.</summary>
    public Task<(string Estado, string? Anteriores)> ActualizarAsync(Guid actorId, string cedula, ActualizarProfesorRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_actualizar_profesor($1, $2::text, $3::text, $4::text, $5::text, $6::text, $7::date)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, cedula, r.Nombre, r.PrimerApellido, r.SegundoApellido, r.NumeroCelular, r.FechaNacimiento);

    /// <summary>Elimina el perfil y devuelve el snapshot previo en JSON. Error: NF002.</summary>
    public Task<string> EliminarAsync(Guid actorId, string cedula) =>
        db.EscalarAsync<string>("SELECT academico.fn_admin_eliminar_profesor($1, $2::text)", actorId, cedula);

    private static ProfesorAdmin Leer(NpgsqlDataReader r) => new(
        r.GetString(0),
        r.GetString(1),
        r.IsDBNull(2) ? null : r.GetString(2),
        r.GetString(3),
        r.IsDBNull(4) ? null : r.GetString(4),
        r.GetFieldValue<DateOnly>(5),
        r.GetGuid(6),
        r.GetString(7));
}
