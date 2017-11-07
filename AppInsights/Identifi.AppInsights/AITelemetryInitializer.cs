using System;
using System.Security.Claims;
using Identifi.Essentials.Extensions;
using Identifi.Infrastructure.Logging;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.Extensibility;

namespace Identifi.AppInsights
{
    public class AITelemetryInitializer: ITelemetryInitializer
    {
        public void Initialize(ITelemetry telemetry)
        {
            var sessionId  = ClaimsPrincipal.Current.GetSessionId();
            telemetry.Context.User.Id = ((ClaimsIdentity)ClaimsPrincipal.Current.Identity).GetStaffKey().ToString();
            telemetry.Context.Session.Id = !string.IsNullOrWhiteSpace(sessionId) ? sessionId : string.Empty;
            telemetry.Context.Properties["ServiceRequestId"] = IdentifiLogContext.CurrentServiceRequestId;
        }
    }
}
