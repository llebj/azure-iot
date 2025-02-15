namespace TelemetryUnit.Options;

public class MqttOptions
{
    public const string Key = "MQTT";

    public string Broker { get; set; } = string.Empty;

    public int Port { get; set; } = 1883;
}