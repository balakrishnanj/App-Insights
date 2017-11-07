using System.Web.Http.ExceptionHandling;
using Microsoft.ApplicationInsights;

namespace Identifi.AppInsights
{
    public class AIException: ExceptionLogger
    {
        public override void Log(ExceptionLoggerContext context)
        {
            if (context?.Exception == null) return;

            var aiClient = new TelemetryClient();
            aiClient.TrackException(context.Exception);
        }

        
    }
}
