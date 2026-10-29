namespace ChoreWars.Application.DTOs.House;
public sealed record MemberContributionResponse(Guid UserId, string Name, int Assigned, int Completed, int PlannedMinutes, int Remaining, int Overdue);
public sealed record SummaryOrderResponse(Guid Id, string Supplier, Guid PayerUserId, string Payer, decimal Amount, DateTime RecordedAt, string ConfirmationSource);
public sealed record HouseholdSummaryResponse(DateOnly From, DateOnly To, Guid? SeasonId, decimal ExternalPayments,
    int PaidOrderCount, int UnpaidOrderCount, decimal InternalTransfers, int Assigned, int Completed, int OnTime,
    int Overdue, int Upcoming, int Skipped, List<MemberContributionResponse> Members, List<SummaryOrderResponse> Orders,
    int CompletionTimingKnown, int CompletionAuthorUnknown);
