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
    public async Task Run([QueueTrigger("readings", Connection = "AzureWebJobsStorage")] QueueMessage message)
    {
        _logger.LogInformation("Processing queue message: {QueueMessage}", message);
        var measurement = JsonSerializer.Deserialize<Measurement>(message.Body);
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