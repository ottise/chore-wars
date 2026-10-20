using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Infrastructure.Migrations;
[DbContext(typeof(AppDbContext))]
[Migration("20261020061539_SeedDefaultHouseAchievements")]
public sealed class SeedDefaultHouseAchievements : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.Sql("""
        INSERT INTO "Achievements" ("Id","HouseId","Name","Description","ConditionType","Threshold")
        SELECT gen_random_uuid(),h."Id",a.name,a.description,a.condition,a.threshold
        FROM "Houses" h
        CROSS JOIN (VALUES
          ('First chore','Complete your first chore in this household.','CHORES_COMPLETED',1),
          ('Karma collector','Earn 100 Karma from chores in this household.','KARMA_EARNED',100),
          ('Three-day streak','Complete chores on three consecutive Vietnam calendar days.','STREAK_DAYS',3),
          ('Helping hand','Accept your first bounty in this household.','BOUNTIES_CLAIMED',1)
        ) AS a(name,description,condition,threshold)
        WHERE NOT EXISTS (SELECT 1 FROM "Achievements" x WHERE x."HouseId"=h."Id" AND x."Name"=a.name AND x."ConditionType"=a.condition AND x."Threshold"=a.threshold);
        """);
    // Awards may reference these definitions. Retain them on downgrade to preserve history.
    protected override void Down(MigrationBuilder migrationBuilder) { }
}
