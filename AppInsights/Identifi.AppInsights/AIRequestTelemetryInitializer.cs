using System;
using System.Security.Claims;
using Identifi.Essentials.Extensions;
using Identifi.Infrastructure.Logging;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;

namespace Identifi.AppInsights
{
    public class AIRequestTelemetryInitializer: ITelemetryInitializer
    {
        public void Initialize(ITelemetry telemetry)
        {
            //Set sessionId/UserId and ServiceRequestId for each telemetry passed.
            var sessionId  = ClaimsPrincipal.Current.GetSessionId();
            var userId = ((ClaimsIdentity)ClaimsPrincipal.Current.Identity).GetStaffKey().ToString();
            telemetry.Context.User.Id = userId;
            telemetry.Context.Session.Id = !string.IsNullOrWhiteSpace(sessionId) ? sessionId : string.Empty;
            telemetry.Context.Properties["SessionId"] =!string.IsNullOrWhiteSpace(sessionId) ? sessionId : string.Empty;
            telemetry.Context.Properties["ServiceRequestId"] = IdentifiLogContext.CurrentServiceRequestId;
        }
    }
}
