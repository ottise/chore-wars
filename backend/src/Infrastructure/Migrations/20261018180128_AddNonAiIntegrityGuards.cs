using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddNonAiIntegrityGuards : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ChoreBounties_ChoreOccurrenceId",
                table: "ChoreBounties");

            migrationBuilder.AddColumn<int>(
                name: "PenaltyStep",
                table: "KarmaTransactions",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_KarmaTransactions_ReferenceId_PenaltyStep",
                table: "KarmaTransactions",
                columns: new[] { "ReferenceId", "PenaltyStep" },
                unique: true,
                filter: "\"ReferenceId\" IS NOT NULL AND \"PenaltyStep\" IS NOT NULL AND \"Type\" = 'PENALTY'");

            migrationBuilder.CreateIndex(
                name: "IX_KarmaTransactions_ReferenceId_Type",
                table: "KarmaTransactions",
                columns: new[] { "ReferenceId", "Type" },
                unique: true,
                filter: "\"ReferenceId\" IS NOT NULL AND \"Type\" IN ('CHORE_COMPLETED','BONUS')");

            migrationBuilder.CreateIndex(
                name: "IX_Chores_SourceTemplateId",
                table: "Chores",
                column: "SourceTemplateId");

            migrationBuilder.CreateIndex(
                name: "IX_ChoreBounties_ChoreOccurrenceId",
                table: "ChoreBounties",
                column: "ChoreOccurrenceId",
                unique: true,
                filter: "\"Status\" IN ('OPEN','CLAIMED')");

            migrationBuilder.AddForeignKey(
                name: "FK_Chores_Chores_SourceTemplateId",
                table: "Chores",
                column: "SourceTemplateId",
                principalTable: "Chores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Chores_Chores_SourceTemplateId",
                table: "Chores");

            migrationBuilder.DropIndex(
                name: "IX_KarmaTransactions_ReferenceId_PenaltyStep",
                table: "KarmaTransactions");

            migrationBuilder.DropIndex(
                name: "IX_KarmaTransactions_ReferenceId_Type",
                table: "KarmaTransactions");

            migrationBuilder.DropIndex(
                name: "IX_Chores_SourceTemplateId",
                table: "Chores");

            migrationBuilder.DropIndex(
                name: "IX_ChoreBounties_ChoreOccurrenceId",
                table: "ChoreBounties");

            migrationBuilder.DropColumn(
                name: "PenaltyStep",
                table: "KarmaTransactions");

            migrationBuilder.CreateIndex(
                name: "IX_ChoreBounties_ChoreOccurrenceId",
                table: "ChoreBounties",
                column: "ChoreOccurrenceId",
                unique: true);
        }
    }
}
