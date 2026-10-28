using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddSimpleOrderEmailAndPaymentLog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Note",
                table: "SupplyOrders",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "PaymentConfirmationSource",
                table: "SupplyOrders",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "PaymentRecordRequestId",
                table: "SupplyOrders",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PaymentRecordedAt",
                table: "SupplyOrders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "PaymentRecordedByUserId",
                table: "SupplyOrders",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentReference",
                table: "SupplyOrders",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RecordedPaidAmount",
                table: "SupplyOrders",
                type: "numeric(18,0)",
                precision: 18,
                scale: 0,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SupplierEmail",
                table: "SupplyOrders",
                type: "character varying(320)",
                maxLength: 320,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Workflow",
                table: "SupplyOrders",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "LEGACY_SHARED");

            migrationBuilder.CreateTable(
                name: "SupplyOrderActivities",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    Kind = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    RecordedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: true),
                    Reference = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplyOrderActivities", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupplyOrderActivities_SupplyOrders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "SupplyOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "SupplyOrderEmailDispatches",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    Recipient = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    Subject = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Body = table.Column<string>(type: "text", nullable: false),
                    State = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Attempts = table.Column<int>(type: "integer", nullable: false),
                    LeaseId = table.Column<Guid>(type: "uuid", nullable: true),
                    LeaseUntil = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    SentAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ErrorCode = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplyOrderEmailDispatches", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupplyOrderEmailDispatches_SupplyOrders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "SupplyOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrderActivities_OrderId_RecordedAt",
                table: "SupplyOrderActivities",
                columns: new[] { "OrderId", "RecordedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrderEmailDispatches_OrderId",
                table: "SupplyOrderEmailDispatches",
                column: "OrderId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrderEmailDispatches_State_CreatedAt",
                table: "SupplyOrderEmailDispatches",
                columns: new[] { "State", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SupplyOrderActivities");

            migrationBuilder.DropTable(
                name: "SupplyOrderEmailDispatches");

            migrationBuilder.DropColumn(
                name: "Note",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "PaymentConfirmationSource",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "PaymentRecordRequestId",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "PaymentRecordedAt",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "PaymentRecordedByUserId",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "PaymentReference",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "RecordedPaidAmount",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "SupplierEmail",
                table: "SupplyOrders");

            migrationBuilder.DropColumn(
                name: "Workflow",
                table: "SupplyOrders");
        }
    }
}
