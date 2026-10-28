using Smi.Control.Calls;
using Xunit;

namespace Smi.Control.Tests;

public class CallStateMachineTests
{
    [Theory]
    [InlineData("Pending", "Connecting", true)]
    [InlineData("Pending", "Connected", true)]   // only with PBX evidence
    [InlineData("Pending", "Ended", true)]
    [InlineData("Connecting", "Connected", true)]
    [InlineData("Connecting", "Ended", true)]
    [InlineData("Connected", "Ended", true)]
    [InlineData("Connecting", "Pending", false)] // downgrade forbidden
    [InlineData("Connected", "Connecting", false)]
    [InlineData("Connected", "Pending", false)]
    [InlineData("Ended", "Pending", false)]      // Ended is terminal — never revived
    [InlineData("Ended", "Connecting", false)]
    [InlineData("Ended", "Connected", false)]
    public void Transitions_FollowSpec(string fromS, string toS, bool expected)
    {
        var from = Enum.Parse<CallState>(fromS);
        var to = Enum.Parse<CallState>(toS);
        Assert.Equal(expected, CallStateMachine.CanTransition(from, to));
    }

    [Fact]
    public void EnsureTransition_Throws_OnInvalid()
    {
        Assert.Throws<InvalidTransitionException>(() =>
            CallStateMachine.EnsureTransition(CallState.Ended, CallState.Connected));
    }

    [Fact]
    public void EndReasons_AreTheFixedSet()
    {
        var expected = new[] { "Completed", "Declined", "CallerCancelled", "NoAnswer", "Busy",
            "Unavailable", "Expired", "NetworkLost", "ServerRestart", "SetupFailed", "AccountDisabled" };
        Assert.Equal(expected, Enum.GetNames<EndReason>());
    }
}
