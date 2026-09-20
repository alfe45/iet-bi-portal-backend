using iet_bi_portal_backend.Models;
using Npgsql;

namespace iet_bi_portal_backend;

// Acceso a los datos y operaciones de secciones.
public sealed class SeccionesService(NpgsqlDataSource dataSource)
{
    // Obtiene las secciones publicadas y asociadas a su curso lectivo.
    public async Task<IReadOnlyList<SeccionResponse>> ListarAsync(CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand("SELECT * FROM api.obtener_secciones();");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var secciones = new List<SeccionResponse>();
        while (await reader.ReadAsync(cancellationToken)) secciones.Add(new(reader.GetInt64(0), reader.GetInt32(1), reader.GetString(2)));
        return secciones;
    }

    // Registra una combinación de curso, nivel y número de sección.
    public Task<long> RegistrarAsync(RegistrarSeccionRequest request, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.registrar_seccion($1, $2, $3, NULL);", new object?[] { request.YearCiclo!.Value, request.Nivel!.Value, request.NumeroSeccion!.Value }, cancellationToken);

    // Borra una sección por los datos que la identifican en el SQL.
    public Task<long> BorrarAsync(int yearCiclo, int nivel, int numeroSeccion, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.borrar_seccion($1, $2, $3, NULL);", new object?[] { yearCiclo, nivel, numeroSeccion }, cancellationToken);

    private async Task<long> EjecutarIdAsync(string sql, object?[] values, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand(sql);
        foreach (var value in values) command.Parameters.Add(new NpgsqlParameter { Value = value ?? DBNull.Value });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("La base no devolvió el ID de la sección.");
        return reader.GetInt64(0);
    }
}
