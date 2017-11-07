using System;
using Microsoft.ApplicationInsights;

namespace Identifi.AppInsights
{
    public static class AIDependency
    {
        public static void TrackDependency(Action dependencyCall, string requestId, string dependency, string target)
        {
            var startTime = DateTime.UtcNow;
            var timer = System.Diagnostics.Stopwatch.StartNew();
            var telemetryClient = new TelemetryClient();
            var success = true;
            try
            {
                dependencyCall();
            }
            catch (Exception ex)
            {
                telemetryClient.TrackException(ex);
                success = false;
            }
            finally
            {
                timer.Stop();
                telemetryClient.TrackDependency(dependency,target, startTime, timer.Elapsed, success);
            }
        }

        public static void TrackDependency<T>(Func<T> dependencyCall, string requestId, string dependency, string target)
        {
            var startTime = DateTime.UtcNow;
            var timer = System.Diagnostics.Stopwatch.StartNew();
            var telemetryClient = new TelemetryClient();
            bool success = true;
            try
            {
                dependencyCall.Invoke();
            }
            catch (Exception ex)
            {
                telemetryClient.TrackException(ex);
                success = false;
            }
            finally
            {
                timer.Stop();
                telemetryClient.TrackDependency(dependency, target, startTime, timer.Elapsed, success);
            }
        }
    }
}
