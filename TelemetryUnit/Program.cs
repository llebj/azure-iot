using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using TelemetryUnit.Extensions;
using TelemetryUnit.Options;
using TelemetryUnit.Services;

using var host = Host.CreateDefaultBuilder(args)
    .ConfigureServices((hostBuilder, services) => {
        services.Configure<WorkerOptions>(hostBuilder.Configuration.GetRequiredSection(WorkerOptions.Key));
        services.Configure<MqttOptions>(hostBuilder.Configuration.GetRequiredSection(MqttOptions.Key));

        services.AddSingleton(TimeProvider.System);
        services.AddChannel();

        services.AddHostedService<WorkerService>();
        services.AddHostedService<MqttClientService>();
    })
    .UseConsoleLifetime()
    .Build();

await host.RunAsync();
