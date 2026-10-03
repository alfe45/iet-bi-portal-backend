using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Secciones.Models;

namespace iet_bi_portal_backend.Modules.Secciones.Data;

/// <summary>Acceso a las funciones de secciones (CU18 a CU21). Todo por (año, nivel, número).</summary>
public class SeccionesRepository(NpgsqlDataSource db)
{
    private const string Columnas = "anio, nivel::int, numero::int, nombre, cedula_guia, nombre_guia, cantidad_estudiantes";

    /// <summary>Devuelve el nombre de la sección ("10-1"). Errores de la DB: AU009, NF004, SE001, SE002, SE005.</summary>
    public Task<string> RegistrarAsync(Guid actorId, RegistrarSeccionRequest r) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_registrar_seccion($1, $2::integer, $3::integer, $4::integer)",
            actorId, r.Anio, r.Nivel, r.Numero);

    public async Task<ResultadoPaginado<Seccion>> ListarAsync(Guid actorId, ConsultaSecciones c)
    {
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_secciones($1, $2::integer, $3::integer, $4, $5)",
            Leer, actorId, c.Anio, c.Nivel, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>(
            "SELECT academico.fn_admin_contar_secciones($1, $2::integer, $3::integer)", actorId, c.Anio, c.Nivel);
        return new ResultadoPaginado<Seccion>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    public Task<Seccion?> ObtenerAsync(Guid actorId, int anio, int nivel, int numero) =>
        db.PrimeroOpcionalAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_obtener_seccion($1, $2, $3, $4)", Leer, actorId, anio, nivel, numero);

    /// <summary>Elimina la sección y devuelve el snapshot previo en JSON. Errores: NF006, SE006, 23001.</summary>
    public Task<string> EliminarAsync(Guid actorId, int anio, int nivel, int numero) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_eliminar_seccion($1, $2, $3, $4)::text", actorId, anio, nivel, numero);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo. Errores: NF006, NF002, SE003, SE004.</summary>
    public Task<(string Estado, string? Anteriores)> AsignarGuiaAsync(
        Guid actorId, int anio, int nivel, int numero, string cedulaProfesor) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_asignar_guia_seccion($1, $2, $3, $4, $5::text)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, anio, nivel, numero, cedulaProfesor);

    /// <summary>Devuelve OK/SIN_CAMBIOS (no tenía guía) y el snapshot previo. Error: NF006.</summary>
    public Task<(string Estado, string? Anteriores)> QuitarGuiaAsync(Guid actorId, int anio, int nivel, int numero) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text FROM academico.fn_admin_quitar_guia_seccion($1, $2, $3, $4)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, anio, nivel, numero);

    /// <summary>Guía CU01: secciones de las que el usuario es guía en un año (null = periodo en curso; NF005).</summary>
    public Task<List<Seccion>> ListarMisSeccionesGuiaAsync(Guid idUsuario, int? anio) =>
        db.ListarAsync($"SELECT {Columnas} FROM academico.fn_profesor_listar_mis_secciones_guia($1, $2::integer)", Leer, idUsuario, anio);

    private static Seccion Leer(NpgsqlDataReader r) => new(
        r.GetInt32(0),
        r.GetInt32(1),
        r.GetInt32(2),
        r.GetString(3),
        r.IsDBNull(4) ? null : r.GetString(4),
        r.IsDBNull(5) ? null : r.GetString(5),
        r.GetInt64(6));
}
