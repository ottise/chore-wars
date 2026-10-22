using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddAIEvidenceAndDataOrigin : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AiDataSource",
                table: "Houses",
                type: "character varying(24)",
                maxLength: 24,
                nullable: false,
                defaultValue: "REAL");

            migrationBuilder.CreateTable(
                name: "ChoreEvidence",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    OccurrenceId = table.Column<Guid>(type: "uuid", nullable: false),
                    UploadedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    StorageKey = table.Column<string>(type: "text", nullable: false),
                    ContentType = table.Column<string>(type: "text", nullable: false),
                    ContentHash = table.Column<string>(type: "text", nullable: false),
                    VisionJson = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    AttachedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChoreEvidence", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ChoreEvidence_ChoreOccurrences_OccurrenceId",
                        column: x => x.OccurrenceId,
                        principalTable: "ChoreOccurrences",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "CK_House_AiDataSource",
                table: "Houses",
                sql: "\"AiDataSource\" IN ('REAL','DEMO_SYNTHETIC')");

            migrationBuilder.CreateIndex(
                name: "IX_ChoreEvidence_OccurrenceId_UploadedByUserId_ClientRequestId",
                table: "ChoreEvidence",
                columns: new[] { "OccurrenceId", "UploadedByUserId", "ClientRequestId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ChoreEvidence");

            migrationBuilder.DropCheckConstraint(
                name: "CK_House_AiDataSource",
                table: "Houses");

            migrationBuilder.DropColumn(
                name: "AiDataSource",
                table: "Houses");
        }
    }
}
