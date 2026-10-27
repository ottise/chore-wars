namespace ChoreWars.Domain.Common.Constants;
public static class SupplyConstants {
 public const string OrderTarget = "SUPPLY_ORDER";
 public const string ScheduleTarget = "SUPPLY_SCHEDULE";
 public const string RepaymentTarget = "INTERNAL_REPAYMENT";
 public const int MaxLines = 30;
 public const int MaxQuantity = 1000;
 public const int MaxMembers = 100;
 public const decimal MaxMoney = 1_000_000_000m;
 public const int QuoteMinutes = 60;
 public const int CheckoutMinutes = 15;
 public const string TimeZone = "Asia/Ho_Chi_Minh";
}
