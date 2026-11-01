using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Smi.Control.Database;
using Smi.Control.Management;
using Xunit;

namespace Smi.Control.Tests;
public class ManagementTests : IDisposable
{
    readonly string root=Path.Combine(Path.GetTempPath(),"smi-admin-"+Guid.NewGuid());
    readonly WebApplicationFactory<Program> factory;
    const string Password="fixture-admin-password-long";
    public ManagementTests() {
        Directory.CreateDirectory(root);
        factory=new WebApplicationFactory<Program>().WithWebHostBuilder(b=>b.ConfigureServices(s=>{
            s.RemoveAll<SmiConfig>();s.AddSingleton(new SmiConfig{DbPath=Path.Combine(root,"db.sqlite"),PbxCfgDir=Path.Combine(root,"pbx"),Domain="test.local",AdminPassword=Password});
        }));
    }
    HttpClient Client()=>factory.CreateClient(new WebApplicationFactoryClientOptions{BaseAddress=new Uri("https://localhost"),AllowAutoRedirect=false});
    async Task<string> Csrf(HttpClient c) {
        var s=await c.GetFromJsonAsync<JsonElement>("/admin/session");return s.GetProperty("csrfToken").GetString()!;
    }
    async Task Login(HttpClient c) {
        c.DefaultRequestHeaders.Remove("X-CSRF-TOKEN");c.DefaultRequestHeaders.Add("X-CSRF-TOKEN",await Csrf(c));
        Assert.Equal(HttpStatusCode.OK,(await c.PostAsJsonAsync("/admin/login",new{password=Password})).StatusCode);
        c.DefaultRequestHeaders.Remove("X-CSRF-TOKEN");c.DefaultRequestHeaders.Add("X-CSRF-TOKEN",await Csrf(c));
    }
    [Fact] public async Task Admin_RejectsMissingAuth_Csrf_AndPhoneBearer() {
        var c=Client();Assert.Equal(HttpStatusCode.Unauthorized,(await c.GetAsync("/admin/extensions")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,(await c.PostAsJsonAsync("/admin/login",new{password=Password})).StatusCode);
        await Login(c);c.DefaultRequestHeaders.Remove("X-CSRF-TOKEN");
        Assert.Equal(HttpStatusCode.BadRequest,(await c.PostAsJsonAsync("/admin/extensions",new{extension="121",displayName="Test",password="fixture-account-password"})).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,(await c.GetAsync("/api/v1/extensions")).StatusCode);
    }
    [Fact] public async Task CreateRename_ResetPassword_NoSecretsInList_AndDuplicateRejected() {
        var c=Client();await Login(c);
        var r=await c.PostAsJsonAsync("/admin/extensions",new{extension="121",displayName="نام آزمایشی",password="fixture-account-password"});
        Assert.Equal(HttpStatusCode.Accepted,r.StatusCode); // AMI deliberately absent: honest pending.
        Assert.False((await r.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("pbxApplied").GetBoolean());
        Assert.Equal(HttpStatusCode.Conflict,(await c.PostAsJsonAsync("/admin/extensions",new{extension="121",displayName="Other",password="fixture-account-password"})).StatusCode);
        var list=await c.GetStringAsync("/admin/extensions");Assert.DoesNotContain("fixture-account-password",list);Assert.DoesNotContain("sipSecret",list);Assert.DoesNotContain("passwordHash",list);
        Assert.Equal(HttpStatusCode.OK,(await c.PutAsJsonAsync("/admin/extensions/121",new{displayName="New name"})).StatusCode);
        var mobile=Client();var login=await mobile.PostAsJsonAsync("/api/v1/sessions",new{extension="121",password="fixture-account-password",installationId=Guid.NewGuid().ToString(),platform="android"});
        login.EnsureSuccessStatusCode();var token=(await login.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("accessToken").GetString();mobile.DefaultRequestHeaders.Authorization=new("Bearer",token);
        Assert.Equal(HttpStatusCode.Unauthorized,(await mobile.GetAsync("/admin/extensions")).StatusCode);
        var directory=await mobile.GetStringAsync("/api/v1/extensions");Assert.Contains("New name",directory);Assert.DoesNotContain("password",directory);Assert.DoesNotContain("sipSecret",directory);
        Assert.Equal(HttpStatusCode.Accepted,(await c.PutAsJsonAsync("/admin/extensions/121",new{displayName="New name",password="new-fixture-account-password"})).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,(await mobile.GetAsync("/api/v1/extensions")).StatusCode);
    }
    [Fact] public async Task InvalidNamesAndNumbersRejected_AndHttpLanDenied() {
        var c=Client();await Login(c);
        foreach(var ext in new[]{"100","200","../121"})
            Assert.Equal(HttpStatusCode.BadRequest,(await c.PostAsJsonAsync("/admin/extensions",new{extension=ext,displayName="Name",password="fixture-account-password"})).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,(await c.PostAsJsonAsync("/admin/extensions",new{extension="122",displayName=new string('x',81),password="fixture-account-password"})).StatusCode);
        var http=factory.CreateClient(new WebApplicationFactoryClientOptions{BaseAddress=new Uri("http://lan.example"),AllowAutoRedirect=false});
        Assert.Equal(HttpStatusCode.Forbidden,(await http.GetAsync("/admin/session")).StatusCode);
    }
    [Fact] public async Task DeleteRecreateAndUnbind_RevokeOldSessions_AndWatchPublishesChanges() {
        var admin=Client();await Login(admin);
        await admin.PostAsJsonAsync("/admin/extensions",new{extension="123",displayName="First",password="fixture-account-password"});
        var mobile=Client();
        async Task SignIn(string password) {
            var response=await mobile.PostAsJsonAsync("/api/v1/sessions",new{extension="123",password,installationId=Guid.NewGuid().ToString(),platform="android"});
            response.EnsureSuccessStatusCode();mobile.DefaultRequestHeaders.Authorization=new("Bearer",(await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("accessToken").GetString());
        }
        await SignIn("fixture-account-password");
        var oldToken=mobile.DefaultRequestHeaders.Authorization;
        Assert.Equal(HttpStatusCode.NoContent,(await mobile.DeleteAsync("/api/v1/sessions/current")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,(await mobile.GetAsync("/api/v1/extensions")).StatusCode);
        await SignIn("fixture-account-password");
        var first=await mobile.GetFromJsonAsync<JsonElement>("/api/v1/extensions/watch");
        var watching=mobile.GetAsync("/api/v1/extensions/watch?version="+first.GetProperty("version").GetString());
        await admin.PutAsJsonAsync("/admin/extensions/123",new{displayName="Changed"});
        var changed=await watching.WaitAsync(TimeSpan.FromSeconds(3));Assert.Contains("Changed",await changed.Content.ReadAsStringAsync());
        var current=await mobile.GetFromJsonAsync<JsonElement>("/api/v1/extensions/watch");
        watching=mobile.GetAsync("/api/v1/extensions/watch?version="+current.GetProperty("version").GetString());
        Assert.Equal(HttpStatusCode.Accepted,(await admin.PostAsJsonAsync("/admin/extensions/123/unbind",new{})).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,(await watching.WaitAsync(TimeSpan.FromSeconds(3))).StatusCode);
        await SignIn("fixture-account-password");
        admin.DefaultRequestHeaders.Remove("X-CSRF-TOKEN");
        Assert.Equal(HttpStatusCode.BadRequest,(await admin.DeleteAsync("/admin/extensions/123")).StatusCode);
        admin.DefaultRequestHeaders.Add("X-CSRF-TOKEN",await Csrf(admin));
        Assert.Equal(HttpStatusCode.Accepted,(await admin.DeleteAsync("/admin/extensions/123")).StatusCode);
        Assert.DoesNotContain("123",await admin.GetStringAsync("/admin/extensions"));
        Assert.DoesNotContain("[123]",File.ReadAllText(Path.Combine(root,"pbx","pjsip","accounts.conf")));
        Assert.Equal(HttpStatusCode.Unauthorized,(await mobile.GetAsync("/api/v1/extensions")).StatusCode);
        Assert.Equal(HttpStatusCode.Accepted,(await admin.PostAsJsonAsync("/admin/extensions",new{extension="123",displayName="Reused",password="new-fixture-account-password"})).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,(await mobile.GetAsync("/api/v1/extensions")).StatusCode);
        await SignIn("new-fixture-account-password");Assert.Contains("Reused",await mobile.GetStringAsync("/api/v1/extensions"));
    }
    [Fact] public async Task LegacyUnnamedAccountsCanBeDisabledWithoutForcingRename() {
        var admin=Client();await Login(admin);
        await admin.PostAsJsonAsync("/admin/extensions",new{extension="124",displayName="Initial",password="fixture-account-password"});
        Assert.Equal(HttpStatusCode.OK,(await admin.PutAsJsonAsync("/admin/extensions/124",new{displayName=""})).StatusCode);
        Assert.Equal(HttpStatusCode.Accepted,(await admin.PutAsJsonAsync("/admin/extensions/124",new{displayName="",enabled=false})).StatusCode);
        var rows=await admin.GetFromJsonAsync<JsonElement>("/admin/extensions");Assert.False(rows[0].GetProperty("enabled").GetBoolean());
        Assert.Equal(HttpStatusCode.Accepted,(await admin.PutAsJsonAsync("/admin/extensions/124",new{displayName="Restored",enabled=true})).StatusCode);
    }
    public void Dispose(){factory.Dispose();try{Directory.Delete(root,true);}catch{}}
}
