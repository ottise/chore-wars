using System.Text.RegularExpressions;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services;

public static partial class ChatMentions
{
    public const string All = "@all";
    public const string Agent = "@agent";
    public const string RoomTarget = "CHAT_ROOM";

    [GeneratedRegex(@"@\{(?<id>[0-9a-fA-F-]{36})\}")]
    private static partial Regex MemberPattern();
    [GeneratedRegex(@"(?<![\w@])@all\b", RegexOptions.IgnoreCase)]
    private static partial Regex AllPattern();

    public static Guid[] Resolve(string content, IReadOnlySet<Guid> activeMembers)
    {
        var ids = MemberPattern().Matches(content).Select(m => Guid.TryParse(m.Groups["id"].Value, out var id)
            ? id : throw new DomainException("Invalid member mention.")).Distinct().ToArray();
        if (ids.Any(id => !activeMembers.Contains(id)))
            throw new DomainException("Only active members of this household can be mentioned.");
        return AllPattern().IsMatch(content) ? activeMembers.ToArray() : ids;
    }
}
