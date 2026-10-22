using System.Security.Cryptography;
using System.Text.Json;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Repositories;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;

namespace ChoreWars.Application.Services.AI;

public sealed class EvidenceService(IUnitOfWork uow, IAIStateRepository ai, IMediaStorage storage,
    IHouseAccessService access, IHouseMutationCoordinator mutations, IAIHousekeeperClient client, TimeProvider clock) : IEvidenceService
{
    public async Task<JsonElement> UploadAsync(Guid occurrenceId, Guid actor, Guid requestId, byte[] bytes, CancellationToken ct)
    {
        if (requestId==Guid.Empty || bytes.Length is <12 or >5_000_000) throw new DomainException("A request ID and image up to 5 MB are required.");
        var type=bytes.AsSpan().StartsWith(new byte[]{137,80,78,71,13,10,26,10})?"image/png":bytes.AsSpan().StartsWith(new byte[]{255,216,255})?"image/jpeg":null;
        if (type==null) throw new DomainException("Evidence must be a PNG or JPEG image.");
        var hash=Convert.ToHexString(SHA256.HashData(bytes));
        var context=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct) ?? throw new NotFoundException("Occurrence not found.");
        return await mutations.RunAsync(context.Chore.HouseId,async()=> {
            var task=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct) ?? throw new NotFoundException("Occurrence not found.");
            await access.EnsureActiveAsync(task.Chore.HouseId,actor,ct);await access.EnsureWritableAsync(task.Chore.HouseId,ct);
            var old=await ai.EvidenceRequestAsync(occurrenceId,actor,requestId,ct);
            if (old!=null) { if (old.ContentHash!=hash) throw new ConflictException("Evidence request ID has different bytes.");return View(old); }
            if (task.AssignedUserId!=actor || task.Status is ChoreOccurrenceStatus.COMPLETED or ChoreOccurrenceStatus.SKIPPED) throw new ForbiddenException("Only the current assignee may upload evidence.");
            var season=await uow.Seasons.GetByIdAsync(task.SeasonId,ct) ?? throw new NotFoundException("Season not found.");
            if (season.Status is SeasonStatus.DRAFT or SeasonStatus.REVIEWING or SeasonStatus.CANCELLED || clock.GetUtcNow().UtcDateTime<season.StartDate)
                throw new ConflictException("Evidence can only be uploaded after the approved season starts.");
            var value=new ChoreEvidence{Id=Guid.NewGuid(),HouseId=task.Chore.HouseId,OccurrenceId=occurrenceId,UploadedByUserId=actor,ClientRequestId=requestId,StorageKey=Guid.NewGuid().ToString("N"),ContentType=type,ContentHash=hash,CreatedAt=clock.GetUtcNow().UtcDateTime};
            await storage.WriteAsync(value.StorageKey,bytes,ct);ai.AddEvidence(value);
            return View(value);
        },ct);
    }

    public async Task<AIEvidenceContent> ReadAsync(Guid evidenceId, Guid actor, CancellationToken ct)
    {
        var value=await ai.EvidenceAsync(evidenceId,ct) ?? throw new NotFoundException("Evidence not found.");
        await access.EnsureActiveAsync(value.HouseId,actor,ct);
        if (!value.AttachedAt.HasValue && value.UploadedByUserId!=actor) throw new ForbiddenException("Unattached evidence is private to its uploader.");
        return new(await storage.ReadAsync(value.StorageKey,ct),value.ContentType);
    }

    public async Task<JsonElement> VerifyAsync(Guid occurrenceId, Guid evidenceId, Guid actor, CancellationToken ct)
    {
        var value=await ai.EvidenceAsync(evidenceId,ct) ?? throw new NotFoundException("Evidence not found.");
        var occurrence=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct) ?? throw new NotFoundException("Occurrence not found.");
        await access.EnsureActiveAsync(value.HouseId,actor,ct);
        if (value.OccurrenceId!=occurrenceId || value.UploadedByUserId!=actor || occurrence.AssignedUserId!=actor) throw new ForbiddenException("Evidence scope mismatch.");
        if ((await ai.SettingsAsync(value.HouseId,ct))?.Enabled!=true) throw new ConflictException("AI is disabled for this household.");
        var hash=value.ContentHash;
        await using var stream=await storage.ReadAsync(value.StorageKey,ct);using var buffer=new MemoryStream();await stream.CopyToAsync(buffer,ct);
        var result=await client.PostAsync(value.HouseId,actor,"/v1/vision/verify-proof",new{house_id=value.HouseId,evidence_id=evidenceId,chore=occurrence.Chore.Name,mime_type=value.ContentType,image_base64=Convert.ToBase64String(buffer.ToArray())},ct);
        if (result.GetProperty("can_complete_automatically").GetBoolean()) throw new DomainException("Vision must remain advisory.");
        return await mutations.RunAsync(value.HouseId,async()=> {
            await access.EnsureActiveAsync(value.HouseId,actor,ct);
            var current=await ai.EvidenceAsync(evidenceId,ct) ?? throw new NotFoundException("Evidence not found.");
            var task=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct) ?? throw new NotFoundException("Occurrence not found.");
            if (current.ContentHash!=hash || task.AssignedUserId!=actor || (await ai.SettingsAsync(value.HouseId,ct))?.Enabled!=true) throw new ConflictException("Evidence or permission changed during inference.");
            current.VisionJson=result.GetRawText();return result;
        },ct);
    }

    public async Task AttachAsync(Guid occurrenceId, Guid evidenceId, Guid actor, CancellationToken ct)
    {
        var value=await ai.EvidenceAsync(evidenceId,ct) ?? throw new NotFoundException("Evidence not found.");
        if (value.OccurrenceId!=occurrenceId || value.UploadedByUserId!=actor) throw new ForbiddenException("Evidence scope mismatch.");
        await access.EnsureActiveAsync(value.HouseId,actor,ct);
        value.AttachedAt ??=clock.GetUtcNow().UtcDateTime;
        var task=await uow.ChoreOccurrences.GetByIdAsync(occurrenceId,ct) ?? throw new NotFoundException("Occurrence not found.");
        task.EvidenceId=evidenceId;
    }

    private static JsonElement View(ChoreEvidence value) => JsonSerializer.SerializeToElement(new{id=value.Id,occurrence_id=value.OccurrenceId,content_type=value.ContentType,content_hash=value.ContentHash,attached=value.AttachedAt.HasValue});
}
