using ChoreWars.Application.Interfaces.Services;
using Microsoft.Extensions.Options;

namespace ChoreWars.Infrastructure.AI;

public sealed class AIServiceStatus(IOptions<AIOptions> options) : IAIServiceStatus
{
    public bool IsConfigured => options.Value.Enabled && options.Value.ServiceKey.Length >= 32;
}
