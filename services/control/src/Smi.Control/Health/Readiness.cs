namespace Smi.Control.Health;

/// <summary>
/// Readiness distinguishes live vs ready (spec 14.2): ready requires a migrated DB,
/// a connected AMI and completed reconciliation. Public /health/ready exposes only a summary.
/// </summary>
public sealed class Readiness
{
    public volatile bool MigrationsApplied;
    public volatile bool AmiReconciled;
    public volatile bool AmiConnected;

    public (bool Ready, object Summary) Evaluate()
    {
        var summary = new
        {
            db = MigrationsApplied ? "ok" : "pending",
            ami = AmiConnected ? (AmiReconciled ? "ok" : "reconciling") : "disconnected",
        };
        var ready = MigrationsApplied && AmiConnected && AmiReconciled;
        return (ready, summary);
    }
}
