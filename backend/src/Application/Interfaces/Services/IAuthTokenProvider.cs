using System;
using ChoreWars.Domain.Entities;

namespace ChoreWars.Application.Interfaces.Services;

public interface IAuthTokenProvider
{
    string GenerateJwtToken(User user);
    string GenerateRefreshToken();
}
