using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class CompleteNonAiCore : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_Chores_ChoreId",
                table: "ChoreOccurrences");

            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_Seasons_SeasonId",
                table: "ChoreOccurrences");

            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_Users_AssignedUserId",
                table: "ChoreOccurrences");

            migrationBuilder.DropForeignKey(
                name: "FK_KarmaTransactions_Houses_HouseId",
                table: "KarmaTransactions");

            migrationBuilder.DropForeignKey(
                name: "FK_KarmaTransactions_Seasons_SeasonId",
                table: "KarmaTransactions");

            migrationBuilder.DropForeignKey(
                name: "FK_KarmaTransactions_Users_UserId",
                table: "KarmaTransactions");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_ChoreOccurrences_OccurrenceId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Houses_HouseId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Seasons_SeasonId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_RewardRedemptions_Rewards_RewardId",
                table: "RewardRedemptions");

            migrationBuilder.DropForeignKey(
                name: "FK_RewardRedemptions_Users_UserId",
                table: "RewardRedemptions");

            migrationBuilder.DropForeignKey(
                name: "FK_SeasonRankings_Users_UserId",
                table: "SeasonRankings");

            migrationBuilder.DropIndex(
                name: "IX_UserAchievements_UserId",
                table: "UserAchievements");

            migrationBuilder.DropIndex(
                name: "IX_RewardRedemptions_RewardId",
                table: "RewardRedemptions");

            migrationBuilder.DropIndex(
                name: "IX_PaymentObligations_OccurrenceId",
                table: "PaymentObligations");

            migrationBuilder.AddColumn<DateTime>(
                name: "FinalizedAt",
                table: "Seasons",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "LastRejectedByUserId",
                table: "Seasons",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LastRejectionReason",
                table: "Seasons",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ScheduleRevision",
                table: "Seasons",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "ScheduleRevision",
                table: "SeasonConfirmations",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AlterColumn<Guid>(
                name: "SeasonId",
                table: "Rewards",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<int>(
                name: "Cost",
                table: "Rewards",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "Enabled",
                table: "Rewards",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ClientRequestId",
                table: "RewardRedemptions",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "CostSnapshot",
                table: "RewardRedemptions",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<Guid>(
                name: "ConfirmedByUserId",
                table: "PaymentObligations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "SeasonId",
                table: "KarmaTransactions",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<int>(
                name: "InviteVersion",
                table: "Houses",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "IsArchived",
                table: "Houses",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<List<DateOnly>>(
                name: "CustomDates",
                table: "Chores",
                type: "date[]",
                nullable: false,
                defaultValueSql: "'{}'::date[]");

            migrationBuilder.AddColumn<int>(
                name: "DeadlineMinutes",
                table: "Chores",
                type: "integer",
                nullable: false,
                defaultValue: 1439);

            migrationBuilder.AddColumn<DateOnly>(
                name: "RecurrenceAnchor",
                table: "Chores",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "SourceTemplateId",
                table: "Chores",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CompletedByUserId",
                table: "ChoreOccurrences",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PlannedStartAt",
                table: "ChoreOccurrences",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SnapshotDifficulty",
                table: "ChoreOccurrences",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "SnapshotMinutes",
                table: "ChoreOccurrences",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<Guid>(
                name: "AttachmentId",
                table: "ChatMessages",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ClientMessageId",
                table: "ChatMessages",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "MessageType",
                table: "ChatMessages",
                type: "text",
                nullable: false,
                defaultValue: "TEXT");

            migrationBuilder.CreateTable(
                name: "ChoreResponsibility",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OccurrenceId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Reason = table.Column<string>(type: "text", nullable: false),
                    StartedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Deadline = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    EndedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    PenaltiesApplied = table.Column<int>(type: "integer", nullable: false),
                    CompletedByUserId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChoreResponsibility", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ChoreResponsibility_ChoreOccurrences_OccurrenceId",
                        column: x => x.OccurrenceId,
                        principalTable: "ChoreOccurrences",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MediaAttachments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RoomId = table.Column<Guid>(type: "uuid", nullable: false),
                    OwnerId = table.Column<Guid>(type: "uuid", nullable: false),
                    StorageKey = table.Column<string>(type: "text", nullable: false),
                    ContentType = table.Column<string>(type: "text", nullable: false),
                    Type = table.Column<string>(type: "text", nullable: false),
                    Size = table.Column<long>(type: "bigint", nullable: false),
                    DurationSeconds = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    AttachedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MediaAttachments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MediaAttachments_ChatRooms_RoomId",
                        column: x => x.RoomId,
                        principalTable: "ChatRooms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MemberAvailabilitySlot",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    MemberAvailabilityId = table.Column<Guid>(type: "uuid", nullable: false),
                    StartMinute = table.Column<int>(type: "integer", nullable: false),
                    EndMinute = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MemberAvailabilitySlot", x => x.Id);
                    table.CheckConstraint("CK_AvailabilitySlot_Interval", "\"StartMinute\" >= 0 AND \"EndMinute\" <= 1440 AND \"StartMinute\" < \"EndMinute\"");
                    table.ForeignKey(
                        name: "FK_MemberAvailabilitySlot_MemberAvailabilities_MemberAvailabil~",
                        column: x => x.MemberAvailabilityId,
                        principalTable: "MemberAvailabilities",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "OutboxMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Topic = table.Column<string>(type: "text", nullable: false),
                    Payload = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PublishedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OutboxMessages", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ProcessedMessages",
                columns: table => new
                {
                    Id = table.Column<string>(type: "text", nullable: false),
                    Consumer = table.Column<string>(type: "text", nullable: false),
                    ProcessedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProcessedMessages", x => new { x.Consumer, x.Id });
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserAchievements_UserId_AchievementId",
                table: "UserAchievements",
                columns: new[] { "UserId", "AchievementId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RewardRedemptions_RewardId_UserId_ClientRequestId",
                table: "RewardRedemptions",
                columns: new[] { "RewardId", "UserId", "ClientRequestId" },
                unique: true,
                filter: "\"ClientRequestId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentObligations_OccurrenceId",
                table: "PaymentObligations",
                column: "OccurrenceId",
                unique: true,
                filter: "\"Reason\" = 'FORCED_REASSIGNMENT' AND \"OccurrenceId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_AttachmentId",
                table: "ChatMessages",
                column: "AttachmentId");

            migrationBuilder.CreateIndex(
                name: "IX_ChatMessages_RoomId_SenderId_ClientMessageId",
                table: "ChatMessages",
                columns: new[] { "RoomId", "SenderId", "ClientMessageId" },
                unique: true,
                filter: "\"ClientMessageId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ChoreResponsibility_OccurrenceId",
                table: "ChoreResponsibility",
                column: "OccurrenceId",
                unique: true,
                filter: "\"EndedAt\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_MediaAttachments_RoomId",
                table: "MediaAttachments",
                column: "RoomId");

            migrationBuilder.CreateIndex(
                name: "IX_MemberAvailabilitySlot_MemberAvailabilityId",
                table: "MemberAvailabilitySlot",
                column: "MemberAvailabilityId");

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_PublishedAt_CreatedAt",
                table: "OutboxMessages",
                columns: new[] { "PublishedAt", "CreatedAt" });

            migrationBuilder.AddForeignKey(
                name: "FK_ChatMessages_MediaAttachments_AttachmentId",
                table: "ChatMessages",
                column: "AttachmentId",
                principalTable: "MediaAttachments",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_Chores_ChoreId",
                table: "ChoreOccurrences",
                column: "ChoreId",
                principalTable: "Chores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_Seasons_SeasonId",
                table: "ChoreOccurrences",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_Users_AssignedUserId",
                table: "ChoreOccurrences",
                column: "AssignedUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_KarmaTransactions_Houses_HouseId",
                table: "KarmaTransactions",
                column: "HouseId",
                principalTable: "Houses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_KarmaTransactions_Seasons_SeasonId",
                table: "KarmaTransactions",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_KarmaTransactions_Users_UserId",
                table: "KarmaTransactions",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_ChoreOccurrences_OccurrenceId",
                table: "PaymentObligations",
                column: "OccurrenceId",
                principalTable: "ChoreOccurrences",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Houses_HouseId",
                table: "PaymentObligations",
                column: "HouseId",
                principalTable: "Houses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Seasons_SeasonId",
                table: "PaymentObligations",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_RewardRedemptions_Rewards_RewardId",
                table: "RewardRedemptions",
                column: "RewardId",
                principalTable: "Rewards",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_RewardRedemptions_Users_UserId",
                table: "RewardRedemptions",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_SeasonRankings_Users_UserId",
                table: "SeasonRankings",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ChatMessages_MediaAttachments_AttachmentId",
                table: "ChatMessages");

            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_Chores_ChoreId",
                table: "ChoreOccurrences");

            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_Seasons_SeasonId",
                table: "ChoreOccurrences");

            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_Users_AssignedUserId",
                table: "ChoreOccurrences");

            migrationBuilder.DropForeignKey(
                name: "FK_KarmaTransactions_Houses_HouseId",
                table: "KarmaTransactions");

            migrationBuilder.DropForeignKey(
                name: "FK_KarmaTransactions_Seasons_SeasonId",
                table: "KarmaTransactions");

            migrationBuilder.DropForeignKey(
                name: "FK_KarmaTransactions_Users_UserId",
                table: "KarmaTransactions");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_ChoreOccurrences_OccurrenceId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Houses_HouseId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Seasons_SeasonId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_RewardRedemptions_Rewards_RewardId",
                table: "RewardRedemptions");

            migrationBuilder.DropForeignKey(
                name: "FK_RewardRedemptions_Users_UserId",
                table: "RewardRedemptions");

            migrationBuilder.DropForeignKey(
                name: "FK_SeasonRankings_Users_UserId",
                table: "SeasonRankings");

            migrationBuilder.DropTable(
                name: "ChoreResponsibility");

            migrationBuilder.DropTable(
                name: "MediaAttachments");

            migrationBuilder.DropTable(
                name: "MemberAvailabilitySlot");

            migrationBuilder.DropTable(
                name: "OutboxMessages");

            migrationBuilder.DropTable(
                name: "ProcessedMessages");

            migrationBuilder.DropIndex(
                name: "IX_UserAchievements_UserId_AchievementId",
                table: "UserAchievements");

            migrationBuilder.DropIndex(
                name: "IX_RewardRedemptions_RewardId_UserId_ClientRequestId",
                table: "RewardRedemptions");

            migrationBuilder.DropIndex(
                name: "IX_PaymentObligations_OccurrenceId",
                table: "PaymentObligations");

            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_AttachmentId",
                table: "ChatMessages");

            migrationBuilder.DropIndex(
                name: "IX_ChatMessages_RoomId_SenderId_ClientMessageId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "FinalizedAt",
                table: "Seasons");

            migrationBuilder.DropColumn(
                name: "LastRejectedByUserId",
                table: "Seasons");

            migrationBuilder.DropColumn(
                name: "LastRejectionReason",
                table: "Seasons");

            migrationBuilder.DropColumn(
                name: "ScheduleRevision",
                table: "Seasons");

            migrationBuilder.DropColumn(
                name: "ScheduleRevision",
                table: "SeasonConfirmations");

            migrationBuilder.DropColumn(
                name: "Cost",
                table: "Rewards");

            migrationBuilder.DropColumn(
                name: "Enabled",
                table: "Rewards");

            migrationBuilder.DropColumn(
                name: "ClientRequestId",
                table: "RewardRedemptions");

            migrationBuilder.DropColumn(
                name: "CostSnapshot",
                table: "RewardRedemptions");

            migrationBuilder.DropColumn(
                name: "ConfirmedByUserId",
                table: "PaymentObligations");

            migrationBuilder.DropColumn(
                name: "InviteVersion",
                table: "Houses");

            migrationBuilder.DropColumn(
                name: "IsArchived",
                table: "Houses");

            migrationBuilder.DropColumn(
                name: "CustomDates",
                table: "Chores");

            migrationBuilder.DropColumn(
                name: "DeadlineMinutes",
                table: "Chores");

            migrationBuilder.DropColumn(
                name: "RecurrenceAnchor",
                table: "Chores");

            migrationBuilder.DropColumn(
                name: "SourceTemplateId",
                table: "Chores");

            migrationBuilder.DropColumn(
                name: "CompletedByUserId",
                table: "ChoreOccurrences");

            migrationBuilder.DropColumn(
                name: "PlannedStartAt",
                table: "ChoreOccurrences");

            migrationBuilder.DropColumn(
                name: "SnapshotDifficulty",
                table: "ChoreOccurrences");

            migrationBuilder.DropColumn(
                name: "SnapshotMinutes",
                table: "ChoreOccurrences");

            migrationBuilder.DropColumn(
                name: "AttachmentId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "ClientMessageId",
                table: "ChatMessages");

            migrationBuilder.DropColumn(
                name: "MessageType",
                table: "ChatMessages");

            migrationBuilder.AlterColumn<Guid>(
                name: "SeasonId",
                table: "Rewards",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "SeasonId",
                table: "KarmaTransactions",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserAchievements_UserId",
                table: "UserAchievements",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_RewardRedemptions_RewardId",
                table: "RewardRedemptions",
                column: "RewardId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentObligations_OccurrenceId",
                table: "PaymentObligations",
                column: "OccurrenceId");

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_Chores_ChoreId",
                table: "ChoreOccurrences",
                column: "ChoreId",
                principalTable: "Chores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_Seasons_SeasonId",
                table: "ChoreOccurrences",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_Users_AssignedUserId",
                table: "ChoreOccurrences",
                column: "AssignedUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_KarmaTransactions_Houses_HouseId",
                table: "KarmaTransactions",
                column: "HouseId",
                principalTable: "Houses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_KarmaTransactions_Seasons_SeasonId",
                table: "KarmaTransactions",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_KarmaTransactions_Users_UserId",
                table: "KarmaTransactions",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_ChoreOccurrences_OccurrenceId",
                table: "PaymentObligations",
                column: "OccurrenceId",
                principalTable: "ChoreOccurrences",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Houses_HouseId",
                table: "PaymentObligations",
                column: "HouseId",
                principalTable: "Houses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Seasons_SeasonId",
                table: "PaymentObligations",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_RewardRedemptions_Rewards_RewardId",
                table: "RewardRedemptions",
                column: "RewardId",
                principalTable: "Rewards",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_RewardRedemptions_Users_UserId",
                table: "RewardRedemptions",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_SeasonRankings_Users_UserId",
                table: "SeasonRankings",
                column: "UserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
