using System.Diagnostics;
using System.Text.Json;
using Azure.Data.Tables;
using Azure.Identity;
using Azure.Storage.Queues.Models;
using Messaging;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace BackEndProcessing;

public class BackEndProcessor
{
    private readonly ILogger<BackEndProcessor> _logger;

    public BackEndProcessor(ILogger<BackEndProcessor> logger)
    {
        _logger = logger;
    }

    [Function(nameof(BackEndProcessor))]
    public async Task Run([QueueTrigger("readings", Connection = "AzureWebJobsStorage")] QueueMessage queueMessage)
    {
        IotMessage message = JsonSerializer.Deserialize<IotMessage>(queueMessage.Body);

        // If we have received a correlation id then we set up an activity with the same correlation id.
        // There is a limitation in using this approach: only operations that occur within the scope of
        // this activity will be correlated with the wider operation. One significant outcome of this is
        // that unhandled exceptions are corrolated using the `CorrelationId` (they are caught and handled
        // by the process outside of the context of the `Run` function). However, they can be associated
        // by using the `customDimensions.InvocationId` property of the trace log that appears in AI.
        using Activity? activity = !string.IsNullOrEmpty(message.CorrelationId) ?
            new Activity(nameof(BackEndProcessor)) :
            null;
        if (activity is not null)
        {
            activity.SetParentId(message.CorrelationId!);
            activity.Start();
        }

        Measurement measurement = message.Measurement;
        _logger.LogInformation("Processing IoT message: {IotMessage}", message);
        _logger.LogInformation("Received: {Measurement}", measurement);

        var uri = Environment.GetEnvironmentVariable("Storage_Uri");
        var tableName = Environment.GetEnvironmentVariable("Storage_TableName");
        var tableClient = new TableClient(
            new Uri(uri!),
            tableName,
            new DefaultAzureCredential()
        );
        var entity = new TableEntity("demo", Guid.NewGuid().ToString())
        {
            { "Timestamp", measurement.TimeStamp },
            { "Message", measurement.Message }
        };

        try
        {
            await tableClient.AddEntityAsync(entity);
        }
        catch (Exception e)
        {
            _logger.LogError(e, e.Message);
            throw;
        }

        _logger.LogInformation("Inserted {Measurement} into {TableName} table.", measurement, tableName);
    }
}