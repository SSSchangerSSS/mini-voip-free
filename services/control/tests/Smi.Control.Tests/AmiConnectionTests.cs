using System.Net;
using System.Net.Sockets;
using System.Text;
using Microsoft.Extensions.Logging.Abstractions;
using Smi.Control.Ami;
using Xunit;

namespace Smi.Control.Tests;

public sealed class AmiConnectionTests
{
    [Fact]
    public async Task LoginIsSentBeforeReady_AndFragmentedResponseIsReadWhileAwaitingLogin()
    {
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        using var client = new AmiClient(new SmiConfig
        {
            AmiHost = "127.0.0.1", AmiPort = ((IPEndPoint)listener.LocalEndpoint).Port,
            AmiSecret = "fixture-only-not-a-production-secret",
        }, NullLogger<AmiClient>.Instance);
        await client.StartAsync(deadline.Token);
        try
        {
            using var peer = await listener.AcceptTcpClientAsync(deadline.Token);
            var stream = peer.GetStream();
            using var input = new StreamReader(stream, Encoding.ASCII, leaveOpen: true);
            await stream.WriteAsync(Encoding.ASCII.GetBytes("Asterisk Call Manager/11.0\r\n"), deadline.Token);
            var login = await ReadPacket(input, deadline.Token);
            Assert.Equal("Login", login["Action"]);
            Assert.Contains("user", login["Events"].Split(','));
            Assert.False(client.ConnectedAndLoggedIn);
            var reply = $"Response: Success\r\nActionID: {login["ActionID"]}\r\nMessage: Authentication accepted\r\n\r\n";
            // Split within CRLF and within fields to exercise TCP fragmentation.
            foreach (var value in Encoding.ASCII.GetBytes(reply))
                await stream.WriteAsync(new[] { value }, deadline.Token);
            while (!client.ConnectedAndLoggedIn)
                await Task.Delay(10, deadline.Token);

            var pingTask = client.SendAction(new Dictionary<string, string> { ["Action"] = "Ping" }, deadline.Token);
            var ping = await ReadPacket(input, deadline.Token);
            Assert.Equal("Ping", ping["Action"]);
            await stream.WriteAsync(Encoding.ASCII.GetBytes(
                $"Response: Success\r\nActionID: {ping["ActionID"]}\r\nPing: Pong\r\n\r\n"), deadline.Token);
            Assert.Equal("Pong", (await pingTask)!.Get("Ping"));
        }
        finally
        {
            await client.StopAsync(CancellationToken.None);
        }
    }

    private static async Task<Dictionary<string, string>> ReadPacket(StreamReader input, CancellationToken ct)
    {
        var fields = new Dictionary<string, string>();
        while (await input.ReadLineAsync(ct) is { } line && line.Length != 0)
        {
            var parts = line.Split(':', 2);
            if (parts.Length == 2) fields[parts[0]] = parts[1].Trim();
        }
        return fields;
    }
}
