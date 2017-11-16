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
        private const string DisableTelemetryConfigKey = "DisableTelemetry";
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
            var telemetryClient = new TelemetryClient();

            //Update UserId, session Id, and Service request Id for each telemetry
            TelemetryConfiguration.Active.TelemetryInitializers.Add(new AIRequestTelemetryInitializer());

            //Send request body for POST data.
            var requestBody = context.Request.GetRequestBody();
            if (!LogActivityMethods.Contains(context.Request.Method) 
                || ResourceEndpointToIgnore.Any(res => context.Request.Uri.PathAndQuery.Contains(res)))
            {
                requestBody = string.Empty;
            }
            if (!string.IsNullOrEmpty(requestBody))
            {
                telemetryClient.TrackTrace(requestBody, SeverityLevel.Information, new Dictionary<string, string> { { "ServiceRequestId", IdentifiLogContext.CurrentServiceRequestId } });
            }

            await Next.Invoke(context);

        }
    }
}
