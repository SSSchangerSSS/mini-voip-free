using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Smi.Control.Push;
using Smi.Control.Database;
using Smi.Control.Calls;
using Xunit;

namespace Smi.Control.Tests;
public class FcmSenderTests
{
    sealed class Handler(RSA publicKey):HttpMessageHandler {
        public int Sent;
        public Exception? Failure;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage r,CancellationToken ct) {
            try{return await SendCore(r,ct);}catch(Exception ex){Failure=ex;throw;}
        }
        async Task<HttpResponseMessage> SendCore(HttpRequestMessage r,CancellationToken ct) {
            if(r.RequestUri!.Host=="oauth2.googleapis.com") {
                var form=await r.Content!.ReadAsStringAsync(ct);
                var jwt=Uri.UnescapeDataString(form.Split('&').Single(p=>p.StartsWith("assertion=")).Split('=',2)[1]);
                var parts=jwt.Split('.');byte[] Decode(string s)=>Convert.FromBase64String(s.Replace('-','+').Replace('_','/').PadRight((s.Length+3)/4*4,'='));
                Assert.Equal("RS256",JsonDocument.Parse(Decode(parts[0])).RootElement.GetProperty("alg").GetString());
                Assert.True(publicKey.VerifyData(Encoding.ASCII.GetBytes(parts[0]+"."+parts[1]),Decode(parts[2]),HashAlgorithmName.SHA256,RSASignaturePadding.Pkcs1));
                return new(HttpStatusCode.OK){Content=new StringContent("{\"access_token\":\"fixture-oauth-token\"}")};
            }
            Sent++;Assert.Equal("Bearer",r.Headers.Authorization!.Scheme);
            var j=JsonDocument.Parse(await r.Content!.ReadAsStringAsync(ct)).RootElement.GetProperty("message");
            Assert.Equal("fixture-device-token",j.GetProperty("token").GetString());
            var android=j.GetProperty("android");Assert.Equal("HIGH",android.GetProperty("priority").GetString());Assert.InRange(int.Parse(android.GetProperty("ttl").GetString()!.TrimEnd('s')),1,40);
            foreach(var p in android.GetProperty("data").EnumerateObject())Assert.Equal(JsonValueKind.String,p.Value.ValueKind);
            Assert.Equal("1",android.GetProperty("data").GetProperty("schemaVersion").GetString());
            Assert.Equal("نام آزمایشی",android.GetProperty("data").GetProperty("callerName").GetString());
            return new(HttpStatusCode.OK){Content=new StringContent("{}")};
        }
    }
    [Theory]
    [InlineData("2026-10-31T06:00:00.0000000Z")]
    [InlineData("2026-10-31T09:30:00.0000000+03:30")]
    public void DatabaseTimesRemainUtcRegardlessOfHostTimezone(string input) {
        var value=UtcTime.Parse(input);Assert.Equal(DateTimeKind.Utc,value.Kind);
        Assert.Equal(new DateTime(2026,10,31,6,0,0,DateTimeKind.Utc),value);
    }
    [Fact] public async Task RsaServiceAccountAndAllStringFcmDataAreUsed() {
        using var key=RSA.Create(2048);var path=Path.GetTempFileName();
        try {
            File.WriteAllText(path,JsonSerializer.Serialize(new{client_email="fixture@example.invalid",private_key=key.ExportPkcs8PrivateKeyPem()}));
            var handler=new Handler(key);var cfg=new SmiConfig{FcmServiceAccountPath=path,FcmProjectId="fixture-project"};
            var sender=new FcmSender(cfg,NullLogger<FcmSender>.Instance,new HttpClient(handler));
            var p=new PushPayload(1,"incoming_call",Guid.NewGuid().ToString(),"104","105",1,DateTime.UtcNow.AddSeconds(30),"نام آزمایشی");
            Assert.True((await sender.SendToDeviceAsync("fixture-device-token",p,30)).Accepted);Assert.Equal(1,handler.Sent);
        } finally{File.Delete(path);}
    }
    [Fact] public async Task DispatchUsesOnlyCurrentCalleeBinding_AndRejectsStaleGeneration() {
        using var key=RSA.Create(2048);var dir=Path.Combine(Path.GetTempPath(),"smi-push-"+Guid.NewGuid());Directory.CreateDirectory(dir);
        try {
            var path=Path.Combine(dir,"service.json");File.WriteAllText(path,JsonSerializer.Serialize(new{client_email="fixture@example.invalid",private_key=key.ExportPkcs8PrivateKeyPem()}));
            var cfg=new SmiConfig{DbPath=Path.Combine(dir,"db.sqlite"),FcmServiceAccountPath=path,FcmProjectId="fixture-project",SetupTimeoutSeconds=30};
            var db=new Db(cfg);db.Migrate();using(var c=db.Open()) {
                foreach(var ext in new[]{"104","105"})Db.Exec(c,"INSERT INTO Extensions(Extension,DisplayName,Enabled,PasswordHash,PasswordSalt,Pbkdf2Iterations,SipSecret,CreatedAtUtc,UpdatedAtUtc) VALUES(@e,@n,1,'fixture','fixture',1,'fixture',@t,@t)",("@e",ext),("@n",ext=="104"?"نام آزمایشی":"Receiver"),("@t",DateTime.UtcNow.ToString("o")));
                Db.Exec(c,"INSERT INTO Devices(InstallationId,Extension,Platform,DeviceGeneration,Active,PushProvider,PushToken) VALUES(@i,'105','android',2,1,'fcm','fixture-device-token')",("@i",Guid.NewGuid().ToString()));
            }
            var store=new CallStore(db,cfg);var admitted=store.Admit("104","105",Guid.NewGuid().ToString(),"fixture","fixture-pbx","fixture-channel",DateTime.UtcNow);
            Assert.Equal(AdmissionResult.Created,admitted.Result);
            var handler=new Handler(key);var dispatcher=new PushDispatch(cfg,db,NullLogger<PushDispatch>.Instance,NullLogger<ApnsSender>.Instance,NullLogger<FcmSender>.Instance,new HttpClient(handler));
            var dispatched=await dispatcher.SendIncomingCallAsync(admitted.Call!);Assert.True(dispatched,handler.Failure?.ToString() ?? $"dispatch failed, sent={handler.Sent}, generation={admitted.Call!.CalleeDeviceGeneration}");Assert.Equal(1,handler.Sent);
            using(var c=db.Open())Db.Exec(c,"UPDATE Devices SET DeviceGeneration=3 WHERE Extension='105'");
            Assert.False(await dispatcher.SendIncomingCallAsync(admitted.Call!));Assert.Equal(1,handler.Sent);
        }finally{Directory.Delete(dir,true);}
    }

}
