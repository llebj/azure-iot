namespace Messaging;

public readonly record struct IotMessage(
    string? CorrelationId,
    Measurement Measurement
);