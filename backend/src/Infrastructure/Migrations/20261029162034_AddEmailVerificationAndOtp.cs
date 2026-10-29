using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddEmailVerificationAndOtp : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "EmailVerifiedAt",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            // Grandfather only accounts that exist at migration time. Future registrations stay unverified.
            migrationBuilder.Sql("UPDATE \"Users\" SET \"EmailVerifiedAt\" = CURRENT_TIMESTAMP WHERE \"EmailVerifiedAt\" IS NULL;");

            migrationBuilder.CreateTable(
                name: "EmailOtpChallenges",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Purpose = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    CodeHash = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ConsumedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    FailedAttempts = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EmailOtpChallenges", x => x.Id);
                    table.ForeignKey(
                        name: "FK_EmailOtpChallenges_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EmailOtpChallenges_UserId_Purpose_CreatedAt",
                table: "EmailOtpChallenges",
                columns: new[] { "UserId", "Purpose", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "EmailOtpChallenges");

            migrationBuilder.DropColumn(
                name: "EmailVerifiedAt",
                table: "Users");
        }
    }
}
