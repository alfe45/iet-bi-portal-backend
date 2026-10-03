using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Asignaturas.Models;

namespace iet_bi_portal_backend.Modules.Asignaturas.Data;

/// <summary>Acceso a las funciones de asignaturas (CU26 a CU29). Todo por código.</summary>
public class AsignaturasRepository(NpgsqlDataSource db)
{
    private const string Columnas = "codigo, nombre::text, tipo::text, descripcion, imparte_nivel_10, imparte_nivel_11";

    /// <summary>Devuelve el código normalizado. Errores de la DB: AU009, AS001 a AS004.</summary>
    public Task<string> RegistrarAsync(Guid actorId, RegistrarAsignaturaRequest r) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_registrar_asignatura($1, $2::text, $3::text, $4::academico.tipo_asignatura, $5::text, $6::boolean, $7::boolean)",
            actorId, r.Codigo, r.Nombre, r.Tipo.ToUpperInvariant(), r.Descripcion, r.ImparteNivel10, r.ImparteNivel11);

    public async Task<ResultadoPaginado<Asignatura>> ListarAsync(Guid actorId, ConsultaAsignaturas c)
    {
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_asignaturas($1, $2::academico.tipo_asignatura, $3::integer, $4, $5)",
            Leer, actorId, c.Tipo?.ToUpperInvariant(), c.Nivel, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>(
            "SELECT academico.fn_admin_contar_asignaturas($1, $2::academico.tipo_asignatura, $3::integer)", actorId, c.Tipo?.ToUpperInvariant(), c.Nivel);
        return new ResultadoPaginado<Asignatura>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    public Task<Asignatura?> ObtenerAsync(Guid actorId, string codigo) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM academico.fn_admin_obtener_asignatura($1, $2::text)", Leer, actorId, codigo);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo en JSON. Errores: NF007, AS002, AS003, AS006, AS007, AS008.</summary>
    public Task<(string Estado, string? Anteriores)> ActualizarAsync(Guid actorId, string codigo, ActualizarAsignaturaRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_actualizar_asignatura($1, $2::text, $3::text, $4::academico.tipo_asignatura, $5::text, $6::boolean, $7::boolean)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, codigo, r.Nombre, r.Tipo.ToUpperInvariant(), r.Descripcion, r.ImparteNivel10, r.ImparteNivel11);

    /// <summary>Elimina la asignatura y devuelve el snapshot previo en JSON. Errores: NF007, 23001.</summary>
    public Task<string> EliminarAsync(Guid actorId, string codigo) =>
        db.EscalarAsync<string>("SELECT academico.fn_admin_eliminar_asignatura($1, $2::text)::text", actorId, codigo);

    private static Asignatura Leer(NpgsqlDataReader r) => new(
        r.GetString(0),
        r.GetString(1),
        r.GetString(2),
        r.IsDBNull(3) ? null : r.GetString(3),
        r.GetBoolean(4),
        r.GetBoolean(5));
}
