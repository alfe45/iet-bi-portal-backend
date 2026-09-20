using iet_bi_portal_backend.Models;
using Npgsql;

namespace iet_bi_portal_backend;

// Acceso a los datos y operaciones de cursos lectivos.
public sealed class CursosLectivosService(NpgsqlDataSource dataSource)
{
    // Obtiene los cursos lectivos publicados por PostgreSQL.
    public async Task<IReadOnlyList<CursoLectivoResponse>> ListarAsync(CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand("SELECT * FROM api.obtener_cursos_lectivos();");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var cursos = new List<CursoLectivoResponse>();
        while (await reader.ReadAsync(cancellationToken)) cursos.Add(new(reader.GetInt64(0), reader.GetInt32(1), reader.GetFieldValue<DateOnly>(2), reader.GetFieldValue<DateOnly>(3)));
        return cursos;
    }

    // Abre un curso y sus dos semestres.
    public Task<long> AbrirAsync(CursoLectivoRequest request, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.abrir_curso_lectivo($1, $2, $3, $4, $5, NULL);", request, cancellationToken);

    // Actualiza las fechas del curso lectivo y sus semestres.
    public Task<long> ActualizarAsync(CursoLectivoRequest request, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.actualizar_curso_lectivo($1, $2, $3, $4, $5, NULL);", request, cancellationToken);

    // Borra un curso lectivo por su año.
    public Task<long> BorrarAsync(int yearCiclo, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.borrar_curso_lectivo($1, NULL);", new CursoLectivoRequest(yearCiclo, null, null, null, null), cancellationToken);

    private async Task<long> EjecutarIdAsync(string sql, CursoLectivoRequest request, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand(sql);
        object?[] values = sql.Contains("$5")
            ? new object?[] { request.YearCiclo, request.FechaInicioI, request.FechaFinI, request.FechaInicioII, request.FechaFinII }
            : new object?[] { request.YearCiclo };
        foreach (var value in values) command.Parameters.Add(new NpgsqlParameter { Value = value ?? DBNull.Value });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("La base no devolvió el ID del curso lectivo.");
        return reader.GetInt64(0);
    }
}
