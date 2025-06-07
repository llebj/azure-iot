using Messaging;
using Microsoft.Extensions.DependencyInjection;
using System.Threading.Channels;

namespace TelemetryUnit.Extensions;

public static class IServiceCollectionExtensions
{
    public static IServiceCollection AddChannel(this IServiceCollection services)
    {
        var channel = Channel.CreateBounded<Measurement>(
            new BoundedChannelOptions(1_000)
            {
                SingleWriter = true,
                SingleReader = true,
                FullMode = BoundedChannelFullMode.DropWrite
            });
        services.AddSingleton(channel.Writer);
        services.AddSingleton(channel.Reader);
        return services;
    }
}