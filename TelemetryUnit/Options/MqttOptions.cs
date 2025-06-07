namespace TelemetryUnit.Options;

public class MqttOptions
{
    public const string Key = "MQTT";

    public string Broker { get; set; } = string.Empty;

    public string ClientId { get; set; } = string.Empty;

    public string ClientCertificate { get; set; } = string.Empty;

    public string ClientCertificatePassword { get; set; } = string.Empty;

    public bool IgnoreCertificateRevocationErrors { get; set; }

    public int Port { get; set; } = 1883;
}