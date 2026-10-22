using System.ComponentModel.DataAnnotations;

namespace ChoreWars.Application.DTOs.AI;

public sealed class AITextRequest
{
    [Required, StringLength(8000, MinimumLength=1)] public string Text { get; set; } = "";
    public Guid? SeasonId { get; set; }
}
