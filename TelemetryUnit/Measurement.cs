namespace TelemetryUnit;

public readonly record struct Measurement(
    DateTimeOffset TimeStamp,
    string Message
);