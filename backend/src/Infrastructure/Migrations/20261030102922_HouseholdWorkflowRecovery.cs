using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class HouseholdWorkflowRecovery : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ChatReadAt",
                table: "HouseMembers",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.Sql("UPDATE \"HouseMembers\" SET \"ChatReadAt\" = CURRENT_TIMESTAMP WHERE \"ChatReadAt\" IS NULL;");

            migrationBuilder.AddColumn<Guid>(
                name: "ChatReadMessageId",
                table: "HouseMembers",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ClientRequestId",
                table: "Chores",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedByUserId",
                table: "Chores",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ScheduleRedistribution",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    SeasonId = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorId = table.Column<Guid>(type: "uuid", nullable: false),
                    TargetUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    ResultJson = table.Column<string>(type: "jsonb", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ScheduleRedistribution", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ScheduleRedistribution_Houses_HouseId",
                        column: x => x.HouseId,
                        principalTable: "Houses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ScheduleRedistribution_Seasons_SeasonId",
                        column: x => x.SeasonId,
                        principalTable: "Seasons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Chores_HouseId_CreatedByUserId_ClientRequestId",
                table: "Chores",
                columns: new[] { "HouseId", "CreatedByUserId", "ClientRequestId" },
                unique: true,
                filter: "\"ClientRequestId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ScheduleRedistribution_HouseId_ActorId_ClientRequestId",
                table: "ScheduleRedistribution",
                columns: new[] { "HouseId", "ActorId", "ClientRequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ScheduleRedistribution_SeasonId",
                table: "ScheduleRedistribution",
                column: "SeasonId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ScheduleRedistribution");

            migrationBuilder.DropIndex(
                name: "IX_Chores_HouseId_CreatedByUserId_ClientRequestId",
                table: "Chores");

            migrationBuilder.DropColumn(
                name: "ChatReadAt",
                table: "HouseMembers");

            migrationBuilder.DropColumn(
                name: "ChatReadMessageId",
                table: "HouseMembers");

            migrationBuilder.DropColumn(
                name: "ClientRequestId",
                table: "Chores");

            migrationBuilder.DropColumn(
                name: "CreatedByUserId",
                table: "Chores");

        }
    }
}
