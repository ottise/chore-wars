using ChoreWars.Domain.Enums;
namespace ChoreWars.Domain.Entities;
public sealed class SupplyOrder {
public SupplyOrderWorkflow Workflow { get; set; }
public string SupplierEmail { get; set; } = "";
public string Note { get; set; } = "";
public Guid? PaymentRecordRequestId { get; set; }
public Guid? PaymentRecordedByUserId { get; set; }
public DateTime? PaymentRecordedAt { get; set; }
public decimal? RecordedPaidAmount { get; set; }
public string? PaymentConfirmationSource { get; set; }
public string? PaymentReference { get; set; }
public SupplyOrderEmailDispatch? EmailDispatch { get; set; }
public List<SupplyOrderActivity> Activities { get; set; } = [];
public Guid Id { get; set; }
public Guid HouseId { get; set; }
public Guid SupplierId { get; set; }
public Guid CreatorUserId { get; set; }
public Guid PayerUserId { get; set; }
public Guid ClientRequestId { get; set; }
public Guid? LastRevisionRequestId { get; set; }
public Guid? ProposalId { get; set; }
public SupplyOrderCreatedVia CreatedVia { get; set; }
public SupplyOrderStatus Status { get; set; }
public int Version { get; set; } = 1;
public string RequestFingerprint { get; set; } = "";
public string DeliveryAddress { get; set; } = "";
public string ContactPhone { get; set; } = "";
public string SupplierName { get; set; } = "";
public string SupplierPhone { get; set; } = "";
public decimal DeliveryFee { get; set; }
public decimal Total { get; set; }
public DateTime CreatedAt { get; set; }
public DateTime QuoteExpiresAt { get; set; }
public DateTime? PaidAt { get; set; }
public bool StockReserved { get; set; }
public decimal RefundedAmount { get; set; }
public List<SupplyOrderLine> Lines { get; set; } = [];
public List<OrderCostShare> Shares { get; set; } = [];
}
