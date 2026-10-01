using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddAiAllocationEntities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Difficulty",
                table: "Chores",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "EstimatedMinutes",
                table: "Chores",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "MemberConstraints",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    HouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    MaxChoresPerWeek = table.Column<int>(type: "integer", nullable: false),
                    MaxEffortMinutesPerDay = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MemberConstraints", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MemberConstraints_Houses_HouseId",
                        column: x => x.HouseId,
                        principalTable: "Houses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MemberConstraints_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "MemberPreferences",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ChoreId = table.Column<Guid>(type: "uuid", nullable: false),
                    Type = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MemberPreferences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MemberPreferences_Chores_ChoreId",
                        column: x => x.ChoreId,
                        principalTable: "Chores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MemberPreferences_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_MemberConstraints_HouseId_UserId",
                table: "MemberConstraints",
                columns: new[] { "HouseId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MemberConstraints_UserId",
                table: "MemberConstraints",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_MemberPreferences_ChoreId",
                table: "MemberPreferences",
                column: "ChoreId");

            migrationBuilder.CreateIndex(
                name: "IX_MemberPreferences_UserId_ChoreId",
                table: "MemberPreferences",
                columns: new[] { "UserId", "ChoreId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MemberConstraints");

            migrationBuilder.DropTable(
                name: "MemberPreferences");

            migrationBuilder.DropColumn(
                name: "Difficulty",
                table: "Chores");

            migrationBuilder.DropColumn(
                name: "EstimatedMinutes",
                table: "Chores");
        }
    }
}
