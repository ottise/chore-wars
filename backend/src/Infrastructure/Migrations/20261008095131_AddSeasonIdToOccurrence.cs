using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddSeasonIdToOccurrence : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Chores_Seasons_SeasonId",
                table: "Chores");

            migrationBuilder.AlterColumn<Guid>(
                name: "SeasonId",
                table: "Chores",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            // Add the column as nullable first so existing occurrences can be
            // linked to the same season as their chore before enforcing the FK.
            migrationBuilder.AddColumn<Guid>(
                name: "SeasonId",
                table: "ChoreOccurrences",
                type: "uuid",
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE "ChoreOccurrences" AS occurrence
                SET "SeasonId" = chore."SeasonId"
                FROM "Chores" AS chore
                WHERE occurrence."ChoreId" = chore."Id";
                """);

            migrationBuilder.AlterColumn<Guid>(
                name: "SeasonId",
                table: "ChoreOccurrences",
                type: "uuid",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ChoreOccurrences_SeasonId",
                table: "ChoreOccurrences",
                column: "SeasonId");

            migrationBuilder.AddForeignKey(
                name: "FK_ChoreOccurrences_Seasons_SeasonId",
                table: "ChoreOccurrences",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Chores_Seasons_SeasonId",
                table: "Chores",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ChoreOccurrences_Seasons_SeasonId",
                table: "ChoreOccurrences");

            migrationBuilder.DropForeignKey(
                name: "FK_Chores_Seasons_SeasonId",
                table: "Chores");

            migrationBuilder.DropIndex(
                name: "IX_ChoreOccurrences_SeasonId",
                table: "ChoreOccurrences");

            migrationBuilder.DropColumn(
                name: "SeasonId",
                table: "ChoreOccurrences");

            migrationBuilder.AlterColumn<Guid>(
                name: "SeasonId",
                table: "Chores",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Chores_Seasons_SeasonId",
                table: "Chores",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
