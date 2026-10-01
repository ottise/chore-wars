using System;
using ChoreWars.Domain.Enums;

namespace ChoreWars.Domain.Entities;

public class MemberPreference
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid ChoreId { get; set; }
    public PreferenceType Type { get; set; }

    public User User { get; set; } = null!;
    public Chore Chore { get; set; } = null!;
}
