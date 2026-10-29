using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddRepaymentReceiptProvenance : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "RecordedByUserId",
                table: "InternalRepayments",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Source",
                table: "InternalRepayments",
                type: "character varying(30)",
                maxLength: 30,
                nullable: false,
                defaultValue: "DEBTOR_REPORTED");

            migrationBuilder.CreateIndex(
                name: "IX_InternalRepayments_RecordedByUserId",
                table: "InternalRepayments",
                column: "RecordedByUserId");

            migrationBuilder.Sql("""
                UPDATE "InternalRepayments" AS r
                SET "RecordedByUserId" = p."DebtorUserId"
                FROM "PaymentObligations" AS p
                WHERE r."ObligationId" = p."Id" AND r."RecordedByUserId" IS NULL;
                """);

            migrationBuilder.AddForeignKey(
                name: "FK_InternalRepayments_Users_RecordedByUserId",
                table: "InternalRepayments",
                column: "RecordedByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_InternalRepayments_Users_RecordedByUserId",
                table: "InternalRepayments");

            migrationBuilder.DropIndex(
                name: "IX_InternalRepayments_RecordedByUserId",
                table: "InternalRepayments");

            migrationBuilder.DropColumn(
                name: "RecordedByUserId",
                table: "InternalRepayments");

            migrationBuilder.DropColumn(
                name: "Source",
                table: "InternalRepayments");
        }
    }
}
