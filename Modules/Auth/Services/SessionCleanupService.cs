using iet_bi_portal_backend.Modules.Auth.Data;

namespace iet_bi_portal_backend.Modules.Auth.Services;

/// <summary>Ejecuta auth.sp_purgar_sesiones_expiradas() una vez al día, en segundo plano.</summary>
public class SessionCleanupService(IServiceScopeFactory scopeFactory, ILogger<SessionCleanupService> logger)
    : BackgroundService
{
    private static readonly TimeSpan Intervalo = TimeSpan.FromHours(24);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var repo = scope.ServiceProvider.GetRequiredService<AuthRepository>();
                await repo.PurgarSesionesExpiradasAsync();
                logger.LogInformation("Sesiones expiradas purgadas correctamente.");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error al purgar sesiones expiradas.");
            }

            try { await Task.Delay(Intervalo, stoppingToken); }
            catch (TaskCanceledException) { /* apagado normal */ }
        }
    }
}
