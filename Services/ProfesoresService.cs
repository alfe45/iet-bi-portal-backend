using iet_bi_portal_backend.Models;
using Npgsql;

namespace iet_bi_portal_backend;

// Acceso a los datos y operaciones de profesores.
public sealed class ProfesoresService(NpgsqlDataSource dataSource)
{
    // Obtiene la vista pública de profesores.
    public async Task<IReadOnlyList<ProfesorResponse>> ListarAsync(CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand("SELECT * FROM api.obtener_profesores();");
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var profesores = new List<ProfesorResponse>();
        while (await reader.ReadAsync(cancellationToken)) profesores.Add(Mapear(reader));
        return profesores;
    }

    // Genera el hash de la contraseña y registra el profesor mediante PostgreSQL.
    public async Task<long> RegistrarAsync(RegistrarProfesorRequest request, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand("CALL api.registrar_profesor($1, $2, $3, $4, $5, $6, $7, $8, NULL);");
        command.Parameters.Add(new NpgsqlParameter { Value = request.Nombre });
        command.Parameters.Add(new NpgsqlParameter { Value = request.PrimerApellido });
        command.Parameters.Add(new NpgsqlParameter { Value = (object?)request.SegundoApellido ?? DBNull.Value });
        command.Parameters.Add(new NpgsqlParameter { Value = request.Cedula });
        command.Parameters.Add(new NpgsqlParameter { Value = (object?)request.NumeroCelular ?? DBNull.Value });
        command.Parameters.Add(new NpgsqlParameter { Value = request.Email });
        command.Parameters.Add(new NpgsqlParameter { Value = request.FechaNacimiento });
        command.Parameters.Add(new NpgsqlParameter { Value = PasswordHashing.Hash(request.Password) });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("La base no devolvió el ID del profesor creado.");
        return reader.GetInt64(0);
    }

    // Actualiza los datos del profesor y reemplaza su contraseña por un nuevo hash.
    public async Task<long> ActualizarAsync(string cedulaActual, ActualizarProfesorRequest request, CancellationToken cancellationToken)
        => await EjecutarIdAsync("CALL api.actualizar_profesor($1, $2, $3, $4, $5, $6, $7, $8, $9, NULL);", new object?[] { cedulaActual, request.Nombre, request.PrimerApellido, request.SegundoApellido, request.Cedula, request.NumeroCelular, request.Email, request.FechaNacimiento, PasswordHashing.Hash(request.Password) }, cancellationToken);

    public Task<long> ActivarAsync(string cedula, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.activar_profesor($1, NULL);", new object?[] { cedula }, cancellationToken);

    public Task<long> DesactivarAsync(string cedula, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.desactivar_profesor($1, NULL);", new object?[] { cedula }, cancellationToken);

    public Task<long> BorrarAsync(string cedula, CancellationToken cancellationToken)
        => EjecutarIdAsync("CALL api.borrar_profesor($1, NULL);", new object?[] { cedula }, cancellationToken);

    private async Task<long> EjecutarIdAsync(string sql, object?[] values, CancellationToken cancellationToken)
    {
        await using var command = dataSource.CreateCommand(sql);
        foreach (var value in values) command.Parameters.Add(new NpgsqlParameter { Value = value ?? DBNull.Value });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken)) throw new InvalidOperationException("La base no devolvió el ID del profesor.");
        return reader.GetInt64(0);
    }

    private static ProfesorResponse Mapear(NpgsqlDataReader reader) => new(
        reader.GetInt64(0), reader.GetString(1), reader.GetString(2), reader.IsDBNull(3) ? null : reader.GetString(3),
        reader.GetString(4), reader.IsDBNull(5) ? null : reader.GetString(5), reader.GetString(6), reader.GetFieldValue<DateOnly>(7),
        reader.GetFieldValue<DateTime>(8), reader.GetBoolean(9));
}
