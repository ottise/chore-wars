using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddHouseholdSupplies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsPurchaseRefund",
                table: "PaymentObligations",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<Guid>(
                name: "SourceOrderId",
                table: "PaymentObligations",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "InternalRepayments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ObligationId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    Reference = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    ReportedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RespondedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResponseReason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InternalRepayments", x => x.Id);
                    table.CheckConstraint("CK_InternalRepayment_Amount", "\"Amount\" > 0");
                    table.ForeignKey(
                        name: "FK_InternalRepayments_PaymentObligations_ObligationId",
                        column: x => x.ObligationId,
                        principalTable: "PaymentObligations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Suppliers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OperatorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Phone = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    Email = table.Column<string>(type: "character varying(254)", maxLength: 254, nullable: false),
                    DeliveryArea = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    DeliveryFee = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    Active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Suppliers", x => x.Id);
                    table.CheckConstraint("CK_Supplier_Fee", "\"DeliveryFee\" >= 0");
                    table.ForeignKey(
                        name: "FK_Suppliers_Users_OperatorUserId",
                        column: x => x.OperatorUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupplySchedules",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    Items = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    DayOfMonth = table.Column<int>(type: "integer", nullable: false),
                    Hour = table.Column<int>(type: "integer", nullable: false),
                    Minute = table.Column<int>(type: "integer", nullable: false),
                    TimeZone = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Enabled = table.Column<bool>(type: "boolean", nullable: false),
                    QuietFromHour = table.Column<int>(type: "integer", nullable: false),
                    QuietToHour = table.Column<int>(type: "integer", nullable: false),
                    NextDueAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    SnoozedUntil = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplySchedules", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupplySchedules_Houses_HouseId",
                        column: x => x.HouseId,
                        principalTable: "Houses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SupplySchedules_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserBankAccounts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    BankName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    AccountNumber = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    AccountName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    Active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserBankAccounts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserBankAccounts_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupplyOrders",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HouseId = table.Column<Guid>(type: "uuid", nullable: false),
                    SupplierId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PayerUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    ProposalId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedVia = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    RequestFingerprint = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    DeliveryAddress = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    ContactPhone = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    SupplierName = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    SupplierPhone = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    DeliveryFee = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    Total = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    QuoteExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PaidAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    StockReserved = table.Column<bool>(type: "boolean", nullable: false),
                    RefundedAmount = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplyOrders", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupplyOrders_ActionProposals_ProposalId",
                        column: x => x.ProposalId,
                        principalTable: "ActionProposals",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SupplyOrders_Houses_HouseId",
                        column: x => x.HouseId,
                        principalTable: "Houses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SupplyOrders_Suppliers_SupplierId",
                        column: x => x.SupplierId,
                        principalTable: "Suppliers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SupplyOrders_Users_CreatorUserId",
                        column: x => x.CreatorUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SupplyOrders_Users_PayerUserId",
                        column: x => x.PayerUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupplyProducts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SupplierId = table.Column<Guid>(type: "uuid", nullable: false),
                    Sku = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    Unit = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Price = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    AvailableQuantity = table.Column<int>(type: "integer", nullable: false),
                    Active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplyProducts", x => x.Id);
                    table.CheckConstraint("CK_SupplyProduct_Price", "\"Price\" > 0");
                    table.CheckConstraint("CK_SupplyProduct_Stock", "\"AvailableQuantity\" >= 0");
                    table.ForeignKey(
                        name: "FK_SupplyProducts_Suppliers_SupplierId",
                        column: x => x.SupplierId,
                        principalTable: "Suppliers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupplyReminderDeliveries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ScheduleId = table.Column<Guid>(type: "uuid", nullable: false),
                    OccurrenceAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplyReminderDeliveries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupplyReminderDeliveries_SupplySchedules_ScheduleId",
                        column: x => x.ScheduleId,
                        principalTable: "SupplySchedules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ObligationAdjustments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ObligationId = table.Column<Guid>(type: "uuid", nullable: false),
                    SourceOrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ObligationAdjustments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ObligationAdjustments_PaymentObligations_ObligationId",
                        column: x => x.ObligationId,
                        principalTable: "PaymentObligations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ObligationAdjustments_SupplyOrders_SourceOrderId",
                        column: x => x.SourceOrderId,
                        principalTable: "SupplyOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "OrderCostShares",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    ApprovedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    RejectedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OrderCostShares", x => x.Id);
                    table.CheckConstraint("CK_OrderCostShare_Amount", "\"Amount\" >= 0");
                    table.ForeignKey(
                        name: "FK_OrderCostShares_SupplyOrders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "SupplyOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_OrderCostShares_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupplierPayments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderCode = table.Column<long>(type: "bigint", nullable: false),
                    PaymentLinkId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    CheckoutUrl = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    QrCode = table.Column<string>(type: "text", nullable: false),
                    Reference = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplierPayments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SupplierPayments_SupplyOrders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "SupplyOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupplierRefunds",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    Reference = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    ReportedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ConfirmedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplierRefunds", x => x.Id);
                    table.CheckConstraint("CK_SupplierRefund_Amount", "\"Amount\" > 0");
                    table.ForeignKey(
                        name: "FK_SupplierRefunds_SupplyOrders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "SupplyOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SupplyOrderLines",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    ProductId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    Unit = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    UnitPrice = table.Column<decimal>(type: "numeric(18,0)", precision: 18, scale: 0, nullable: false),
                    Quantity = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SupplyOrderLines", x => x.Id);
                    table.CheckConstraint("CK_SupplyOrderLine_Quantity", "\"Quantity\" > 0");
                    table.ForeignKey(
                        name: "FK_SupplyOrderLines_SupplyOrders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "SupplyOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SupplyOrderLines_SupplyProducts_ProductId",
                        column: x => x.ProductId,
                        principalTable: "SupplyProducts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PaymentWebhookReceipts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PaymentId = table.Column<Guid>(type: "uuid", nullable: false),
                    Reference = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    ReceivedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PaymentWebhookReceipts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PaymentWebhookReceipts_SupplierPayments_PaymentId",
                        column: x => x.PaymentId,
                        principalTable: "SupplierPayments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PaymentObligations_SourceOrderId_DebtorUserId_CreditorUserI~",
                table: "PaymentObligations",
                columns: new[] { "SourceOrderId", "DebtorUserId", "CreditorUserId", "IsPurchaseRefund" },
                unique: true,
                filter: "\"SourceOrderId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_InternalRepayments_ObligationId_ClientRequestId",
                table: "InternalRepayments",
                columns: new[] { "ObligationId", "ClientRequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ObligationAdjustments_ObligationId",
                table: "ObligationAdjustments",
                column: "ObligationId");

            migrationBuilder.CreateIndex(
                name: "IX_ObligationAdjustments_SourceOrderId",
                table: "ObligationAdjustments",
                column: "SourceOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_OrderCostShares_OrderId_UserId",
                table: "OrderCostShares",
                columns: new[] { "OrderId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_OrderCostShares_UserId",
                table: "OrderCostShares",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentWebhookReceipts_PaymentId",
                table: "PaymentWebhookReceipts",
                column: "PaymentId");

            migrationBuilder.CreateIndex(
                name: "IX_PaymentWebhookReceipts_Reference",
                table: "PaymentWebhookReceipts",
                column: "Reference",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplierPayments_OrderCode",
                table: "SupplierPayments",
                column: "OrderCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplierPayments_OrderId",
                table: "SupplierPayments",
                column: "OrderId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplierRefunds_OrderId_ClientRequestId",
                table: "SupplierRefunds",
                columns: new[] { "OrderId", "ClientRequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Suppliers_OperatorUserId",
                table: "Suppliers",
                column: "OperatorUserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrderLines_OrderId_ProductId",
                table: "SupplyOrderLines",
                columns: new[] { "OrderId", "ProductId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrderLines_ProductId",
                table: "SupplyOrderLines",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrders_CreatorUserId",
                table: "SupplyOrders",
                column: "CreatorUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrders_HouseId_CreatedAt",
                table: "SupplyOrders",
                columns: new[] { "HouseId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrders_HouseId_CreatorUserId_ClientRequestId",
                table: "SupplyOrders",
                columns: new[] { "HouseId", "CreatorUserId", "ClientRequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrders_PayerUserId",
                table: "SupplyOrders",
                column: "PayerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrders_ProposalId",
                table: "SupplyOrders",
                column: "ProposalId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplyOrders_SupplierId",
                table: "SupplyOrders",
                column: "SupplierId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplyProducts_SupplierId_Sku",
                table: "SupplyProducts",
                columns: new[] { "SupplierId", "Sku" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplyReminderDeliveries_ScheduleId_OccurrenceAt",
                table: "SupplyReminderDeliveries",
                columns: new[] { "ScheduleId", "OccurrenceAt" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SupplySchedules_CreatedByUserId",
                table: "SupplySchedules",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_SupplySchedules_Enabled_NextDueAt",
                table: "SupplySchedules",
                columns: new[] { "Enabled", "NextDueAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SupplySchedules_HouseId_ClientRequestId",
                table: "SupplySchedules",
                columns: new[] { "HouseId", "ClientRequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserBankAccounts_UserId",
                table: "UserBankAccounts",
                column: "UserId",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_PaymentObligations_SupplyOrders_SourceOrderId",
                table: "PaymentObligations",
                column: "SourceOrderId",
                principalTable: "SupplyOrders",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PaymentObligations_SupplyOrders_SourceOrderId",
                table: "PaymentObligations");

            migrationBuilder.DropTable(
                name: "InternalRepayments");

            migrationBuilder.DropTable(
                name: "ObligationAdjustments");

            migrationBuilder.DropTable(
                name: "OrderCostShares");

            migrationBuilder.DropTable(
                name: "PaymentWebhookReceipts");

            migrationBuilder.DropTable(
                name: "SupplierRefunds");

            migrationBuilder.DropTable(
                name: "SupplyOrderLines");

            migrationBuilder.DropTable(
                name: "SupplyReminderDeliveries");

            migrationBuilder.DropTable(
                name: "UserBankAccounts");

            migrationBuilder.DropTable(
                name: "SupplierPayments");

            migrationBuilder.DropTable(
                name: "SupplyProducts");

            migrationBuilder.DropTable(
                name: "SupplySchedules");

            migrationBuilder.DropTable(
                name: "SupplyOrders");

            migrationBuilder.DropTable(
                name: "Suppliers");

            migrationBuilder.DropIndex(
                name: "IX_PaymentObligations_SourceOrderId_DebtorUserId_CreditorUserI~",
                table: "PaymentObligations");

            migrationBuilder.DropColumn(
                name: "IsPurchaseRefund",
                table: "PaymentObligations");

            migrationBuilder.DropColumn(
                name: "SourceOrderId",
                table: "PaymentObligations");
        }
    }
}
