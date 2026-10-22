using System.Security.Claims;
using System.Text.Json;
using System.ComponentModel.DataAnnotations;
using ChoreWars.Application.DTOs.AI;
using ChoreWars.Application.Interfaces.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ChoreWars.Presentation.Controllers;

[ApiController, Authorize]
[Route("api/houses/{houseId:guid}/ai")]
[Route("api/v1/houses/{houseId:guid}/ai")]
public sealed class AIHousekeeperController(IAIHousekeeperService service) : ControllerBase
{
    private Guid Actor => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub") ?? throw new UnauthorizedAccessException());
    [HttpPost("observations")]
    public Task<JsonElement> Observe(Guid houseId,[FromBody]AIObservationRequest request,CancellationToken ct)=>service.ObserveAsync(houseId,Actor,request,ct);
    [HttpGet("profiles")]
    public Task<JsonElement> Profiles(Guid houseId,CancellationToken ct,[FromQuery,RegularExpression("^(all-time|30d|90d|season)$")]string period="all-time",[FromQuery]Guid? seasonId=null)=>service.ReadAsync(houseId,Actor,$"profiles?period={Uri.EscapeDataString(period)}{(seasonId.HasValue?$"&season_id={seasonId}":"")}",false,ct);
    [HttpGet("evidence/{id:guid}")]
    public Task<JsonElement> Evidence(Guid houseId,Guid id,CancellationToken ct)=>service.ReadAsync(houseId,Actor,$"evidence/{id}",false,ct);
    [HttpGet("contributions")]
    public Task<JsonElement> Contributions(Guid houseId,CancellationToken ct)=>service.ReadAsync(houseId,Actor,"profiles",false,ct);
    [HttpGet("learning-report")]
    public Task<JsonElement> Learning(Guid houseId,CancellationToken ct)=>service.ReadAsync(houseId,Actor,"learning-status",true,ct);
    [HttpGet("models/status")]
    public Task<JsonElement> Models(Guid houseId,CancellationToken ct)=>service.ReadAsync(houseId,Actor,"models/status",true,ct);
    [HttpGet("learning/timeline")]
    public Task<JsonElement> Timeline(Guid houseId,CancellationToken ct,[FromQuery]int page=1)=>service.ReadAsync(houseId,Actor,$"learning/timeline?page={Math.Max(1,page)}",true,ct);
    [HttpGet("learning/training-runs/{id:guid}")]
    public Task<JsonElement> Training(Guid houseId,Guid id,CancellationToken ct)=>service.ReadAsync(houseId,Actor,$"learning/training-runs/{id}",true,ct);
    [HttpGet("learning/training-runs")]
    public Task<JsonElement> TrainingRuns(Guid houseId,CancellationToken ct,[FromQuery]int page=1)=>service.ReadAsync(houseId,Actor,$"learning/training-runs?page={Math.Max(1,page)}",true,ct);
    [HttpGet("chat/insights")]
    public Task<JsonElement> ChatInsights(Guid houseId,CancellationToken ct)=>service.ChatInsightsAsync(houseId,Actor,ct);
    [HttpGet("failures")]
    public Task<JsonElement> Failures(Guid houseId,CancellationToken ct)=>service.ReadAsync(houseId,Actor,"failures",true,ct);
    [HttpPost("evaluations/seasons/{seasonId:guid}")]
    public Task<JsonElement> Evaluate(Guid houseId,Guid seasonId,CancellationToken ct)=>service.EvaluateAsync(houseId,Actor,seasonId,ct);
    [HttpGet("bounties/suggestions")]
    public Task<JsonElement> Bounties(Guid houseId,CancellationToken ct)=>service.BountySuggestionsAsync(houseId,Actor,ct);
    [HttpGet("me/risk-insights")]
    public Task<JsonElement> Risk(Guid houseId,CancellationToken ct)=>service.OwnRiskAsync(houseId,Actor,ct);
    [HttpPut("me/availability-exceptions")]
    public Task<JsonElement> AvailabilityException(Guid houseId,[FromBody]AIAvailabilityExceptionRequest request,CancellationToken ct)=>service.SetAvailabilityExceptionAsync(houseId,Actor,request,ct);
    [HttpPost("me/availability-confirmations")]
    public Task<JsonElement> ConfirmAvailability(Guid houseId,[FromBody]AIAvailabilityChangeRequest request,CancellationToken ct)=>service.ConfirmAvailabilityAsync(houseId,Actor,request,ct);
    [HttpGet("evaluations/runs")]
    public Task<JsonElement> Runs(Guid houseId,CancellationToken ct,[FromQuery]int page=1)=>service.ReadAsync(houseId,Actor,$"evaluations/runs?page={Math.Max(1,page)}",true,ct);
    [HttpGet("evaluations/aggregates")]
    public Task<JsonElement> Aggregates(Guid houseId,CancellationToken ct)=>service.ReadAsync(houseId,Actor,"evaluations/aggregates",true,ct);
    [HttpGet("evaluations/runs/{id:guid}")]
    public Task<JsonElement> Run(Guid houseId,Guid id,CancellationToken ct)=>service.ReadAsync(houseId,Actor,$"evaluations/runs/{id}",true,ct);
    [HttpGet("evaluations/runs/{id:guid}/examples")]
    public Task<JsonElement> Examples(Guid houseId,Guid id,CancellationToken ct,[FromQuery]int page=1)=>service.ReadAsync(houseId,Actor,$"evaluations/runs/{id}/examples?page={Math.Max(1,page)}",true,ct);
    [HttpGet("evaluations/comparisons/{id:guid}")]
    public Task<JsonElement> Compare(Guid houseId,Guid id,CancellationToken ct)=>service.ReadAsync(houseId,Actor,$"evaluations/comparisons/{id}",true,ct);
    [HttpPost("schedules/propose")]
    public Task<JsonElement> Propose(Guid houseId,[FromBody]AIGenerateRequest request,CancellationToken ct) { request.Kind="ALLOCATION";return service.GenerateAsync(houseId,Actor,request,ct); }
    [HttpPost("schedules/replan")]
    public Task<JsonElement> Replan(Guid houseId,[FromBody]AIGenerateRequest request,CancellationToken ct) { request.Kind="REPLAN";return service.GenerateAsync(houseId,Actor,request,ct); }
    [HttpPost("schedules/swap")]
    public Task<JsonElement> Swap(Guid houseId,[FromBody]AIGenerateRequest request,CancellationToken ct) { request.Kind="SWAP";return service.GenerateAsync(houseId,Actor,request,ct); }
    [HttpPost("seasons/evolve")]
    public Task<JsonElement> Evolve(Guid houseId,[FromBody]AIGenerateRequest request,CancellationToken ct) { request.Kind="EVOLUTION";return service.GenerateAsync(houseId,Actor,request,ct); }
    [HttpPost("urgent/plan")]
    public Task<JsonElement> Urgent(Guid houseId,[FromBody]AIGenerateRequest request,CancellationToken ct) {request.Kind="URGENT";return service.GenerateAsync(houseId,Actor,request,ct);}
    [HttpGet("recommendations/{id:guid}")]
    public Task<JsonElement> Recommendation(Guid houseId,Guid id,CancellationToken ct)=>service.RecommendationAsync(houseId,Actor,id,ct);
    [HttpPost("recommendations/{id:guid}/accept")]
    public Task<JsonElement> Accept(Guid houseId,Guid id,CancellationToken ct)=>service.AcceptAsync(houseId,Actor,id,ct);
    [HttpPost("recommendations/{id:guid}/reject")]
    public Task<JsonElement> Reject(Guid houseId,Guid id,CancellationToken ct)=>service.RejectAsync(houseId,Actor,id,ct);
    [HttpPost("interpret")]
    public Task<JsonElement> Interpret(Guid houseId,[FromBody]AITextRequest request,CancellationToken ct)=>service.InterpretAsync(houseId,Actor,request,false,ct);
    [HttpPost("chat/insights")]
    public Task<JsonElement> Chat(Guid houseId,[FromBody]AITextRequest request,CancellationToken ct)=>service.InterpretAsync(houseId,Actor,request,true,ct);
    [HttpGet("settings")]
    public Task<JsonElement> Settings(Guid houseId,CancellationToken ct)=>service.SettingsAsync(houseId,Actor,null,null,ct);
    [HttpPut("settings")]
    public Task<JsonElement> SetSettings(Guid houseId,[FromBody]Dictionary<string,bool> request,CancellationToken ct)=>service.SettingsAsync(houseId,Actor,request.GetValueOrDefault("enabled"),request.GetValueOrDefault("chatAutoInsightsEnabled"),ct);
    [HttpGet("me/consent")]
    public Task<JsonElement> Consent(Guid houseId,CancellationToken ct)=>service.ConsentAsync(houseId,Actor,null,ct);
    [HttpPut("me/consent")]
    public Task<JsonElement> SetConsent(Guid houseId,[FromBody]Dictionary<string,bool> request,CancellationToken ct)=>service.ConsentAsync(houseId,Actor,request.GetValueOrDefault("chatAnalysisEnabled"),ct);
}
