using System.Security.Cryptography;
using System.Text;
using ChoreWars.Application.Interfaces.Services;

namespace AIDemo;

public sealed class DemoIdentity(int seed) : IChoreOccurrenceIdentity
{
    public Guid Named(string name)=>new(SHA256.HashData(Encoding.UTF8.GetBytes($"chorewars-demo-v1/{seed}/{name}"))[..16]);
    public Guid ForDate(Guid templateId, DateOnly date)=>Named($"occurrence/{templateId}/{date:yyyy-MM-dd}");
    public double Draw(string name)=>BitConverter.ToUInt32(SHA256.HashData(Encoding.UTF8.GetBytes($"{seed}/{name}")),0)/(double)uint.MaxValue;
}
