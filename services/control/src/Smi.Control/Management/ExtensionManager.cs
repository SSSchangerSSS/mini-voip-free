using Smi.Control.Database;
using Smi.Control.Calls;
using Smi.Control.Ami;
using Smi.Control.Provisioning;

namespace Smi.Control.Management;

public sealed record DirectoryEntry(string Extension, string DisplayName);
public sealed record DirectorySnapshot(string Version, IReadOnlyList<DirectoryEntry> Entries);
public sealed record ManagedExtension(string Extension, string DisplayName, bool Enabled, bool DeviceBound);
public sealed class ExtensionManager(Db db, SmiConfig cfg, AmiClient ami)
{
    private TaskCompletionSource _changed = NewSignal();
    static TaskCompletionSource NewSignal() => new(TaskCreationOptions.RunContinuationsAsynchronously);
    public Task Changed => Volatile.Read(ref _changed).Task;
    private readonly object _snapshotLock = new();
    private DirectorySnapshot? _snapshot;
    private DateTime _snapshotUntil;
    public void NotifyChanged() {
        lock(_snapshotLock) _snapshot=null;
        var old=Interlocked.Exchange(ref _changed,NewSignal());old.TrySetResult();
    }
    public DirectorySnapshot Snapshot() {
        lock(_snapshotLock) {
            if(_snapshot is not null && DateTime.UtcNow<_snapshotUntil)return _snapshot;
            var entries=ReadDirectory();
            var version=Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Json.JsonSerializer.SerializeToUtf8Bytes(entries)));
            _snapshot=new(version,entries);_snapshotUntil=DateTime.UtcNow.AddSeconds(5);return _snapshot;
        }
    }
    public string Version()=>Snapshot().Version;
    public IReadOnlyList<DirectoryEntry> Directory()=>Snapshot().Entries;
    private readonly SemaphoreSlim _write = new(1, 1);
    private IReadOnlyList<DirectoryEntry> ReadDirectory()
    {
        using var c = db.Open(); using var r = Db.Query(c, "SELECT Extension,DisplayName FROM Extensions WHERE Enabled=1 AND Deleted=0 ORDER BY Extension");
        var rows = new List<DirectoryEntry>();
        while(r.Read()) rows.Add(new(r.GetString(0), r.GetString(1)));
        return rows;
    }
    public IReadOnlyList<ManagedExtension> List()
    {
        using var c = db.Open(); using var r = Db.Query(c, """
            SELECT e.Extension,e.DisplayName,e.Enabled,EXISTS(SELECT 1 FROM Devices d WHERE d.Extension=e.Extension AND d.Active=1)
            FROM Extensions e WHERE e.Deleted=0 ORDER BY e.Extension
            """);
        var rows = new List<ManagedExtension>();
        while(r.Read()) rows.Add(new(r.GetString(0),r.GetString(1),r.GetInt32(2)!=0,r.GetInt32(3)!=0));
        return rows;
    }
    public async Task<(string? Error, bool Applied)> Save(string ext, string name, string? password, bool? enabled, bool create)
    {
        if(DigitNormalizer.NormalizeInternal(ext)!=ext || (create && string.IsNullOrWhiteSpace(name)) || name.Length>80 || name.Any(char.IsControl) ||
            (password is not null && (password.Length<12 || password.Length>256)) || (create && password is null)) return ("INVALID_INPUT",false);
        await _write.WaitAsync();
        try {
            using(var c=db.Open()) using(var tx=Db.BeginImmediate(c)) {
                var exists=Db.Scalar(c,"SELECT Extension FROM Extensions WHERE Extension=@e",("@e",ext)) is not null;
                if(enabled==true && exists && Convert.ToInt64(Db.Scalar(c,"SELECT Enabled FROM Extensions WHERE Extension=@e",("@e",ext)))==0 &&
                    Convert.ToInt64(Db.Scalar(c,"SELECT COUNT(*) FROM Extensions WHERE Enabled=1"))>=30)return ("CAPACITY",false);
                var deleted=exists && Convert.ToInt64(Db.Scalar(c,"SELECT Deleted FROM Extensions WHERE Extension=@e",("@e",ext)))!=0;
                if(deleted && !create)return ("NOT_FOUND",false);
                if(deleted && create) {
                    if(Convert.ToInt64(Db.Scalar(c,"SELECT COUNT(*) FROM Extensions WHERE Enabled=1"))>=30)return ("CAPACITY",false);
                    Revoke(c,ext,DateTime.UtcNow.ToString("o"));
                    // Reuse the identifier without resurrecting credentials or bindings.
                    Db.Exec(c,"UPDATE Extensions SET Deleted=0 WHERE Extension=@e",("@e",ext));
                    create=false;enabled=true;
                }
                else if(exists && create)return ("ALREADY_EXISTS",false);
                if(!exists && !create)return ("NOT_FOUND",false);
                // Guard against admission races while changing credentials or disabling.
                if(exists && (password is not null || enabled==false) && Db.Scalar(c,"SELECT Extension FROM CallSlots WHERE Extension=@e",("@e",ext)) is not null) return ("ACTIVE_CALL",false);
                var now=DateTime.UtcNow.ToString("o");
                if(create) {
                    var count=(long)Db.Scalar(c,"SELECT COUNT(*) FROM Extensions WHERE Enabled=1")!;
                    if(count>=30)return ("CAPACITY",false);
                    var(h,s,i)=Crypto.HashPassword(password!);
                    Db.Exec(c,"""
                        INSERT INTO Extensions(Extension,DisplayName,Enabled,PasswordHash,PasswordSalt,Pbkdf2Iterations,SipSecret,ConfigurationGeneration,CreatedAtUtc,UpdatedAtUtc)
                        VALUES(@e,@n,1,@h,@s,@i,@sip,1,@t,@t)
                        """,("@e",ext),("@n",name.Trim()),("@h",h),("@s",s),("@i",i),("@sip",Crypto.NewSipSecret()),("@t",now));
                } else {
                    Db.Exec(c,"UPDATE Extensions SET DisplayName=@n,UpdatedAtUtc=@t WHERE Extension=@e",("@n",name.Trim()),("@t",now),("@e",ext));
                    if(enabled is not null) Db.Exec(c,"UPDATE Extensions SET Enabled=@b WHERE Extension=@e",("@b",enabled.Value?1:0),("@e",ext));
                    if(password is not null) {
                        var(h,s,i)=Crypto.HashPassword(password);
                        Db.Exec(c,"UPDATE Extensions SET PasswordHash=@h,PasswordSalt=@s,Pbkdf2Iterations=@i,SipSecret=@sip,ConfigurationGeneration=ConfigurationGeneration+1 WHERE Extension=@e",("@h",h),("@s",s),("@i",i),("@sip",Crypto.NewSipSecret()),("@e",ext));
                    }
                    if(password is not null || enabled==false) Revoke(c,ext,now);
                }
                tx.Commit();
                NotifyChanged();
            }
            return (null, !create && password is null && enabled is null ? true : await Apply());
        } finally { _write.Release(); }
    }
    public async Task<(string? Error,bool Applied)> Unbind(string ext)
    {
        await _write.WaitAsync();
        try {
            using(var c=db.Open()) using(var tx=Db.BeginImmediate(c)) {
                if(Db.Scalar(c,"SELECT Extension FROM Extensions WHERE Extension=@e AND Deleted=0",("@e",ext)) is null)return("NOT_FOUND",false);
                if(Db.Scalar(c,"SELECT Extension FROM CallSlots WHERE Extension=@e",("@e",ext)) is not null)return("ACTIVE_CALL",false);
                Revoke(c,ext,DateTime.UtcNow.ToString("o"));
                Db.Exec(c,"UPDATE Extensions SET SipSecret=@s,ConfigurationGeneration=ConfigurationGeneration+1 WHERE Extension=@e",("@s",Crypto.NewSipSecret()),("@e",ext));tx.Commit();NotifyChanged();
            }
            return(null,await Apply());
        } finally {_write.Release();}
    }
    public async Task<(string? Error,bool Applied)> Delete(string ext) {
        await _write.WaitAsync();
        try {
            using(var c=db.Open()) using(var tx=Db.BeginImmediate(c)) {
                if(Db.Scalar(c,"SELECT Extension FROM Extensions WHERE Extension=@e AND Deleted=0",("@e",ext)) is null)return("NOT_FOUND",false);
                if(Db.Scalar(c,"SELECT Extension FROM CallSlots WHERE Extension=@e",("@e",ext)) is not null)return("ACTIVE_CALL",false);
                Revoke(c,ext,DateTime.UtcNow.ToString("o"));
                var(h,s,i)=Crypto.HashPassword(Crypto.NewSipSecret());
                Db.Exec(c,"UPDATE Extensions SET Deleted=1,Enabled=0,PasswordHash=@h,PasswordSalt=@s,Pbkdf2Iterations=@i,SipSecret=@sip,ConfigurationGeneration=ConfigurationGeneration+1 WHERE Extension=@e",("@h",h),("@s",s),("@i",i),("@sip",Crypto.NewSipSecret()),("@e",ext));
                tx.Commit();NotifyChanged();
            }
            return(null,await Apply());
        } finally {_write.Release();}
    }
    private static void Revoke(Microsoft.Data.Sqlite.SqliteConnection c,string ext,string now) {
        Db.Exec(c,"UPDATE Sessions SET RevokedAtUtc=@t WHERE Extension=@e AND RevokedAtUtc IS NULL",("@t",now),("@e",ext));
        Db.Exec(c,"UPDATE Devices SET Active=0,PushToken=NULL,DeviceGeneration=DeviceGeneration+1 WHERE Extension=@e AND Active=1",("@e",ext));
    }
    private async Task<bool> Apply() {
        // Render always; a disconnected AMI is explicitly pending, not success.
        var rendered=await ExtensionsCli.RenderAndApplyAsync(cfg,db,ami);
        return rendered && ami.ConnectedAndLoggedIn;
    }
}
