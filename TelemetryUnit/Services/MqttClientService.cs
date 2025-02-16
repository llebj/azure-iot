using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using System.Threading.Channels;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MQTTnet;
using TelemetryUnit.Options;

namespace TelemetryUnit.Services;

public class MqttClientService : BackgroundService
{
    private readonly ILogger<MqttClientService> _logger;
    private readonly MqttOptions _options;
    private readonly ChannelReader<Measurement> _reader;

    public MqttClientService(
        ILogger<MqttClientService> logger,
        IOptions<MqttOptions> options,
        ChannelReader<Measurement> reader
    )
    {
        _logger = logger; 
        _options = options.Value;
        _reader = reader;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        MqttClientFactory mqttClientFactory = new();
        var mqttClientOptions = mqttClientFactory.CreateClientOptionsBuilder()
            .WithTcpServer(_options.Broker, _options.Port)
            .WithProtocolVersion(MQTTnet.Formatter.MqttProtocolVersion.V500)
            .WithTlsOptions(new MqttClientTlsOptionsBuilder()
                .UseTls()
                .WithIgnoreCertificateRevocationErrors(_options.IgnoreCertificateRevocationErrors)
                .WithCertificateValidationHandler((MqttClientCertificateValidationEventArgs e) => {
                    // This allows a useful place to use the debugger to inspect any TLS issues.
                    return e.SslPolicyErrors == System.Net.Security.SslPolicyErrors.None;
                })
                .WithSslProtocols(System.Security.Authentication.SslProtocols.Tls13)
                .WithClientCertificates(new[] { new X509Certificate2(_options.ClientCertificate, _options.ClientCertificatePassword) })
                .Build())
            .Build();
        var mqttClientDisconnectOptions = mqttClientFactory
            .CreateClientDisconnectOptionsBuilder()
            .WithReason(MqttClientDisconnectOptionsReason.NormalDisconnection)
            .Build();

        using var mqttClient = mqttClientFactory.CreateMqttClient();
        mqttClient.ConnectingAsync += OnMqttClientConnecting;
        mqttClient.ConnectedAsync += OnMqttClientConnected;
        mqttClient.DisconnectedAsync += OnMqttClientDisconnected;

        // TODO: Handle failed connection attempts.
        var response = await mqttClient.ConnectAsync(mqttClientOptions, stoppingToken);

        try
        {
            while (await _reader.WaitToReadAsync(stoppingToken))
            {
                _logger.LogDebug("Attempting to read measurement.");
                while (mqttClient.IsConnected && _reader.TryRead(out Measurement measurement))
                {
                    var messageBuilder = new MqttApplicationMessageBuilder();
                    var message = messageBuilder
                        .WithTopic("/measurements")
                        .WithPayload(JsonSerializer.Serialize(measurement))
                        .Build();
                    
                    _logger.LogDebug("Publishing message {Message}.", measurement.Message);
                    // TODO: Handle exception thrown when the client is not connected to the broker.
                    await mqttClient.PublishAsync(message, stoppingToken);
                }
            }
        } 
        catch (OperationCanceledException) { }
        
        await mqttClient.DisconnectAsync(mqttClientDisconnectOptions, stoppingToken);
        mqttClient.ConnectingAsync -= OnMqttClientConnecting;
        mqttClient.ConnectedAsync -= OnMqttClientConnected;
        mqttClient.DisconnectedAsync -= OnMqttClientDisconnected;
    }

    private Task OnMqttClientConnecting(MqttClientConnectingEventArgs eventArgs)
    {
        _logger.LogInformation("Connecting to broker as {ClientId}.", eventArgs.ClientOptions.ClientId);
        return Task.CompletedTask;
    }

    private Task OnMqttClientConnected(MqttClientConnectedEventArgs eventArgs)
    {
        _logger.LogInformation("Connected to broker.");
        return Task.CompletedTask;
    }

    private Task OnMqttClientDisconnected(MqttClientDisconnectedEventArgs eventArgs)
    {
        // TODO: Handle reconnects.
        _logger.LogInformation("Disconnected from broker. Reason: {DisconnectReason}", eventArgs.Reason);
        return Task.CompletedTask;
    }
}