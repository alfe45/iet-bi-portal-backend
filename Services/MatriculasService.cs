using iet_bi_portal_backend.Models;
using Npgsql;

namespace iet_bi_portal_backend;

// Acceso a los datos y operaciones de matrícula.
public sealed class MatriculasService(NpgsqlDataSource dataSource)
{
    // Consulta el historial de matrículas de una cédula.
    public async Task<IReadOnlyList<MatriculaResponse>> ListarPorCedulaAsync(string cedula, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand("SELECT * FROM api.obtener_matriculas_estudiante($1);");
        command.Parameters.Add(new NpgsqlParameter { Value = cedula });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var matriculas = new List<MatriculaResponse>();
        while (await reader.ReadAsync(cancellationToken)) matriculas.Add(Mapear(reader));
        return matriculas;
    }

    // Matricula al estudiante en una sección de nivel 10.
    public Task<long> RegistrarNivel10Async(RegistrarMatriculaNivel10Request request, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.matricular_estudiante_en_nivel_10($1, $2, $3, NULL);", new object?[] { request.CedulaEstudiante, request.YearCiclo!.Value, request.NumeroSeccion!.Value }, cancellationToken);

    // Ejecuta la promoción académica definida para nivel 11.
    public Task<long> RegistrarNivel11Async(string cedula, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.matricular_estudiante_en_nivel_11($1, NULL);", new object?[] { cedula }, cancellationToken);

    // Finaliza una matrícula mediante el procedimiento oficial.
    public Task<long> FinalizarAsync(long idMatricula, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.finalizar_matricula($1, NULL);", new object?[] { idMatricula }, cancellationToken);

    // Borra una matrícula usando su identificador.
    public Task<long> BorrarAsync(long idMatricula, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.borrar_matricula($1, NULL);", new object?[] { idMatricula }, cancellationToken);

    private async Task<long> EjecutarIdAsync(string sql, object?[] values, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand(sql);
        foreach (var value in values) command.Parameters.Add(new NpgsqlParameter { Value = value ?? DBNull.Value });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("La base no devolvió el ID de la matrícula.");
        return reader.GetInt64(0);
    }

    private static MatriculaResponse Mapear(NpgsqlDataReader reader) => new(
        reader.GetInt64(0), reader.GetInt32(1), reader.GetInt64(2), reader.GetString(3),
        reader.GetFieldValue<DateTimeOffset>(4), reader.GetValue(5).ToString()!,
        reader.IsDBNull(6) ? null : reader.GetFieldValue<DateTimeOffset>(6));
}
