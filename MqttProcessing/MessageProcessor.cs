
using FromBodyAttribute = Microsoft.Azure.Functions.Worker.Http.FromBodyAttribute;
using Messaging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Azure.Data.Tables;

namespace MqttProcessing
{
    public class MessageProcessor
    {
        private readonly ILogger<MessageProcessor> _logger;

        public MessageProcessor(ILogger<MessageProcessor> logger)
        {
            _logger = logger;
        }

        [Function("MessageProcessor")]
        public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest req,
            [FromBody] Measurement measurement)
        {
            _logger.LogInformation("Received: {Measurement}", measurement);

            var uri = Environment.GetEnvironmentVariable("Storage_Uri");
            var tableName = Environment.GetEnvironmentVariable("Storage_TableName");
            var accountName = Environment.GetEnvironmentVariable("Storage_AccountName");
            var accountKey = Environment.GetEnvironmentVariable("Storage_AccountKey");

            var tableClient = new TableClient(
                new Uri(uri!),
                tableName,
                new TableSharedKeyCredential(accountName, accountKey)
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
            return new OkObjectResult(measurement);
        }
    }
}
