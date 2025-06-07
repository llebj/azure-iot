
using FromBodyAttribute = Microsoft.Azure.Functions.Worker.Http.FromBodyAttribute;
using Messaging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

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
        public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest req,
            [FromBody] Measurement measurement)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");
            _logger.LogDebug("Received: {Measurement}", measurement);
            return new OkObjectResult(measurement);
        }
    }
}
