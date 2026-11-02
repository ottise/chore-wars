using System;
using ChoreWars.Infrastructure.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations;

[DbContext(typeof(AppDbContext))]
[Migration("20261102180000_AddPushDeviceTokens")]
public partial class AddPushDeviceTokens : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "PushDeviceTokens",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                UserId = table.Column<Guid>(type: "uuid", nullable: false),
                Token = table.Column<string>(type: "character varying(4096)", maxLength: 4096, nullable: false),
                Platform = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_PushDeviceTokens", x => x.Id);
                table.ForeignKey(
                    name: "FK_PushDeviceTokens_Users_UserId",
                    column: x => x.UserId,
                    principalTable: "Users",
                    principalColumn: "Id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "IX_PushDeviceTokens_Token",
            table: "PushDeviceTokens",
            column: "Token",
            unique: true);

        migrationBuilder.CreateIndex(
            name: "IX_PushDeviceTokens_UserId",
            table: "PushDeviceTokens",
            column: "UserId");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "PushDeviceTokens");
    }
}
