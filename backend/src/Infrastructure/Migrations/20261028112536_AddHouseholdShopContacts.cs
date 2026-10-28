using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddHouseholdShopContacts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<Guid>(
                name: "OperatorUserId",
                table: "Suppliers",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "HouseId",
                table: "Suppliers",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Suppliers_HouseId",
                table: "Suppliers",
                column: "HouseId");

            migrationBuilder.AddForeignKey(
                name: "FK_Suppliers_Houses_HouseId",
                table: "Suppliers",
                column: "HouseId",
                principalTable: "Houses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Suppliers_Houses_HouseId",
                table: "Suppliers");

            migrationBuilder.DropIndex(
                name: "IX_Suppliers_HouseId",
                table: "Suppliers");

            migrationBuilder.DropColumn(
                name: "HouseId",
                table: "Suppliers");

            migrationBuilder.AlterColumn<Guid>(
                name: "OperatorUserId",
                table: "Suppliers",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);
        }
    }
}
