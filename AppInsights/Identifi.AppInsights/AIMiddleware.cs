using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Identifi.Essentials.Extensions;
using Identifi.Infrastructure.Logging;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Owin;

namespace Identifi.AppInsights
{
    public class AIMiddleware: OwinMiddleware
    {
        private static readonly IEnumerable<string> LogActivityMethods = new List<string>
        {
            HttpMethod.Get.Method,
            HttpMethod.Post.Method,
            HttpMethod.Put.Method,
            HttpMethod.Delete.Method
        };

        private static readonly IEnumerable<string> ResourceEndpointToIgnore = new List<string>
        {
            "user/authenticate",
            "user/resetpassword",
            "user/securityquestion",
            "/token",
            "/UserManagementAuthorization"
        };

        public AIMiddleware(OwinMiddleware next) : base(next)
        {
        }

        public override async Task Invoke(IOwinContext context)
        {
           
            var requestBody = context.Request.GetRequestBody();

            if (!LogActivityMethods.Contains(context.Request.Method))
            {
                return;
            }

            if (ResourceEndpointToIgnore.Any(res => context.Request.Uri.PathAndQuery.Contains(res)))
            {
                requestBody = string.Empty;
            }

            var telemetryClient = new TelemetryClient();

            TelemetryConfiguration.Active.TelemetryInitializers.Add(new AITelemetryInitializer());

            telemetryClient.TrackTrace(requestBody);

            using (var operation = telemetryClient.StartOperation<RequestTelemetry>(IdentifiLogContext.CurrentServiceRequestId))
            {
                telemetryClient.TrackTrace("Invoking call...");

                await Next.Invoke(context);

                telemetryClient.StopOperation(operation);
            }

               
        }
    }
}
