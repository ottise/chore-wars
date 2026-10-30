# Phụ lục API cho bộ test hai người

Đối chiếu source main `6247d59`, ngày 30/10/2026. Danh sách được trích từ route attributes của controller,
không thay Swagger/runtime routing. Alias `api/v1` được liệt kê nếu controller khai báo.
Mỗi nhóm phải ghi request đã chạy vào phiếu test; có ánh xạ không đồng nghĩa endpoint đã Pass.

[Kịch bản A/B](two-tester-full-system-2026-10-30.vi.md) · [Phiếu chạy](two-tester-run-sheet-2026-10-30.vi.md)

## Phạm vi

36 controller backend, HTTP media và SignalR ChatHub. API Python AI nội bộ dùng credential backend: kiểm tra qua các ca AI/OPS và contract test, không đưa service key cho client A/B.

| Controller | Ca cần đối chiếu |
|---|---|
| [ActionProposalController](../../backend/src/Presentation/Controllers/ActionProposalController.cs) | AI-11, SECURITY-02 |
| [AIHousekeeperController](../../backend/src/Presentation/Controllers/AIHousekeeperController.cs) | AI-01…22, PREF-08, SECURITY-02 |
| [AuthController](../../backend/src/Presentation/Controllers/AuthController.cs) | AUTH-01…19 |
| [BountyController](../../backend/src/Presentation/Controllers/BountyController.cs) | BOUNTY-01…18, DEBT-01…14 |
| [ChatController](../../backend/src/Presentation/Controllers/ChatController.cs) | CHAT-01…14 |
| [ChoreClaimController](../../backend/src/Presentation/Controllers/ChoreClaimController.cs) | EXEC-07, EXEC-10 |
| [ChoreController](../../backend/src/Presentation/Controllers/ChoreController.cs) | CHORE-01…18, EXEC-01…14 |
| [ChoreEvidenceController](../../backend/src/Presentation/Controllers/ChoreEvidenceController.cs) | EXEC-08…09, AI-17 |
| [ChoreRoutineController](../../backend/src/Presentation/Controllers/ChoreRoutineController.cs) | CHORE-15…17 |
| [DeploymentHealthController](../../backend/src/Presentation/Controllers/DeploymentHealthController.cs) | ENV-01, OPS-01…08 |
| [EmailOtpController](../../backend/src/Presentation/Controllers/EmailOtpController.cs) | AUTH-01…12, OPS-07 |
| [FailedEventController](../../backend/src/Presentation/Controllers/FailedEventController.cs) | OPS-04, SECURITY-02 |
| [GamificationController](../../backend/src/Presentation/Controllers/GamificationController.cs) | REWARD-01…06 |
| [HouseAdministrationController](../../backend/src/Presentation/Controllers/HouseAdministrationController.cs) | HOUSE-03…17 |
| [HouseCalendarController](../../backend/src/Presentation/Controllers/HouseCalendarController.cs) | SUMMARY-01, SUMMARY-07 |
| [HouseController](../../backend/src/Presentation/Controllers/HouseController.cs) | HOUSE-01…17, PREF-01…08, JOIN-01…12 |
| [HouseholdResolutionController](../../backend/src/Presentation/Controllers/HouseholdResolutionController.cs) | EXEC-13 |
| [HouseholdSummaryController](../../backend/src/Presentation/Controllers/HouseholdSummaryController.cs) | SUMMARY-02…10 |
| [HouseMemberReadController](../../backend/src/Presentation/Controllers/HouseMemberReadController.cs) | ACCOUNT-02…05, SUMMARY-05…09 |
| [InternalRepaymentsController](../../backend/src/Presentation/Controllers/InternalRepaymentsController.cs) | DEBT-01…14 |
| [MediaController](../../backend/src/Presentation/Controllers/MediaController.cs) | CHAT-10…14, VOICE-01…08, OPS-05…08 |
| [NotificationController](../../backend/src/Presentation/Controllers/NotificationController.cs) | NOTI-01…06 |
| [PersonalFinanceController](../../backend/src/Presentation/Controllers/PersonalFinanceController.cs) | DEBT-01…14, SUMMARY-03 |
| [RewardController](../../backend/src/Presentation/Controllers/RewardController.cs) | REWARD-07…09 |
| [SeasonController](../../backend/src/Presentation/Controllers/SeasonController.cs) | SEASON-01…15, JOIN-01…12, REWARD-02 |
| [SimpleSupplyOrdersController](../../backend/src/Presentation/Controllers/SimpleSupplyOrdersController.cs) | SHOP-08…15 |
| [SupplierCatalogController](../../backend/src/Presentation/Controllers/SupplierCatalogController.cs) | SHOP-01…06, SUPPLIER-01…02 |
| [SupplierOrdersController](../../backend/src/Presentation/Controllers/SupplierOrdersController.cs) | SUPPLIER-09 |
| [SupplierPaymentsController](../../backend/src/Presentation/Controllers/SupplierPaymentsController.cs) | SUPPLIER-06…08 |
| [SupplyDisputesController](../../backend/src/Presentation/Controllers/SupplyDisputesController.cs) | SUPPLIER-11 |
| [SupplyOrdersController](../../backend/src/Presentation/Controllers/SupplyOrdersController.cs) | SUPPLIER-03…09 |
| [SupplyRefundsController](../../backend/src/Presentation/Controllers/SupplyRefundsController.cs) | SUPPLIER-10 |
| [SupplySchedulesController](../../backend/src/Presentation/Controllers/SupplySchedulesController.cs) | SUPPLIER-12 |
| [UnresolvedChoreController](../../backend/src/Presentation/Controllers/UnresolvedChoreController.cs) | EXEC-11…13 |
| [UserBankAccountsController](../../backend/src/Presentation/Controllers/UserBankAccountsController.cs) | DEBT-09, SECURITY-02 |
| [UserController](../../backend/src/Presentation/Controllers/UserController.cs) | ACCOUNT-01…07 |

## Routes theo source

Public endpoint như login/register/OTP, invitation preview theo cấu hình và health phải được xét đúng chính sách riêng; không áp dụng máy móc yêu cầu JWT của endpoint bảo vệ. Webhook ngân hàng phải kiểm tra chữ ký thay vì token member.

### ActionProposalController

Ca: AI-11, SECURITY-02.

| Method | Route |
|---|---|
| POST | `/api/houses/{houseId:guid}/proposals` |
| POST | `/api/v1/houses/{houseId:guid}/proposals` |
| POST | `/api/proposals/{proposalId:guid}/respond` |
| POST | `/api/v1/proposals/{proposalId:guid}/respond` |
| GET | `/api/rooms/{roomId:guid}/proposals/active` |
| GET | `/api/v1/rooms/{roomId:guid}/proposals/active` |

### AIHousekeeperController

Ca: AI-01…22, PREF-08, SECURITY-02.

| Method | Route |
|---|---|
| POST | `/api/houses/{houseId:guid}/ai/observations` |
| POST | `/api/v1/houses/{houseId:guid}/ai/observations` |
| GET | `/api/houses/{houseId:guid}/ai/profiles` |
| GET | `/api/v1/houses/{houseId:guid}/ai/profiles` |
| GET | `/api/houses/{houseId:guid}/ai/evidence/{id:guid}` |
| GET | `/api/v1/houses/{houseId:guid}/ai/evidence/{id:guid}` |
| GET | `/api/houses/{houseId:guid}/ai/contributions` |
| GET | `/api/v1/houses/{houseId:guid}/ai/contributions` |
| GET | `/api/houses/{houseId:guid}/ai/learning-report` |
| GET | `/api/v1/houses/{houseId:guid}/ai/learning-report` |
| GET | `/api/houses/{houseId:guid}/ai/models/status` |
| GET | `/api/v1/houses/{houseId:guid}/ai/models/status` |
| GET | `/api/houses/{houseId:guid}/ai/learning/timeline` |
| GET | `/api/v1/houses/{houseId:guid}/ai/learning/timeline` |
| GET | `/api/houses/{houseId:guid}/ai/learning/training-runs/{id:guid}` |
| GET | `/api/v1/houses/{houseId:guid}/ai/learning/training-runs/{id:guid}` |
| GET | `/api/houses/{houseId:guid}/ai/learning/training-runs` |
| GET | `/api/v1/houses/{houseId:guid}/ai/learning/training-runs` |
| GET | `/api/houses/{houseId:guid}/ai/chat/insights` |
| GET | `/api/v1/houses/{houseId:guid}/ai/chat/insights` |
| GET | `/api/houses/{houseId:guid}/ai/failures` |
| GET | `/api/v1/houses/{houseId:guid}/ai/failures` |
| POST | `/api/houses/{houseId:guid}/ai/evaluations/seasons/{seasonId:guid}` |
| POST | `/api/v1/houses/{houseId:guid}/ai/evaluations/seasons/{seasonId:guid}` |
| GET | `/api/houses/{houseId:guid}/ai/bounties/suggestions` |
| GET | `/api/v1/houses/{houseId:guid}/ai/bounties/suggestions` |
| GET | `/api/houses/{houseId:guid}/ai/me/risk-insights` |
| GET | `/api/v1/houses/{houseId:guid}/ai/me/risk-insights` |
| PUT | `/api/houses/{houseId:guid}/ai/me/availability-exceptions` |
| PUT | `/api/v1/houses/{houseId:guid}/ai/me/availability-exceptions` |
| POST | `/api/houses/{houseId:guid}/ai/me/availability-confirmations` |
| POST | `/api/v1/houses/{houseId:guid}/ai/me/availability-confirmations` |
| GET | `/api/houses/{houseId:guid}/ai/evaluations/runs` |
| GET | `/api/v1/houses/{houseId:guid}/ai/evaluations/runs` |
| GET | `/api/houses/{houseId:guid}/ai/evaluations/aggregates` |
| GET | `/api/v1/houses/{houseId:guid}/ai/evaluations/aggregates` |
| GET | `/api/houses/{houseId:guid}/ai/evaluations/runs/{id:guid}` |
| GET | `/api/v1/houses/{houseId:guid}/ai/evaluations/runs/{id:guid}` |
| GET | `/api/houses/{houseId:guid}/ai/evaluations/runs/{id:guid}/examples` |
| GET | `/api/v1/houses/{houseId:guid}/ai/evaluations/runs/{id:guid}/examples` |
| GET | `/api/houses/{houseId:guid}/ai/evaluations/comparisons/{id:guid}` |
| GET | `/api/v1/houses/{houseId:guid}/ai/evaluations/comparisons/{id:guid}` |
| POST | `/api/houses/{houseId:guid}/ai/schedules/propose` |
| POST | `/api/v1/houses/{houseId:guid}/ai/schedules/propose` |
| POST | `/api/houses/{houseId:guid}/ai/schedules/replan` |
| POST | `/api/v1/houses/{houseId:guid}/ai/schedules/replan` |
| POST | `/api/houses/{houseId:guid}/ai/schedules/swap` |
| POST | `/api/v1/houses/{houseId:guid}/ai/schedules/swap` |
| POST | `/api/houses/{houseId:guid}/ai/seasons/evolve` |
| POST | `/api/v1/houses/{houseId:guid}/ai/seasons/evolve` |
| POST | `/api/houses/{houseId:guid}/ai/urgent/plan` |
| POST | `/api/v1/houses/{houseId:guid}/ai/urgent/plan` |
| POST | `/api/houses/{houseId:guid}/ai/urgent/request` |
| POST | `/api/v1/houses/{houseId:guid}/ai/urgent/request` |
| GET | `/api/houses/{houseId:guid}/ai/recommendations/{id:guid}` |
| GET | `/api/v1/houses/{houseId:guid}/ai/recommendations/{id:guid}` |
| POST | `/api/houses/{houseId:guid}/ai/recommendations/{id:guid}/accept` |
| POST | `/api/v1/houses/{houseId:guid}/ai/recommendations/{id:guid}/accept` |
| POST | `/api/houses/{houseId:guid}/ai/recommendations/{id:guid}/reject` |
| POST | `/api/v1/houses/{houseId:guid}/ai/recommendations/{id:guid}/reject` |
| POST | `/api/houses/{houseId:guid}/ai/interpret` |
| POST | `/api/v1/houses/{houseId:guid}/ai/interpret` |
| POST | `/api/houses/{houseId:guid}/ai/chat/insights` |
| POST | `/api/v1/houses/{houseId:guid}/ai/chat/insights` |
| GET | `/api/houses/{houseId:guid}/ai/settings` |
| GET | `/api/v1/houses/{houseId:guid}/ai/settings` |
| PUT | `/api/houses/{houseId:guid}/ai/settings` |
| PUT | `/api/v1/houses/{houseId:guid}/ai/settings` |
| GET | `/api/houses/{houseId:guid}/ai/me/consent` |
| GET | `/api/v1/houses/{houseId:guid}/ai/me/consent` |
| PUT | `/api/houses/{houseId:guid}/ai/me/consent` |
| PUT | `/api/v1/houses/{houseId:guid}/ai/me/consent` |

### AuthController

Ca: AUTH-01…19.

| Method | Route |
|---|---|
| POST | `/api/auth/google` |
| POST | `/api/auth/google/link` |
| POST | `/api/auth/register` |
| POST | `/api/auth/login` |
| POST | `/api/auth/refresh-token` |
| POST | `/api/auth/logout` |

### BountyController

Ca: BOUNTY-01…18, DEBT-01…14.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId}/bounties/eligible-chores` |
| POST | `/api/houses/{houseId}/bounties` |
| POST | `/api/houses/{houseId}/bounties/{bountyId}/accept` |
| POST | `/api/houses/{houseId}/bounties/{bountyId}/cancel` |
| GET | `/api/houses/{houseId}/bounties` |
| GET | `/api/houses/{houseId}/bounties/{bountyId}` |
| GET | `/api/houses/{houseId}/bounties/payments` |
| GET | `/api/houses/{houseId}/bounties/payments/{paymentId}` |
| POST | `/api/houses/{houseId}/bounties/payments/{paymentId}/settle` |

### ChatController

Ca: CHAT-01…14.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId}/chat/unread` |
| PUT | `/api/houses/{houseId}/chat/read` |
| GET | `/api/houses/{houseId}/chat/notification-settings` |
| PUT | `/api/houses/{houseId}/chat/notification-settings` |
| GET | `/api/houses/{houseId}/chat` |
| GET | `/api/chat/rooms/{roomId}/messages` |
| GET | `/api/chat/rooms/{roomId:guid}/photos` |

### ChoreClaimController

Ca: EXEC-07, EXEC-10.

| Method | Route |
|---|---|
| POST | `/api/occurrences/{occurrenceId:guid}/claim` |

### ChoreController

Ca: CHORE-01…18, EXEC-01…14.

| Method | Route |
|---|---|
| POST | `/api/houses/{houseId}/chores` |
| POST | `/api/occurrences/{occurrenceId}/complete` |
| GET | `/api/occurrences/{occurrenceId}` |
| POST | `/api/occurrences/{occurrenceId}/skip` |
| GET | `/api/houses/{houseId}/my-chores` |
| PUT | `/api/chores/{choreId}` |
| DELETE | `/api/chores/{choreId}` |
| GET | `/api/houses/{houseId}/chores` |
| POST | `/api/chores/{choreId}/assign` |

### ChoreEvidenceController

Ca: EXEC-08…09, AI-17.

| Method | Route |
|---|---|
| POST | `/api/occurrences/{id:guid}/evidence` |
| GET | `/api/evidence/{id:guid}` |
| GET | `/api/evidence/{id:guid}/thumbnail` |
| POST | `/api/occurrences/{id:guid}/ai/verify-proof` |
| POST | `/api/occurrences/{id:guid}/evidence/{evidenceId:guid}/attach` |

### ChoreRoutineController

Ca: CHORE-15…17.

| Method | Route |
|---|---|
| POST | `/api/houses/{houseId:guid}/seasons/{seasonId:guid}/routines/{templateId:guid}` |

### DeploymentHealthController

Ca: ENV-01, OPS-01…08.

| Method | Route |
|---|---|
| GET | `/health/version` |
| GET | `/api/deployment/health` |

### EmailOtpController

Ca: AUTH-01…12, OPS-07.

| Method | Route |
|---|---|
| POST | `/api/auth/email-otp/request` |
| POST | `/api/auth/email-otp/verify` |
| POST | `/api/auth/password/reset` |

### FailedEventController

Ca: OPS-04, SECURITY-02.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/failed-events` |
| POST | `/api/houses/{houseId:guid}/failed-events/{failedEventId:guid}/replay` |

### GamificationController

Ca: REWARD-01…06.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId}/gamification/karma` |
| GET | `/api/houses/{houseId}/gamification/karma/history` |
| GET | `/api/houses/{houseId}/gamification/seasons/{seasonId}/rewards` |
| POST | `/api/houses/{houseId}/gamification/rewards/redemptions/{redemptionId}/claim` |
| POST | `/api/houses/{houseId}/gamification/rewards/redemptions/{redemptionId}/use-chore-pass/{occurrenceId}` |
| GET | `/api/houses/{houseId}/gamification/achievements` |

### HouseAdministrationController

Ca: HOUSE-03…17.

| Method | Route |
|---|---|
| GET | `/api/invitations/{code}/preview` |
| POST | `/api/houses/{houseId:guid}/transfer-ownership` |
| POST | `/api/houses/{houseId:guid}/rotate-invite` |
| POST | `/api/houses/{houseId:guid}/archive` |

### HouseCalendarController

Ca: SUMMARY-01, SUMMARY-07.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/calendar` |

### HouseController

Ca: HOUSE-01…17, PREF-01…08, JOIN-01…12.

| Method | Route |
|---|---|
| POST | `/api/houses` |
| POST | `/api/houses/join` |
| DELETE | `/api/houses/{houseId}/leave` |
| DELETE | `/api/houses/{houseId}/members/{memberId}` |
| GET | `/api/houses/{houseId}/members` |
| GET | `/api/houses/{houseId}` |
| GET | `/api/houses/my-houses` |
| POST | `/api/houses/{houseId}/transfer-ownership/{newOwnerId}` |
| GET | `/api/houses/{houseId}/preferences` |
| POST | `/api/houses/{houseId}/preferences` |
| GET | `/api/houses/{houseId}/constraints` |
| POST | `/api/houses/{houseId}/constraints` |

### HouseholdResolutionController

Ca: EXEC-13.

| Method | Route |
|---|---|
| POST | `/api/occurrences/{occurrenceId:guid}/take-responsibility` |

### HouseholdSummaryController

Ca: SUMMARY-02…10.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/summary` |

### HouseMemberReadController

Ca: ACCOUNT-02…05, SUMMARY-05…09.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/members/{userId:guid}/avatar` |
| GET | `/api/houses/{houseId:guid}/members/{userId:guid}/schedule` |

### InternalRepaymentsController

Ca: DEBT-01…14.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/purchase-debts` |
| GET | `/api/payment-obligations/{id:guid}/purchase-debt` |
| GET | `/api/payment-obligations/{id:guid}/instructions` |
| POST | `/api/payment-obligations/{id:guid}/repayments` |
| GET | `/api/payment-obligations/{id:guid}/debt` |
| POST | `/api/payment-obligations/{id:guid}/record-receipt` |
| POST | `/api/payment-obligations/{id:guid}/repayments/{repaymentId:guid}/respond` |

### MediaController

Ca: CHAT-10…14, VOICE-01…08, OPS-05…08.

| Method | Route |
|---|---|
| POST | `/api/media` |
| GET | `/api/media/{id:guid}` |
| POST | `/api/media/send` |

### NotificationController

Ca: NOTI-01…06.

| Method | Route |
|---|---|
| GET | `/api/notifications` |
| POST | `/api/notifications/{notificationId}/read` |
| POST | `/api/notifications/read-all` |

### PersonalFinanceController

Ca: DEBT-01…14, SUMMARY-03.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/me/debts` |
| GET | `/api/houses/{houseId:guid}/me/debts/{id:guid}` |
| GET | `/api/houses/{houseId:guid}/me/payment-history` |

### RewardController

Ca: REWARD-07…09.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/rewards` |
| POST | `/api/houses/{houseId:guid}/rewards` |
| PUT | `/api/houses/{houseId:guid}/rewards/{rewardId:guid}` |
| POST | `/api/houses/{houseId:guid}/rewards/{rewardId:guid}/redeem` |

### SeasonController

Ca: SEASON-01…15, JOIN-01…12, REWARD-02.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId}/seasons/{seasonId}/redistribution-preview` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/redistribute` |
| GET | `/api/houses/{houseId}/seasons/current` |
| GET | `/api/houses/{houseId}/seasons` |
| POST | `/api/houses/{houseId}/seasons` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/start` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/end` |
| GET | `/api/houses/{houseId}/seasons/{seasonId}/availability` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/availability` |
| GET | `/api/houses/{houseId}/seasons/{seasonId}/rankings` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/reuse` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/generate-schedule` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/submit-review` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/confirm` |
| POST | `/api/houses/{houseId}/seasons/{seasonId}/reject` |
| PUT | `/api/houses/{houseId}/seasons/{seasonId}/occurrences/{occurrenceId}/assign` |
| GET | `/api/houses/{houseId}/seasons/{seasonId}/fairness-warnings` |
| GET | `/api/houses/{houseId}/seasons/{seasonId}/occurrences` |
| GET | `/api/houses/{houseId}/seasons/{seasonId}/workload-summary` |

### SimpleSupplyOrdersController

Ca: SHOP-08…15.

| Method | Route |
|---|---|
| POST | `/api/houses/{houseId:guid}/orders/send` |
| POST | `/api/houses/{houseId:guid}/orders/{orderId:guid}/retry-email` |
| POST | `/api/houses/{houseId:guid}/orders/{orderId:guid}/record-payment` |

### SupplierCatalogController

Ca: SHOP-01…06, SUPPLIER-01…02.

| Method | Route |
|---|---|
| GET | `/api/suppliers` |
| GET | `/api/houses/{houseId:guid}/shop/suppliers` |
| POST | `/api/houses/{houseId:guid}/shop/items` |
| GET | `/api/supplier/profile` |
| PUT | `/api/supplier/profile` |
| GET | `/api/suppliers/{supplierId:guid}/products` |
| POST | `/api/supplier/products` |
| PUT | `/api/supplier/products/{productId:guid}` |

### SupplierOrdersController

Ca: SUPPLIER-09.

| Method | Route |
|---|---|
| GET | `/api/supplier/orders` |
| POST | `/api/supplier/orders/{id:guid}/fulfillment` |

### SupplierPaymentsController

Ca: SUPPLIER-06…08.

| Method | Route |
|---|---|
| POST | `/api/houses/{houseId:guid}/supply-orders/{id:guid}/checkout` |
| GET | `/api/houses/{houseId:guid}/supply-orders/{id:guid}/payment` |
| POST | `/api/payments/webhooks/payos` |

### SupplyDisputesController

Ca: SUPPLIER-11.

| Method | Route |
|---|---|
| GET | `/api/supply-orders/{id:guid}/disputes` |
| POST | `/api/supply-orders/{id:guid}/disputes` |
| POST | `/api/supplier/orders/{id:guid}/disputes/{disputeId:guid}/propose` |
| POST | `/api/supply-orders/{id:guid}/disputes/{disputeId:guid}/accept` |

### SupplyOrdersController

Ca: SUPPLIER-03…09.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/supply-orders` |
| GET | `/api/houses/{houseId:guid}/supply-orders/{id:guid}` |
| POST | `/api/houses/{houseId:guid}/supply-orders` |
| PUT | `/api/houses/{houseId:guid}/supply-orders/{id:guid}` |
| POST | `/api/houses/{houseId:guid}/supply-orders/{id:guid}/submit` |
| POST | `/api/houses/{houseId:guid}/supply-orders/{id:guid}/approve` |
| POST | `/api/houses/{houseId:guid}/supply-orders/{id:guid}/cancel` |
| POST | `/api/houses/{houseId:guid}/supply-orders/{id:guid}/receive` |

### SupplyRefundsController

Ca: SUPPLIER-10.

| Method | Route |
|---|---|
| GET | `/api/supply-orders/{id:guid}/refunds` |
| POST | `/api/supplier/orders/{id:guid}/refunds` |
| POST | `/api/supply-orders/{id:guid}/refunds/{refundId:guid}/confirm` |
| POST | `/api/supply-orders/{id:guid}/refunds/{refundId:guid}/reject` |

### SupplySchedulesController

Ca: SUPPLIER-12.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/supply-schedules` |
| POST | `/api/houses/{houseId:guid}/supply-schedules` |
| PATCH | `/api/houses/{houseId:guid}/supply-schedules/{id:guid}` |

### UnresolvedChoreController

Ca: EXEC-11…13.

| Method | Route |
|---|---|
| GET | `/api/houses/{houseId:guid}/unresolved-chores` |

### UserBankAccountsController

Ca: DEBT-09, SECURITY-02.

| Method | Route |
|---|---|
| GET | `/api/user/bank-account` |
| PUT | `/api/user/bank-account` |

### UserController

Ca: ACCOUNT-01…07.

| Method | Route |
|---|---|
| GET | `/api/user/profile` |
| PUT | `/api/user/profile` |
| GET | `/api/user/avatar-image` |
| POST | `/api/user/avatar` |

## SignalR

| Method | Ca |
|---|---|
| JoinRoom / LeaveRoom | CHAT-02, CHAT-14, SECURITY-05 |
| SendMessage / SendText | CHAT-02…08, SECURITY-01…09 |
| ChatUnreadChanged và nhận tin phòng | CHAT-04…08, NOTI-02 |

Không đánh Pass thông báo khi app đóng hoàn toàn chỉ từ việc SignalR hoạt động lúc app mở.
