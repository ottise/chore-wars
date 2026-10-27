using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Exceptions;
using Microsoft.Extensions.Options;
namespace ChoreWars.Infrastructure.Payments;
public sealed class PayOsPurchasePaymentGateway(HttpClient http, IOptions<PayOsOptions> options) : IPurchasePaymentGateway
{
    public void EnsureConfigured() {
        var o=Settings();
        if (!Uri.TryCreate(o.WebBaseUrl,UriKind.Absolute,out var origin) || (origin.Scheme!="https" && !(origin.Scheme=="http"&&origin.IsLoopback)))
            throw new ConflictException("Configure the supplier checkout web return address before creating a payment.");
    }
    private PayOsOptions Settings()
    {
        var o = options.Value;
        if (!o.Enabled || o.OperatorUserId == Guid.Empty || string.IsNullOrWhiteSpace(o.ClientId) ||
            string.IsNullOrWhiteSpace(o.ApiKey) || string.IsNullOrWhiteSpace(o.ChecksumKey) || string.IsNullOrWhiteSpace(o.AccountNumber))
            throw new ConflictException("Supplier payment is not configured. No payment or purchase debt has been recorded.");
        return o;
    }
    public async Task<SupplierCheckoutResult> CreateAsync(SupplierCheckoutRequest r, CancellationToken ct)
    {
        var o = Settings();
        if (!Uri.TryCreate(o.WebBaseUrl, UriKind.Absolute, out var origin) ||
            (origin.Scheme != "https" && !(origin.Scheme == "http" && origin.IsLoopback)))
            throw new ConflictException("Configure the supplier checkout web return address.");
        var returnUrl = $"{origin.GetLeftPart(UriPartial.Authority)}/#/houses/{r.HouseId}/supplies/orders/{r.OrderId}";
        var description = $"CW{r.OrderCode.ToString(CultureInfo.InvariantCulture)[^7..]}";
        var fields = new SortedDictionary<string, string>(StringComparer.Ordinal) {
            ["amount"] = decimal.Truncate(r.Amount).ToString(CultureInfo.InvariantCulture), ["cancelUrl"] = returnUrl,
            ["description"] = description, ["orderCode"] = r.OrderCode.ToString(CultureInfo.InvariantCulture), ["returnUrl"] = returnUrl };
        var body = new { orderCode = r.OrderCode, amount = (long)r.Amount, description, cancelUrl = returnUrl,
            returnUrl, expiredAt = new DateTimeOffset(r.ExpiresAt).ToUnixTimeSeconds(), signature = Sign(fields, o.ChecksumKey) };
        var payload = await Send(HttpMethod.Post, "v2/payment-requests", body, ct);
        var data = payload.GetProperty("data");
        VerifyData(payload, o);
        if (data.GetProperty("orderCode").GetInt64() != r.OrderCode || data.GetProperty("amount").GetDecimal() != r.Amount ||
            data.GetProperty("accountNumber").GetString() != o.AccountNumber) throw new ConflictException("Payment response did not match the supplier order.");
        var url = data.GetProperty("checkoutUrl").GetString()!;
        if (!Uri.TryCreate(url, UriKind.Absolute, out var checkout) || checkout.Scheme != "https" ||
            !(checkout.Host == "pay.payos.vn" || checkout.Host.EndsWith(".payos.vn", StringComparison.OrdinalIgnoreCase)))
            throw new ConflictException("Unexpected payment checkout address.");
        return new(data.GetProperty("paymentLinkId").GetString()!, url, data.GetProperty("qrCode").GetString()!);
    }
    public async Task<SupplierPaymentResult> QueryAsync(long code, CancellationToken ct)
    {
        var result = await Send(HttpMethod.Get, $"v2/payment-requests/{code.ToString(CultureInfo.InvariantCulture)}", null, ct);
        var d = result.GetProperty("data");
        var status = d.GetProperty("status").GetString() ?? "PENDING";
        var amount = status == "PAID" ? d.GetProperty("amountPaid").GetDecimal() : d.GetProperty("amount").GetDecimal();
        return new(d.GetProperty("orderCode").GetInt64(), status, amount, d.GetProperty("id").GetString()!, $"query:{code}");
    }
    public Task<SupplierPaymentResult> VerifyAsync(JsonElement webhook, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        try {
        var o = Settings(); VerifyData(webhook, o);
        var d = webhook.GetProperty("data");
        if (!webhook.TryGetProperty("success", out var success) || !success.GetBoolean() ||
            webhook.GetProperty("code").GetString() != "00" || d.GetProperty("code").GetString() != "00" ||
            d.GetProperty("currency").GetString() != "VND" || d.GetProperty("accountNumber").GetString() != o.AccountNumber)
            throw new DomainException("This callback does not confirm a VND payment to this supplier.");
        return Task.FromResult(new SupplierPaymentResult(d.GetProperty("orderCode").GetInt64(), "PAID",
            d.GetProperty("amount").GetDecimal(), d.GetProperty("paymentLinkId").GetString()!, d.GetProperty("reference").GetString()!));
        } catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException or FormatException) {
            throw new DomainException("Malformed payment callback.");
        }
    }
    private static string Sign(IEnumerable<KeyValuePair<string, string>> fields, string key) =>
        Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(key), Encoding.UTF8.GetBytes(string.Join("&", fields.Select(x => $"{x.Key}={x.Value}"))))).ToLowerInvariant();
    private static void VerifyData(JsonElement payload, PayOsOptions options)
    {
        if (!payload.TryGetProperty("data", out var data) || data.ValueKind != JsonValueKind.Object || !payload.TryGetProperty("signature", out var signature))
            throw new DomainException("Missing payment signature.");
        var fields = data.EnumerateObject().OrderBy(x => x.Name, StringComparer.Ordinal).Select(x => new KeyValuePair<string, string>(x.Name,
            x.Value.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined ? "" : x.Value.ValueKind == JsonValueKind.String ? x.Value.GetString()! : x.Value.GetRawText()));
        var expected = Sign(fields, options.ChecksumKey);
        var supplied = signature.GetString() ?? "";
        if (expected.Length != supplied.Length || !CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(expected), Encoding.ASCII.GetBytes(supplied.ToLowerInvariant())))
            throw new DomainException("Invalid payment signature.");
    }
    private async Task<JsonElement> Send(HttpMethod method, string path, object? body, CancellationToken ct)
    {
        var o = Settings();
        using var request = new HttpRequestMessage(method, new Uri(new Uri("https://api-merchant.payos.vn/"), path));
        request.Headers.Add("x-client-id", o.ClientId); request.Headers.Add("x-api-key", o.ApiKey);
        if (body != null) request.Content = JsonContent.Create(body);
        using var response = await http.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode) throw new ConflictException($"Payment provider could not confirm this request ({(int)response.StatusCode}). Reconcile before trying another payment.");
        var payload = await response.Content.ReadFromJsonAsync<JsonElement>(ct);
        if (payload.GetProperty("code").GetString() != "00") throw new ConflictException("Payment provider rejected the request. No successful payment has been recorded.");
        return payload;
    }
}
