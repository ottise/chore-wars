using System;

namespace ChoreWars.Domain.Exceptions;

public class ForbiddenException : DomainException
{
    public ForbiddenException(string message = "You do not have permission to perform this action.") 
        : base(message)
    {
    }
}
