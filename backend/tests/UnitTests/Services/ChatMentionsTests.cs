using ChoreWars.Application.Services;
using ChoreWars.Domain.Exceptions;

namespace UnitTests.Services;

public sealed class ChatMentionsTests
{
    [Fact]
    public void StableMemberIdsDoNotDependOnDuplicateDisplayNames()
    {
        var first = Guid.NewGuid(); var second = Guid.NewGuid();
        Assert.Equal([second], ChatMentions.Resolve($"@{{{second}}} @{{{second}}} giúp mình nhé", new HashSet<Guid> { first, second }));
    }
    [Fact]
    public void AllIsAnExplicitTokenAndDoesNotMatchAnEmail()
    {
        var members = new HashSet<Guid> { Guid.NewGuid(), Guid.NewGuid() };
        Assert.Empty(ChatMentions.Resolve("email@all.example.test", members));
        Assert.Equal(2, ChatMentions.Resolve("@all cả nhà ơi", members).Length);
    }
    [Fact]
    public void CannotTagAnOutsiderOrAFormerMember()
        => Assert.Throws<DomainException>(() => ChatMentions.Resolve($"@{{{Guid.NewGuid()}}} xem lịch", new HashSet<Guid>()));
    [Fact]
    public void InvalidIdentifierIsADomainErrorRatherThanAServerError()
        => Assert.Throws<DomainException>(() => ChatMentions.Resolve("@{------------------------------------}", new HashSet<Guid>()));
}
