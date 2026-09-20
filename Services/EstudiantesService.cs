using iet_bi_portal_backend.Models;
using Npgsql;

namespace iet_bi_portal_backend;

// Acceso a los datos y operaciones de estudiantes.
public sealed class EstudiantesService(NpgsqlDataSource dataSource)
{
    // Obtiene todos los estudiantes publicados por PostgreSQL.
    public async Task<IReadOnlyList<EstudianteResponse>> ListarAsync(CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand("SELECT * FROM api.obtener_estudiantes();");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var estudiantes = new List<EstudianteResponse>();
        while (await reader.ReadAsync(cancellationToken)) estudiantes.Add(Mapear(reader));
        return estudiantes;
    }

    // Registra un estudiante usando la regla oficial de PostgreSQL.
    public Task<long> RegistrarAsync(RegistrarEstudianteRequest request, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.registrar_estudiante($1, $2, $3, $4, $5, $6, $7, NULL);", new object?[] { request.Nombre, request.PrimerApellido, request.SegundoApellido, request.Cedula, request.NumeroCelular, request.Email, request.FechaNacimiento }, cancellationToken);

    // Actualiza un estudiante identificado por su cédula actual.
    public Task<long> ActualizarAsync(string cedulaActual, ActualizarEstudianteRequest request, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.actualizar_estudiante($1, $2, $3, $4, $5, $6, $7, $8, NULL);", new object?[] { cedulaActual, request.Nombre, request.PrimerApellido, request.SegundoApellido, request.Cedula, request.NumeroCelular, request.Email, request.FechaNacimiento }, cancellationToken);

    // Borra un estudiante mediante el procedimiento SQL correspondiente.
    public Task<long> BorrarAsync(string cedula, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.borrar_estudiante($1, NULL);", new object?[] { cedula }, cancellationToken);

    private async Task<long> EjecutarIdAsync(string sql, object?[] values, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand(sql);
        foreach (var value in values) command.Parameters.Add(new NpgsqlParameter { Value = value ?? DBNull.Value });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("La base no devolvió el ID del estudiante.");
        return reader.GetInt64(0);
    }

    private static EstudianteResponse Mapear(NpgsqlDataReader reader) => new(
        reader.GetInt64(0), reader.GetString(1), reader.GetString(2), reader.IsDBNull(3) ? null : reader.GetString(3),
        reader.GetString(4), reader.IsDBNull(5) ? null : reader.GetString(5), reader.GetString(6),
        reader.GetFieldValue<DateOnly>(7), reader.GetFieldValue<DateTime>(8));
}
