namespace Messaging;

public readonly record struct Measurement(
    DateTimeOffset TimeStamp,
    string Message
);