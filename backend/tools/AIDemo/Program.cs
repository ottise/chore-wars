using System.Text.Json;
using AIDemo;
using ChoreWars.Application.DTOs.Bounty;
using ChoreWars.Application.DTOs.House;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.DTOs.Season;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Common.Constants;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Enums;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Data;
using ChoreWars.Presentation.Extensions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;

var arguments=args.Chunk(2).ToDictionary(pair=>pair[0],pair=>pair.Length==2?pair[1]:throw new ArgumentException("Use --option value"));
var seed=int.Parse(arguments.GetValueOrDefault("--seed","42"));
var months=int.Parse(arguments.GetValueOrDefault("--months","14"));
if(months is <1 or >14)throw new ArgumentException("Use 1–14 months; independent seeds must not share histories.");
var output=Path.GetFullPath(arguments.GetValueOrDefault("--output",$"artifacts/ai-demo/seed-{seed}"));
if(Directory.Exists(output) && Directory.EnumerateFileSystemEntries(output).Any())throw new InvalidOperationException("Choose an empty output directory to preserve earlier evidence.");
Directory.CreateDirectory(output);
var adminSource=Environment.GetEnvironmentVariable("CHOREWARS_DEMO_POSTGRES_ADMIN") ?? throw new InvalidOperationException("Set CHOREWARS_DEMO_POSTGRES_ADMIN to a disposable local PostgreSQL server.");
var connection=new NpgsqlConnectionStringBuilder(adminSource);
if(connection.Host is not ("localhost" or "127.0.0.1"))throw new InvalidOperationException("Demo creation is restricted to local disposable databases.");
var database=$"cw_ai_demo_{seed}_{Guid.NewGuid():N}";
Console.WriteLine(JsonSerializer.Serialize(new{seed,database,status="CREATING_DISPOSABLE_DEMO",output}));
await using(var admin=new NpgsqlConnection(connection.ConnectionString)) {
    await admin.OpenAsync();await using var create=new NpgsqlCommand($"CREATE DATABASE \"{database}\"",admin);await create.ExecuteNonQueryAsync();
}
connection.Database=database;
var start=DateOnly.Parse(arguments.GetValueOrDefault("--start","2025-08-01"));
if(start.Day!=1)throw new ArgumentException("Start at the first local day of a month.");
var initial=ChoreWars.Application.Services.ScheduleTime.Utc(start,0);
var clock=new DemoClock(initial);
var identities=new DemoIdentity(seed);
var realtime=new DemoRealtimeLog(Path.Combine(output,"realtime-audit.jsonl"));
var config=new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{["ConnectionStrings:DefaultConnection"]=connection.ConnectionString,["AI:Enabled"]="true",["Jwt:Secret"]="demo-only-account-signing-secret-at-least-32-characters"}).Build();
var services=new ServiceCollection();services.AddLogging(builder=>builder.SetMinimumLevel(LogLevel.Warning));
services.AddInfrastructureServices(config);services.AddApplicationServices();
services.AddSingleton<TimeProvider>(clock);services.AddSingleton<IChoreOccurrenceIdentity>(identities);
services.AddSingleton<IActionProposalRealtimePublisher>(realtime);services.AddSingleton<INotificationRealtimePublisher>(realtime);
await using var provider=services.BuildServiceProvider(new ServiceProviderOptions{ValidateScopes=true});
async Task Use(Func<IServiceProvider,Task> action) {await using var scope=provider.CreateAsyncScope();await action(scope.ServiceProvider);}
async Task<T> Read<T>(Func<IServiceProvider,Task<T>> action) {await using var scope=provider.CreateAsyncScope();return await action(scope.ServiceProvider);}
await Use(async sp=>await sp.GetRequiredService<AppDbContext>().Database.MigrateAsync());
var house=identities.Named("house");var people=Enumerable.Range(0,6).Select(i=>identities.Named($"person/{i}")).ToArray();
var routines=Enumerable.Range(0,6).Select(i=>identities.Named($"routine/{i}")).ToArray();
var password=Environment.GetEnvironmentVariable("CHOREWARS_DEMO_PASSWORD") ?? "Demo-Only-2026!";
await Use(async sp=> {
    var db=sp.GetRequiredService<AppDbContext>();var hasher=sp.GetRequiredService<IPasswordHasher>();
    db.Houses.Add(new House{Id=house,Name=$"Gia đình mô phỏng — seed {seed}",InviteCode=identities.Named("invite").ToString("N")[..10],CreatedAt=initial,AiDataSource="DEMO_SYNTHETIC"});
    for(var i=0;i<people.Length;i++) {
        db.Users.Add(new User{Id=people[i],Email=$"demo-{seed}-{i}@example.invalid",DisplayName=$"Thành viên {i+1}",PasswordHash=hasher.Hash(password),CreatedAt=initial});
        db.HouseMembers.Add(new HouseMember{Id=identities.Named($"membership/{i}"),HouseId=house,UserId=people[i],Status=HouseMemberStatus.ACTIVE,Role=i==0?HouseRole.OWNER:HouseRole.MEMBER,JoinedAt=initial});
        var effort=(ChoreEffort)(1+i%3);
        db.Chores.Add(new Chore{Id=routines[i],HouseId=house,Name=new[]{"Rửa bát","Lau sàn","Nấu ăn","Giặt đồ","Dọn bếp","Chăm cây"}[i],Description="Routine giả lập có công bố nguồn",Type=ChoreType.NORMAL,FrequencyType=FrequencyType.DAILY,Difficulty=effort,KarmaPoints=10+i*3,EstimatedMinutes=ChoreWars.Application.Services.ScheduleTime.Effort(effort),DeadlineMinutes=1260,RecurrenceAnchor=start});
    }
    await db.SaveChangesAsync();
});
await Use(sp=>sp.GetRequiredService<IAIHousekeeperService>().SettingsAsync(house,people[0],true,false,default));
var room=await Read(sp=>sp.GetRequiredService<IChatService>().GetHouseRoomAsync(house,people[0]));
var contexts=new List<string>();var observed=new List<object>();
for(var month=0;month<months;month++) {
    var first=start.AddMonths(month);var last=first.AddMonths(1).AddDays(-1);
    clock.Set(ChoreWars.Application.Services.ScheduleTime.Utc(first,0));
    var season=await Read(sp=>sp.GetRequiredService<ISeasonService>().CreateSeasonAsync(house,new CreateSeasonRequest{Name=$"DEMO {first:yyyy-MM}",StartDate=ChoreWars.Application.Services.ScheduleTime.Utc(first,0),EndDate=ChoreWars.Application.Services.ScheduleTime.Utc(last,0),AllocationMethod=AllocationMethod.AUTOMATIC},people[0]));
    foreach(var member in people)await Use(sp=>sp.GetRequiredService<ISeasonService>().SetAvailabilityAsync(season.Id,new MemberAvailabilityRequest{Slots=Enumerable.Range(0,7).ToDictionary(day=>day,_=>new List<AvailabilitySlotRequest>{new(){StartMinute=480,EndMinute=1260}})},member));
    foreach(var routine in routines)await Use(sp=>sp.GetRequiredService<IChoreService>().ImportRoutineAsync(house,season.Id,routine,people[0]));
    var templates=await Read(async sp=>await sp.GetRequiredService<AppDbContext>().Chores.AsNoTracking().Where(c=>c.SeasonId==season.Id).ToListAsync());
    for(var member=0;member<people.Length;member++) {
        var preferred=templates.Single(c=>c.SourceTemplateId==routines[(member+(month>=7?1:0))%6]);
        await Use(sp=>sp.GetRequiredService<IHouseService>().SetMemberPreferencesAsync(house,new SetMemberPreferencesRequest{Preferences=[new(){ChoreId=preferred.Id,Type=PreferenceType.PREFERRED},new(){ChoreId=templates.Single(c=>c.SourceTemplateId==routines[(member+3)%6]).Id,Type=PreferenceType.DISLIKED}]},people[member]));
    }
    await Use(sp=>sp.GetRequiredService<ISeasonService>().GenerateScheduleAsync(season.Id,people[0]));
    var allocated=await Read(async sp=>await sp.GetRequiredService<AppDbContext>().ChoreOccurrences.Include(o=>o.Chore).AsNoTracking().Where(o=>o.SeasonId==season.Id).OrderBy(o=>o.DueDate).ThenByDescending(o=>o.SnapshotKarma).ToListAsync());
    if(allocated.Any(o=>o.AssignedUserId==null))throw new InvalidOperationException("Demo cannot silently omit unassigned chores.");
    var snapshot=await Read(sp=>sp.GetRequiredService<IAIContextBuilder>().BuildAsync(house,season.Id,default));
    // Reconstruct the common pre-allocation input; no outcomes or private chat are included.
    var context=JsonSerializer.Deserialize<Dictionary<string,JsonElement>>(snapshot.GetRawText())!;
    context["tasks"]=JsonSerializer.SerializeToElement(snapshot.GetProperty("tasks").EnumerateArray().Select(t=>{var task=t.EnumerateObject().ToDictionary(p=>p.Name,p=>p.Value);task["assigned_to"]=JsonSerializer.SerializeToElement<object?>(null);task["start_at"]=JsonSerializer.SerializeToElement<object?>(null);return task;}));
    var file=$"context-{month+1:00}.json";await File.WriteAllTextAsync(Path.Combine(output,file),JsonSerializer.Serialize(context));contexts.Add(file);
    await File.WriteAllTextAsync(Path.Combine(output,$"baseline-{month+1:00}.json"),snapshot.GetRawText());
    await Use(sp=>sp.GetRequiredService<ISeasonService>().SubmitReviewAsync(season.Id,people[0]));
    var revision=await Read(async sp=>(await sp.GetRequiredService<AppDbContext>().Seasons.AsNoTracking().SingleAsync(s=>s.Id==season.Id)).ScheduleRevision);
    foreach(var member in people)await Use(sp=>sp.GetRequiredService<ISeasonService>().ConfirmSeasonAsync(season.Id,member,expectedRevision:revision));
    var actions=new List<(DateTime At,Func<Task> Execute)>();
    var bountyTasks=new HashSet<Guid>();
    foreach(var task in allocated) {
        var assignee=task.AssignedUserId!.Value;var index=Array.IndexOf(people,assignee);var receiver=assignee;var key=$"{first:yyyy-MM}/{task.Chore.Name}/{task.DueDate:yyyy-MM-dd}";
        var day=DateOnly.FromDateTime(ChoreWars.Application.Services.ScheduleTime.Local(task.DueDate));
        if(identities.Draw(key+"/bounty")<(index<2?.22:.08)) {
            bountyTasks.Add(task.Id);
            receiver=people[index==5?4:5];var target=receiver;
            actions.Add((ChoreWars.Application.Services.ScheduleTime.Utc(day,490),async()=> {
                var bounty=await Read(sp=>sp.GetRequiredService<IBountyService>().CreateBountyAsync(house,new CreateBountyRequest{ChoreOccurrenceId=task.Id,Amount=10000+month*1000+index*2000},assignee));
                await Use(sp=>sp.GetRequiredService<IBountyService>().AcceptBountyAsync(bounty.Id,target));
            }));
        }
        var actual=receiver;var lateness=.12+index*.025+(month>=7 && index==4?.18:0);
        var draw=identities.Draw(key+"/completion");
        if(draw<.04)continue;
        var completion=task.DueDate.AddMinutes(draw<lateness?60+Math.Floor(identities.Draw(key+"/delay")*600):-60-Math.Floor(identities.Draw(key+"/early")*240));
        if(completion>ChoreWars.Application.Services.ScheduleTime.Utc(last,1440).AddTicks(-1))continue;
        actions.Add((completion,async()=> {
            await Use(sp=>sp.GetRequiredService<IChoreService>().CompleteChoreAsync(task.Id,null,actual));
            var payments=await Read(async sp=>await sp.GetRequiredService<AppDbContext>().PaymentObligations.AsNoTracking().Where(p=>p.OccurrenceId==task.Id && p.Status==PaymentObligationStatus.PENDING).ToListAsync());
            foreach(var payment in payments)if(identities.Draw(key+"/payment")<.8)await Use(sp=>sp.GetRequiredService<IBountyService>().SettlePaymentAsync(payment.Id,payment.CreditorUserId));
        }));
    }
    foreach(var day in allocated.GroupBy(o=>DateOnly.FromDateTime(ChoreWars.Application.Services.ScheduleTime.Local(o.DueDate)))) {
        var available=day.Where(t=>!bountyTasks.Contains(t.Id)).ToList();
        if(available.Count<2 || identities.Draw($"{day.Key}/request")>.25)continue;
        var source=available[0];var target=available.FirstOrDefault(t=>t.AssignedUserId!=source.AssignedUserId);
        if(target==null)continue;
        actions.Add((ChoreWars.Application.Services.ScheduleTime.Utc(day.Key,550),async()=> {
            try {
                var proposal=await Read(sp=>sp.GetRequiredService<IActionProposalService>().CreateProposalAsync(house,new CreateProposalRequest{Type=ProposalType.CHORE_SWAP,Title="Đề nghị đổi việc trong demo",Description="Tình huống yêu cầu tự nguyện; không suy ra động cơ.",PayloadJson=JsonSerializer.Serialize(new ChoreSwapPayload{SourceOccurrenceId=source.Id,TargetOccurrenceId=target.Id}),TargetUserIds=[target.AssignedUserId!.Value],ExpiresAt=clock.GetUtcNow().UtcDateTime.AddHours(1)},source.AssignedUserId!.Value));
                await Use(sp=>sp.GetRequiredService<IActionProposalService>().RespondProposalAsync(proposal.Id,new RespondProposalRequest{Status=ConfirmationStatus.REJECTED,Reason="Giữ lịch hiện tại trong tình huống giả lập."},target.AssignedUserId!.Value));
            } catch(ConflictException error) {
                await File.AppendAllTextAsync(Path.Combine(output,"ineligible-actions.jsonl"),JsonSerializer.Serialize(new{at=clock.GetUtcNow(),action="SWAP_REQUEST",source=source.Id,target=target.Id,status="REJECTED_BY_DOMAIN",reason=error.Message,eligible_label_created=false})+Environment.NewLine);
            }
        }));
    }
    for(var member=0;member<people.Length;member++) {
        var actor=people[member];var index=member;
        actions.Add((ChoreWars.Application.Services.ScheduleTime.Utc(first,420+member),()=>Use(sp=>sp.GetRequiredService<IChatService>().CreateMessageAsync(room.Id,actor,$"Tháng {first:MM/yyyy}: tôi muốn trao đổi lịch {new[]{"rửa bát","lau sàn","nấu ăn","giặt đồ","dọn bếp","chăm cây"}[index]} trước khi nhận trách nhiệm."))));
    }
    foreach(var action in actions.OrderBy(a=>a.At)) {clock.Set(action.At);await action.Execute();}
    clock.Set(ChoreWars.Application.Services.ScheduleTime.Utc(last,1440));
    await Use(sp=>sp.GetRequiredService<ISeasonEndService>().FinalizeSeasonAsync(season.Id));
    var status=await Read(async sp=>(await sp.GetRequiredService<AppDbContext>().Seasons.AsNoTracking().SingleAsync(s=>s.Id==season.Id)).Status);
    if(status!=SeasonStatus.COMPLETED)throw new InvalidOperationException("Demo season failed to finalize.");
    observed.Add(new{month=month+1,season_id=season.Id,policy="CORE_BASELINE",occurrences=allocated.Count,source="DEMO_SYNTHETIC"});
    Console.WriteLine(JsonSerializer.Serialize(new{seed,month=month+1,status="COMPLETED",occurrences=allocated.Count}));
}
await Use(async sp=> {
    var db=sp.GetRequiredService<AppDbContext>();
    var telemetry=await db.OutboxMessages.AsNoTracking().Where(e=>e.Topic==AIConstants.TelemetryTopic && e.MessageKey==house.ToString()).ToListAsync();
    var ordered=telemetry.OrderBy(e=>JsonDocument.Parse(e.Payload).RootElement.GetProperty("house_sequence").GetInt64());
    await File.WriteAllLinesAsync(Path.Combine(output,"events.jsonl"),ordered.Select(e=>e.Payload));
});
var manifest=new{version="core-business-demo-v1",seed,house_id=house,database,data_source="DEMO_SYNTHETIC",scenario_id="six-member-changing-preferences-v1",months,
    accounts=people.Select((id,i)=>new{id,email=$"demo-{seed}-{i}@example.invalid"}),contexts,events="events.jsonl",observed,
    bootstrap="Identity, membership and routine fixtures only; assignment, responsibility, completion, bounty, payment, penalty and season close use application services.",
    outcome_comparison="Only CORE_BASELINE outcomes were executed. S0/H1 schedule comparisons do not claim counterfactual completion or adjustment improvements."};
await File.WriteAllTextAsync(Path.Combine(output,"manifest.json"),JsonSerializer.Serialize(manifest,new JsonSerializerOptions{WriteIndented=true}));
Console.WriteLine(JsonSerializer.Serialize(new{manifest=Path.Combine(output,"manifest.json"),database,data_source="DEMO_SYNTHETIC"}));
