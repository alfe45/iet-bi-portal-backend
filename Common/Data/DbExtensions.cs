using Npgsql;
using iet_bi_portal_backend.Common.Models;

namespace iet_bi_portal_backend.Common.Data;

/// <summary>Acceso a datos común para todos los Repository (RP-33). Parámetros posicionales
/// ($1, $2...). Los parámetros que pueden ser null llevan cast explícito en el SQL (ej. $4::text).</summary>
public static class DbExtensions
{
    private static NpgsqlCommand Crear(NpgsqlDataSource db, string sql, object?[] args)
    {
        var cmd = db.CreateCommand(sql);
        foreach (var arg in args)
            cmd.Parameters.AddWithValue(arg ?? DBNull.Value);
        return cmd;
    }

    /// <summary>Ejecuta un CALL / sentencia sin resultado.</summary>
    public static async Task EjecutarAsync(this NpgsqlDataSource db, string sql, params object?[] args)
    {
        await using var cmd = Crear(db, sql, args);
        await cmd.ExecuteNonQueryAsync();
    }

    /// <summary>Primer valor de la primera fila. Lanza si no es del tipo esperado (incluye NULL).</summary>
    public static async Task<T> EscalarAsync<T>(this NpgsqlDataSource db, string sql, params object?[] args)
    {
        await using var cmd = Crear(db, sql, args);
        var resultado = await cmd.ExecuteScalarAsync();
        return resultado is T valor
            ? valor
            : throw new InvalidOperationException($"Respuesta inesperada de: {sql}");
    }

    /// <summary>Como EscalarAsync, pero devuelve null si el valor es NULL o no hay filas.</summary>
    public static async Task<T?> EscalarOpcionalAsync<T>(this NpgsqlDataSource db, string sql, params object?[] args)
        where T : struct
    {
        await using var cmd = Crear(db, sql, args);
        var resultado = await cmd.ExecuteScalarAsync();
        return resultado is T valor ? valor : null;
    }

    public static async Task<List<T>> ListarAsync<T>(
        this NpgsqlDataSource db, string sql, Func<NpgsqlDataReader, T> leer, params object?[] args)
    {
        await using var cmd = Crear(db, sql, args);
        await using var reader = await cmd.ExecuteReaderAsync();

        var items = new List<T>();
        while (await reader.ReadAsync())
            items.Add(leer(reader));
        return items;
    }

    /// <summary>Primera fila, o null si no hay ninguna.</summary>
    public static async Task<T?> PrimeroOpcionalAsync<T>(
        this NpgsqlDataSource db, string sql, Func<NpgsqlDataReader, T> leer, params object?[] args)
        where T : class
    {
        await using var cmd = Crear(db, sql, args);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? leer(reader) : null;
    }

    /// <summary>Primera fila; lanza si no hay ninguna (para funciones que siempre devuelven una).</summary>
    public static async Task<T> PrimeroAsync<T>(
        this NpgsqlDataSource db, string sql, Func<NpgsqlDataReader, T> leer, params object?[] args)
    {
        await using var cmd = Crear(db, sql, args);
        await using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? leer(reader)
            : throw new InvalidOperationException($"Respuesta vacía de: {sql}");
    }
}
