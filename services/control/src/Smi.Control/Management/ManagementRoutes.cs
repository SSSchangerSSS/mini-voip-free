using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;
using Smi.Control.Auth;

namespace Smi.Control.Management;

public static class ManagementRoutes
{
    public static void MapManagement(this WebApplication app)
    {
        app.Use(async (ctx,next) => {
            if(ctx.Request.Path.StartsWithSegments("/admin")) {
                // HTTP allowed only for a literal loopback URL; TLS required across the LAN.
                var h=ctx.Request.Host.Host;
                if(!ctx.Request.IsHttps && !(System.Net.IPAddress.IsLoopback(ctx.Connection.RemoteIpAddress ?? System.Net.IPAddress.None) && h is "localhost" or "127.0.0.1" or "[::1]")) {
                    ctx.Response.StatusCode=403; return;
                }
                if(ctx.Request.ContentLength>4096){ctx.Response.StatusCode=413;return;}
                ctx.Response.Headers.CacheControl="no-store";
                ctx.Response.Headers.ContentSecurityPolicy="default-src 'self'; script-src 'self'; style-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'";
            }
            await next();
        });
        foreach(var file in new[]{"index.html","admin.js","admin.css"}) {
            var asset=file;
            app.MapGet(file=="index.html"?"/admin":"/admin/"+file,()=>Asset(asset));
        }
        app.MapGet("/admin/session", (HttpContext ctx,IAntiforgery csrf,SmiConfig cfg) => Results.Json(new {
            authenticated=ctx.User.Identity?.IsAuthenticated==true,
            configured=cfg.AdminPassword is not null,
            csrfToken=csrf.GetAndStoreTokens(ctx).RequestToken,
        }));
        app.MapPost("/admin/login",async(HttpContext ctx,IAntiforgery csrf,SmiConfig cfg) => {
            if(!await ValidCsrf(ctx,csrf))return Results.BadRequest();
            if(string.IsNullOrEmpty(cfg.AdminPassword))return Results.StatusCode(503);
            var ip=ctx.Connection.RemoteIpAddress?.ToString()??"unknown";
            if(LoginThrottle.IsBlocked(ip,"admin"))return Results.StatusCode(429);
            var body=await ctx.Request.ReadFromJsonAsync<LoginInput>();
            if(body?.Password is not string pw || pw.Length>256 || !CryptographicOperations.FixedTimeEquals(
                SHA256.HashData(Encoding.UTF8.GetBytes(cfg.AdminPassword)),SHA256.HashData(Encoding.UTF8.GetBytes(pw)))) {
                LoginThrottle.RecordFailure(ip,"admin");return Results.Unauthorized();
            }
            LoginThrottle.Reset(ip,"admin");
            await ctx.SignInAsync("admin",new ClaimsPrincipal(new ClaimsIdentity(new[]{new Claim(ClaimTypes.Role,"admin")},"admin")));
            return Results.Ok();
        });
        app.MapPost("/admin/logout",async(HttpContext ctx,IAntiforgery csrf)=>{
            if(!await ValidCsrf(ctx,csrf))return Results.BadRequest();
            await ctx.SignOutAsync("admin"); return Results.Ok();
        });
        app.MapGet("/admin/extensions",(HttpContext ctx,ExtensionManager manager)=>
            IsAdmin(ctx)?Results.Ok(manager.List()):Results.Unauthorized());
        app.MapPost("/admin/extensions",async(HttpContext ctx,ExtensionManager manager,IAntiforgery csrf)=>{
            if(!IsAdmin(ctx))return Results.Unauthorized();
            if(!await ValidCsrf(ctx,csrf))return Results.BadRequest();
            var input=await ctx.Request.ReadFromJsonAsync<ExtensionInput>();
            if(input is null)return Results.BadRequest();
            return Reply(await manager.Save(input.Extension??"",input.DisplayName??"",input.Password,null,true));
        });
        app.MapPut("/admin/extensions/{ext}",async(string ext,HttpContext ctx,ExtensionManager manager,IAntiforgery csrf)=>{
            if(!IsAdmin(ctx))return Results.Unauthorized();
            if(!await ValidCsrf(ctx,csrf))return Results.BadRequest();
            var input=await ctx.Request.ReadFromJsonAsync<ExtensionInput>();
            if(input is null)return Results.BadRequest();
            return Reply(await manager.Save(ext,input.DisplayName??"",input.Password,input.Enabled,false));
        });
        app.MapPost("/admin/extensions/{ext}/unbind",async(string ext,HttpContext ctx,ExtensionManager manager,IAntiforgery csrf)=>{
            if(!IsAdmin(ctx))return Results.Unauthorized();
            if(!await ValidCsrf(ctx,csrf))return Results.BadRequest();
            return Reply(await manager.Unbind(ext));
        });
        app.MapDelete("/admin/extensions/{ext}",async(string ext,HttpContext ctx,ExtensionManager manager,IAntiforgery csrf)=>{
            if(!IsAdmin(ctx))return Results.Unauthorized();
            if(!await ValidCsrf(ctx,csrf))return Results.BadRequest();
            return Reply(await manager.Delete(ext));
        });
        app.MapGet("/api/v1/extensions/watch",async(HttpContext ctx,ExtensionManager manager,SessionService sessions)=>{
            var version=ctx.Request.Query["version"].ToString();
            var until=DateTime.UtcNow.AddSeconds(25);
            while(true) {
                var signal=manager.Changed;
                var token=ctx.Request.Headers.Authorization.ToString();
                if(!token.StartsWith("Bearer ") || sessions.Validate(token[7..],DateTime.UtcNow) is null)return Results.Unauthorized();
                if(manager.Version()!=version || DateTime.UtcNow>=until)return Results.Ok(manager.Snapshot());
                await Task.WhenAny(signal,Task.Delay(TimeSpan.FromSeconds(5),ctx.RequestAborted));
                ctx.RequestAborted.ThrowIfCancellationRequested();
            }
        });
        app.MapGet("/api/v1/extensions",(ExtensionManager manager)=>Results.Ok(manager.Directory()));
    }
    static bool IsAdmin(HttpContext ctx)=>ctx.User.IsInRole("admin");
    static async Task<bool> ValidCsrf(HttpContext ctx,IAntiforgery csrf) {
        try {await csrf.ValidateRequestAsync(ctx);return true;} catch(AntiforgeryValidationException){return false;}
    }
    static IResult Reply((string? Error,bool Applied) r)=>r.Error is not null
        ? Results.Json(new{code=r.Error},statusCode:r.Error=="INVALID_INPUT"?400:r.Error=="NOT_FOUND"?404:409)
        : Results.Json(new{saved=true,pbxApplied=r.Applied,status=r.Applied?"APPLIED":"RELOAD_PENDING"},statusCode:r.Applied?200:202);
    static IResult Asset(string name) {
        var stream=typeof(ManagementRoutes).Assembly.GetManifestResourceStream("Smi.Control.Management.Assets."+name);
        return stream is null?Results.NotFound():Results.Stream(stream,name.EndsWith(".js")?"text/javascript; charset=utf-8":name.EndsWith(".css")?"text/css; charset=utf-8":"text/html; charset=utf-8");
    }
    sealed record LoginInput(string? Password);
    sealed record ExtensionInput(string? Extension,string? DisplayName,string? Password,bool? Enabled);
}
