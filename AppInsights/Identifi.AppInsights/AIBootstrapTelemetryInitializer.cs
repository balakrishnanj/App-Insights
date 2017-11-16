using System;
using System.Linq;
using Identifi.Infrastructure;
using Microsoft.ApplicationInsights.Channel;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using System.Net;
using System.Web.Configuration;

namespace Identifi.AppInsights
{
    public class AIBootstrapTelemetryInitializer: ITelemetryInitializer
    {
        private readonly HttpStatusCode[] _detailMessageErrorCodes = { HttpStatusCode.Unauthorized, HttpStatusCode.PreconditionFailed, HttpStatusCode.Forbidden };

        public void Initialize(ITelemetry telemetry)
        {
            //Disable Telemetry if the config value is set to true
            bool disableTelemetry;
            var configReader = ServiceLocator.Current.GetInstance<IConfigReader>();
            if (configReader == null)
            {
                bool.TryParse(WebConfigurationManager.AppSettings["DisableTelemetry"], out disableTelemetry);
            }
            else
            {
                disableTelemetry = configReader.Get("DisableTelemetry", false);
            }
            if (disableTelemetry)
                TelemetryConfiguration.Active.DisableTelemetry = true;

            //Treat 403/412/401 as success instead of error
            var requestTelemetry = telemetry as RequestTelemetry;
            // Is this a TrackRequest() ?
            if (requestTelemetry == null) return;
            int code;
            bool parsed = Int32.TryParse(requestTelemetry.ResponseCode, out code);
            if (!parsed) return;

            if (_detailMessageErrorCodes.Contains((HttpStatusCode)code))
            {
                // If we set the Success property, the SDK won't change it:
                requestTelemetry.Success = true;
                // Allow us to filter these requests in the portal:
                requestTelemetry.Context.Properties["Overridden400s"] = "true";
            }
        }
    }
}
