namespace ChoreWars.Domain.Exceptions;

public sealed class ServiceUnavailableException : DomainException
{
    public ServiceUnavailableException(string message) : base(message)
    {
    }
}
