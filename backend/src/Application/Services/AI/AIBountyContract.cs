using System.Text.Json;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services.AI;

public static class AIBountyContract
{
    public static JsonElement ValidateAndGround(JsonElement result, IReadOnlyDictionary<Guid, ChoreOccurrence> eligible)
    {
        if (!result.TryGetProperty("intent", out var intent) || intent.GetString() != "bounty_create") return result;
        var hasCandidate = result.TryGetProperty("bounty", out var candidate) && candidate.ValueKind != JsonValueKind.Null;
        if (hasCandidate && candidate.ValueKind != JsonValueKind.Object) throw new ConflictException("The assistant returned an invalid bounty draft.");
        ChoreOccurrence? occurrence = null;
        if (hasCandidate && candidate.TryGetProperty("occurrence_id", out var id) && id.ValueKind != JsonValueKind.Null)
        {
            if (id.ValueKind != JsonValueKind.String || !id.TryGetGuid(out var occurrenceId) || !eligible.TryGetValue(occurrenceId, out occurrence))
                throw new ConflictException("This chore is no longer eligible for a bounty. Choose one of your available chores.");
        }
        decimal? amount = null;
        if (hasCandidate && candidate.TryGetProperty("amount", out var money) && money.ValueKind != JsonValueKind.Null)
        {
            if (money.ValueKind != JsonValueKind.Number || !money.TryGetDecimal(out var value) || value <= 0 || decimal.Truncate(value) != value)
                throw new ConflictException("Enter a positive bounty amount in whole VND.");
            amount = value;
        }
        var fields = result.EnumerateObject().ToDictionary(p => p.Name, p => (object?)p.Value);
        var missing = result.TryGetProperty("missing_fields", out var missingFields) && missingFields.ValueKind == JsonValueKind.Array
            ? missingFields.EnumerateArray().Select(x => x.GetString()!).ToList() : [];
        if (occurrence == null) missing.Add("bounty_chore");
        if (amount == null) missing.Add("bounty_amount_vnd");
        fields["missing_fields"] = missing.Distinct().ToList();
        fields["requires_confirmation"] = false;
        // Names and deadlines come from current Core data, never generated text.
        fields["bounty"] = new { occurrence_id = occurrence?.Id, amount, chore_name = occurrence?.Chore.Name, due_at = occurrence?.DueDate };
        return JsonSerializer.SerializeToElement(fields);
    }
}
