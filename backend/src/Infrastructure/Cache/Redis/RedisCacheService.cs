using System;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using StackExchange.Redis;
using ChoreWars.Application.Interfaces.Services;

namespace ChoreWars.Infrastructure.Cache.Redis;

public class RedisCacheService : ICacheService
{
    private readonly IConnectionMultiplexer _redis;

    public RedisCacheService(IConnectionMultiplexer redis)
    {
        _redis = redis;
    }

    public async Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default)
    {
        try
        {
            if (!_redis.IsConnected) return default;
            var db = _redis.GetDatabase();
            var value = await db.StringGetAsync(key);
            if (!value.HasValue)
                return default;

            return JsonSerializer.Deserialize<T>(value.ToString());
        }
        catch
        {
            return default;
        }
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expiration = null, CancellationToken cancellationToken = default)
    {
        try
        {
            if (!_redis.IsConnected) return;
            var db = _redis.GetDatabase();
            var serialized = JsonSerializer.Serialize(value);
            if (expiration.HasValue)
            {
                await db.StringSetAsync(key, serialized, expiration.Value);
            }
            else
            {
                await db.StringSetAsync(key, serialized);
            }
        }
        catch
        {
            // Fallback gracefully
        }
    }

    public async Task RemoveAsync(string key, CancellationToken cancellationToken = default)
    {
        try
        {
            if (!_redis.IsConnected) return;
            var db = _redis.GetDatabase();
            await db.KeyDeleteAsync(key);
        }
        catch
        {
            // Fallback gracefully
        }
    }
}
