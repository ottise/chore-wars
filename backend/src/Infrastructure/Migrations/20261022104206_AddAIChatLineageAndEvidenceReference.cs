using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddAIChatLineageAndEvidenceReference : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "EvidenceId",
                table: "ChoreOccurrences",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AIChatInsights",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    MessageId = table.Column<Guid>(type: "uuid", nullable: false),
                    ConsentVersion = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    ResultJson = table.Column<string>(type: "jsonb", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ProcessedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Attempts = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AIChatInsights", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AIChatInsights_ChatMessages_MessageId",
                        column: x => x.MessageId,
                        principalTable: "ChatMessages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_AIChatInsights_Houses_HouseId",
                        column: x => x.HouseId,
                        principalTable: "Houses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ChoreOccurrences_EvidenceId",
                table: "ChoreOccurrences",
                column: "EvidenceId");

            migrationBuilder.CreateIndex(
                name: "IX_AIChatInsights_HouseId",
                table: "AIChatInsights",
                column: "HouseId");

            migrationBuilder.CreateIndex(
                name: "IX_AIChatInsights_MessageId",
                table: "AIChatInsights",
                column: "MessageId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AIChatInsights_Status_CreatedAt",
                table: "AIChatInsights",
                columns: new[] { "Status", "CreatedAt" });

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_ChoreEvidence_EvidenceId",
                table: "ChoreOccurrences",
                column: "EvidenceId",
                principalTable: "ChoreEvidence",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_ChoreEvidence_EvidenceId",
                table: "ChoreOccurrences");

            migrationBuilder.DropTable(
                name: "AIChatInsights");

            migrationBuilder.DropIndex(
                name: "IX_ChoreOccurrences_EvidenceId",
                table: "ChoreOccurrences");

            migrationBuilder.DropColumn(
                name: "EvidenceId",
                table: "ChoreOccurrences");
        }
    }
}
