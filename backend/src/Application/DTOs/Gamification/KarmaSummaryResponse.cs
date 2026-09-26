namespace ChoreWars.Application.DTOs.Gamification;

public class KarmaSummaryResponse
{
    public int Current { get; set; }
    public int NormalChores { get; set; }
    public int Bonus { get; set; }
    public int Penalties { get; set; }
}
