using System.Diagnostics;
using System.Text.Json;
using Azure.Identity;
using Azure.Storage.Queues;
using Messaging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FrontEndProcessing;

public class FrontEndProcessor
{
    private readonly ILogger<FrontEndProcessor> _logger;

    public FrontEndProcessor(ILogger<FrontEndProcessor> logger)
    {
        _logger = logger;
    }

    [Function(nameof(FrontEndProcessor))]
    public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest req)
    {
        using Activity activity = new(nameof(FrontEndProcessor));
        activity.Start();

        using StreamReader reader = new(req.Body);
        var requestBody = await reader.ReadToEndAsync();
        _logger.LogInformation("Request body: {RequestBody}", requestBody);
        var measurement = JsonSerializer.Deserialize<Measurement>(requestBody);
        _logger.LogInformation("Received: {Measurement}", measurement);

        // Attach the activity id to the IotMessage so that activities can be correlated with downstream operations.
        IotMessage message = new(activity?.Id, measurement);

        var uri = Environment.GetEnvironmentVariable("Storage_Uri");
        var queueClient = new QueueClient(
            new Uri(uri!),
            new DefaultAzureCredential(),
            new QueueClientOptions
            {
                MessageEncoding = QueueMessageEncoding.Base64
            }
        );

        try
        {
            await queueClient.SendMessageAsync(JsonSerializer.Serialize(message));
        }
        catch (Exception e)
        {
            _logger.LogError(e, e.Message);
            throw;
        }

        _logger.LogInformation("Sent {Measurement} to queue.", measurement);
        return new OkObjectResult(measurement);
    }
}