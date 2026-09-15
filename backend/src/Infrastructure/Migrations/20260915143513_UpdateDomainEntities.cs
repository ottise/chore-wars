using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class UpdateDomainEntities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Users_FromUserId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Users_ToUserId",
                table: "PaymentObligations");

            migrationBuilder.RenameColumn(
                name: "ToUserId",
                table: "PaymentObligations",
                newName: "DebtorUserId");

            migrationBuilder.RenameColumn(
                name: "FromUserId",
                table: "PaymentObligations",
                newName: "CreditorUserId");

            migrationBuilder.RenameIndex(
                name: "IX_PaymentObligations_ToUserId",
                table: "PaymentObligations",
                newName: "IX_PaymentObligations_DebtorUserId");

            migrationBuilder.RenameIndex(
                name: "IX_PaymentObligations_FromUserId",
                table: "PaymentObligations",
                newName: "IX_PaymentObligations_CreditorUserId");

            migrationBuilder.AlterColumn<DateTime>(
                name: "RedeemedAt",
                table: "RewardRedemptions",
                type: "timestamp with time zone",
                nullable: true,
                oldClrType: typeof(DateTime),
                oldType: "timestamp with time zone");

            migrationBuilder.AddColumn<DateTime>(
                name: "ClaimDeadline",
                table: "RewardRedemptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "UsageDeadline",
                table: "RewardRedemptions",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "OccurrenceId",
                table: "PaymentObligations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PaidAt",
                table: "PaymentObligations",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "SeasonId",
                table: "PaymentObligations",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsForcedReassigned",
                table: "ChoreOccurrences",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "SnapshotKarma",
                table: "ChoreOccurrences",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "SeasonConfirmations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SeasonId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SeasonConfirmations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SeasonConfirmations_Seasons_SeasonId",
                        column: x => x.SeasonId,
                        principalTable: "Seasons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SeasonConfirmations_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PaymentObligations_OccurrenceId",
                table: "PaymentObligations",
                column: "OccurrenceId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentObligations_SeasonId",
                table: "PaymentObligations",
                column: "SeasonId");

            migrationBuilder.CreateIndex(
                name: "IX_SeasonConfirmations_SeasonId_UserId",
                table: "SeasonConfirmations",
                columns: new[] { "SeasonId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SeasonConfirmations_UserId",
                table: "SeasonConfirmations",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_ChoreOccurrences_OccurrenceId",
                table: "PaymentObligations",
                column: "OccurrenceId",
                principalTable: "ChoreOccurrences",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Seasons_SeasonId",
                table: "PaymentObligations",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Users_CreditorUserId",
                table: "PaymentObligations",
                column: "CreditorUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Users_DebtorUserId",
                table: "PaymentObligations",
                column: "DebtorUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_ChoreOccurrences_OccurrenceId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Seasons_SeasonId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Users_CreditorUserId",
                table: "PaymentObligations");

            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_Users_DebtorUserId",
                table: "PaymentObligations");

            migrationBuilder.DropTable(
                name: "SeasonConfirmations");

            migrationBuilder.DropIndex(
                name: "IX_PaymentObligations_OccurrenceId",
                table: "PaymentObligations");

            migrationBuilder.DropIndex(
                name: "IX_PaymentObligations_SeasonId",
                table: "PaymentObligations");

            migrationBuilder.DropColumn(
                name: "ClaimDeadline",
                table: "RewardRedemptions");

            migrationBuilder.DropColumn(
                name: "UsageDeadline",
                table: "RewardRedemptions");

            migrationBuilder.DropColumn(
                name: "OccurrenceId",
                table: "PaymentObligations");

            migrationBuilder.DropColumn(
                name: "PaidAt",
                table: "PaymentObligations");

            migrationBuilder.DropColumn(
                name: "SeasonId",
                table: "PaymentObligations");

            migrationBuilder.DropColumn(
                name: "IsForcedReassigned",
                table: "ChoreOccurrences");

            migrationBuilder.DropColumn(
                name: "SnapshotKarma",
                table: "ChoreOccurrences");

            migrationBuilder.RenameColumn(
                name: "DebtorUserId",
                table: "PaymentObligations",
                newName: "ToUserId");

            migrationBuilder.RenameColumn(
                name: "CreditorUserId",
                table: "PaymentObligations",
                newName: "FromUserId");

            migrationBuilder.RenameIndex(
                name: "IX_PaymentObligations_DebtorUserId",
                table: "PaymentObligations",
                newName: "IX_PaymentObligations_ToUserId");

            migrationBuilder.RenameIndex(
                name: "IX_PaymentObligations_CreditorUserId",
                table: "PaymentObligations",
                newName: "IX_PaymentObligations_FromUserId");

            migrationBuilder.AlterColumn<DateTime>(
                name: "RedeemedAt",
                table: "RewardRedemptions",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified),
                oldClrType: typeof(DateTime),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Users_FromUserId",
                table: "PaymentObligations",
                column: "FromUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_Users_ToUserId",
                table: "PaymentObligations",
                column: "ToUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
