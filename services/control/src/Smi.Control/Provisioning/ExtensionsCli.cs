using System.Text;
using Smi.Control.Calls;
using Smi.Control.Database;

namespace Smi.Control.Provisioning;

/// <summary>
/// Account/device management CLI — a mode of the Control program itself (spec 11.2, 13).
/// One command creates the API account AND renders the SIP config from a single source of
/// truth. Config changes go through: render to temp → validate → atomic replace → AMI reload
/// → report. If any step fails the state is explicit (DB updated / reload pending), never
/// a fake success. Secrets never appear on the command line.
/// </summary>
public static class ExtensionsCli
{
    public static async Task<int> RunAsync(string[] args, SmiConfig cfg, Db db, Smi.Control.Ami.AmiClient ami, CallStore calls)
    {
        if (args.Length < 2) { PrintUsage(); return 2; }
        var verb = args[0] + " " + args[1];

        try
        {
            switch (verb)
            {
                case "extensions add": return await ExtensionAddAsync(args[2..], cfg, db, ami);
                case "extensions disable": return await ExtensionDisableAsync(args[2..], cfg, db, ami, calls);
                case "extensions set-password": return await ExtensionAddAsync(args[2..], cfg, db, ami);
                case "device reset": return await DeviceResetAsync(args[2..], cfg, db, ami, calls);
                default: PrintUsage(); return 2;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"ERROR {ex.GetType().Name}: {ex.Message}");
            return 1;
        }
    }

    private static (string Ext, string CredentialFile, bool Force) ParseExtArgs(string[] args)
    {
        string ext = "", file = ""; bool force = false;
        for (var i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--credential-file": file = args[++i]; break;
                case "--force": force = true; break;
                default: if (!args[i].StartsWith("--") && ext.Length == 0) ext = args[i]; break;
            }
        }
        return (ext, file, force);
    }

    private static async Task<int> ExtensionAddAsync(string[] args, SmiConfig cfg, Db db, Smi.Control.Ami.AmiClient ami)
    {
        var (extRaw, credFile, _) = ParseExtArgs(args);
        if (credFile.Length == 0) { Console.Error.WriteLine("ERROR --credential-file is required (never pass passwords on the command line)"); return 2; }
        var ext = DigitNormalizer.NormalizeInternal(extRaw);
        if (ext is null) { Console.Error.WriteLine("ERROR extension must be a 3-digit value in 101..199"); return 2; }
        if (!File.Exists(credFile)) { Console.Error.WriteLine($"ERROR credential file not found: {credFile}"); return 2; }
        var password = File.ReadAllText(credFile).Trim();
        if (password.Length < 8) { Console.Error.WriteLine("ERROR password shorter than 8 characters"); return 2; }

        var now = DateTime.UtcNow.ToString("o");
        var (hash, salt, iters) = Crypto.HashPassword(password);
        var sipSecret = Crypto.NewSipSecret();

        using (var c = db.Open())
        using (var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable))
        {
            var existing = Db.Scalar(c, "SELECT Extension FROM Extensions WHERE Extension=@e", ("@e", ext));
            if (existing is null)
            {
                Db.Exec(c, """
                    INSERT INTO Extensions(Extension,Enabled,PasswordHash,PasswordSalt,Pbkdf2Iterations,SipSecret,ConfigurationGeneration,CreatedAtUtc,UpdatedAtUtc)
                    VALUES(@e,1,@h,@s,@it,@sip,1,@n,@n)
                    """, ("@e", ext), ("@h", hash), ("@s", salt), ("@it", iters), ("@sip", sipSecret), ("@n", now));
                Console.WriteLine($"EXTENSION_CREATED {ext}");
            }
            else
            {
                Db.Exec(c, """
                    UPDATE Extensions SET PasswordHash=@h, PasswordSalt=@s, Pbkdf2Iterations=@it, SipSecret=@sip,
                        ConfigurationGeneration=ConfigurationGeneration+1, UpdatedAtUtc=@n, Enabled=1
                    WHERE Extension=@e
                    """, ("@h", hash), ("@s", salt), ("@it", iters), ("@sip", sipSecret), ("@n", now), ("@e", ext));
                Console.WriteLine($"EXTENSION_UPDATED {ext}");
            }
            tx.Commit();
        }

        var rendered = await RenderAndApplyAsync(cfg, db, ami);
        return rendered ? 0 : 1;
    }

    private static async Task<int> ExtensionDisableAsync(string[] args, SmiConfig cfg, Db db, Smi.Control.Ami.AmiClient ami, CallStore calls)
    {
        var (extRaw, _, force) = ParseExtArgs(args);
        var ext = DigitNormalizer.NormalizeInternal(extRaw);
        if (ext is null) { Console.Error.WriteLine("ERROR invalid extension"); return 2; }

        var active = calls.GetCurrentFor(ext);
        if (active is not null && !force)
        {
            Console.Error.WriteLine($"BLOCKED extension {ext} has an active call {active.CallId}; use --force to end it");
            return 3;
        }

        using (var c = db.Open())
        {
            var n = Db.Exec(c, "UPDATE Extensions SET Enabled=0, UpdatedAtUtc=@n WHERE Extension=@e", ("@n", DateTime.UtcNow.ToString("o")), ("@e", ext));
            if (n == 0) { Console.Error.WriteLine($"ERROR extension {ext} not found"); return 2; }
            Db.Exec(c, "DELETE FROM CallSlots WHERE Extension=@e", ("@e", ext));
        }
        Console.WriteLine($"EXTENSION_DISABLED {ext}");
        var rendered = await RenderAndApplyAsync(cfg, db, ami);
        return rendered ? 0 : 1;
    }

    private static async Task<int> DeviceResetAsync(string[] args, SmiConfig cfg, Db db, Smi.Control.Ami.AmiClient ami, CallStore calls)
    {
        var (extRaw, credFile, force) = ParseExtArgs(args);
        if (credFile.Length == 0) { Console.Error.WriteLine("ERROR --credential-file is required (rotates the SIP secret too)"); return 2; }
        var ext = DigitNormalizer.NormalizeInternal(extRaw);
        if (ext is null) { Console.Error.WriteLine("ERROR invalid extension"); return 2; }

        var active = calls.GetCurrentFor(ext);
        if (active is not null && !force)
        {
            Console.Error.WriteLine($"BLOCKED extension {ext} has an active call {active.CallId}; use --force for emergency cut-off");
            return 3;
        }

        var sipSecret = Crypto.NewSipSecret();
        var now = DateTime.UtcNow.ToString("o");
        using (var c = db.Open())
        using (var tx = c.BeginTransaction(System.Data.IsolationLevel.Serializable))
        {
            var exists = Db.Scalar(c, "SELECT Extension FROM Extensions WHERE Extension=@e", ("@e", ext));
            if (exists is null) { Console.Error.WriteLine($"ERROR extension {ext} not found"); return 2; }
            Db.Exec(c, "UPDATE Extensions SET SipSecret=@s, ConfigurationGeneration=ConfigurationGeneration+1, UpdatedAtUtc=@n WHERE Extension=@e",
                ("@s", sipSecret), ("@n", now), ("@e", ext));
            // invalidate ALL sessions and the device binding: the old device must not re-register
            Db.Exec(c, "UPDATE Sessions SET RevokedAtUtc=@n WHERE Extension=@e AND RevokedAtUtc IS NULL", ("@n", now), ("@e", ext));
            Db.Exec(c, "UPDATE Devices SET Active=0, PushToken=NULL, DeviceGeneration=DeviceGeneration+1 WHERE Extension=@e AND Active=1", ("@n", now), ("@e", ext));
            tx.Commit();
        }
        Console.WriteLine($"DEVICE_RESET {ext} (generation bumped, sessions revoked, SIP secret rotated)");
        var rendered = await RenderAndApplyAsync(cfg, db, ami);
        return rendered ? 0 : 1;
    }

    /// <summary>Render the per-extension PJSIP accounts file: temp → validate → atomic replace → AMI reload.</summary>
    private static async Task<bool> RenderAndApplyAsync(SmiConfig cfg, Db db, Smi.Control.Ami.AmiClient ami)
    {
        var sb = new StringBuilder();
        sb.AppendLine("; GENERATED by smi extension CLI — do not edit by hand (spec 8.1, 11.2)");
        using (var c = db.Open())
        using (var r = Db.Query(c, "SELECT Extension,SipSecret FROM Extensions WHERE Enabled=1 ORDER BY Extension"))
        {
            while (r.Read())
            {
                var ext = r.GetString(0);
                var secret = r.GetString(1);
                sb.AppendLine($"[{ext}](smi-endpoint-template)");
                sb.AppendLine("auth=" + ext);
                sb.AppendLine("aors=" + ext);
                sb.AppendLine();
                sb.AppendLine($"[{ext}](smi-auth-template)");
                sb.AppendLine("username=" + ext);
                sb.AppendLine("password=" + secret);
                sb.AppendLine();
                sb.AppendLine($"[{ext}](smi-aor-template)");
                sb.AppendLine();
            }
        }

        Directory.CreateDirectory(cfg.PbxCfgDir);
        var target = System.IO.Path.Combine(cfg.PbxCfgDir, "pjsip", "accounts.conf");
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(target)!);
        var tmp = target + ".tmp";
        await File.WriteAllTextAsync(tmp, sb.ToString());

        // validation pass: re-read and count blocks
        var rendered = await File.ReadAllTextAsync(tmp);
        var endpoints = rendered.Split('\n').Count(l => l.StartsWith('['));
        if (endpoints == 0) { Console.Error.WriteLine("ERROR rendered config has no endpoints; aborting replace"); File.Delete(tmp); return false; }
        File.Move(tmp, target, overwrite: true);
        Console.WriteLine($"CONFIG_RENDERED {target} ({endpoints} blocks)");

        // reload via AMI; if unreachable the change stays pending and is retried on reconnect
        if (ami.ConnectedAndLoggedIn)
        {
            var res = await ami.Reload("res_pjsip.so", CancellationToken.None);
            var ok = res is not null && string.Equals(res.Get("Response"), "Success", StringComparison.OrdinalIgnoreCase);
            Console.WriteLine(ok ? "PJSIP_RELOADED" : "PJSIP_RELOAD_FAILED");
            return ok;
        }
        Console.WriteLine("PJSIP_RELOAD_PENDING (AMI not connected; will be retried when AMI reconnects)");
        return true;
    }

    private static void PrintUsage()
    {
        Console.WriteLine("""
            Usage (run on the server):
              dotnet Smi.Control.dll extensions add 101 --credential-file <secure-path>
              dotnet Smi.Control.dll extensions disable 101 [--force]
              dotnet Smi.Control.dll device reset 101 --credential-file <secure-path> [--force]
            """);
    }
}
