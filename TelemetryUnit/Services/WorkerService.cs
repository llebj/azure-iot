using Messaging;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Threading.Channels;
using TelemetryUnit.Options;

namespace TelemetryUnit.Services;

public class WorkerService : BackgroundService
{
    private readonly ILogger<WorkerService> _logger;
    private readonly WorkerOptions _options;
    private readonly TimeProvider _timeProvider;
    private readonly ChannelWriter<Measurement> _writer;

    public WorkerService(
        ILogger<WorkerService> logger,
        IOptions<WorkerOptions> options,
        TimeProvider timeProvider,
        ChannelWriter<Measurement> writer)
    {
        _logger = logger;
        _options = options.Value;
        _timeProvider = timeProvider;
        _writer = writer;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_options.Period), _timeProvider);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken)) 
            {
                var timeStamp = _timeProvider.GetUtcNow();
                _logger.LogDebug("Created message {TimeStamp}.", timeStamp.Ticks);

                var result = _writer.TryWrite(new(timeStamp, timeStamp.Ticks.ToString()));
                if (!result)
                {
                    _logger.LogInformation("Failed to write to channel");
                }
            }
        }
        catch (OperationCanceledException) { };

        _writer.Complete();
    }
}