using iet_bi_portal_backend.Modules.Auth.Data;

namespace iet_bi_portal_backend.Modules.Auth.Services;

/// <summary>Corre auth.sp_purgar_sesiones_expiradas() una vez al día, en segundo plano.</summary>
public class SessionCleanupService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(24);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SessionCleanupService> _logger;

    /// <summary> Crea un servicio de limpieza de sesiones expiradas. </summary>
    public SessionCleanupService(IServiceScopeFactory scopeFactory, ILogger<SessionCleanupService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary> Ejecuta el servicio en segundo plano, purgando sesiones expiradas cada 24 horas. </summary>
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var repo = scope.ServiceProvider.GetRequiredService<AuthRepository>();
                await repo.PurgeExpiredSessionsAsync();
                _logger.LogInformation("Sesiones expiradas purgadas correctamente.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al purgar sesiones expiradas.");
            }

            try { await Task.Delay(Interval, stoppingToken); }
            catch (TaskCanceledException) { /* apagado normal */ }
        }
    }
}