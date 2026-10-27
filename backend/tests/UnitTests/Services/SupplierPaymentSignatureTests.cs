using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ChoreWars.Domain.Exceptions;
using ChoreWars.Infrastructure.Payments;
using Microsoft.Extensions.Options;
namespace UnitTests.Services;
public sealed class SupplierPaymentSignatureTests
{
 private const string Key="test-only-checksum-secret";
 private static PayOsPurchasePaymentGateway Gateway()=>new(new HttpClient(),Options.Create(new PayOsOptions{Enabled=true,OperatorUserId=Guid.NewGuid(),ClientId="test",ApiKey="test",ChecksumKey=Key,AccountNumber="12345678",WebBaseUrl="https://example.test"}));
 private static JsonElement Callback(decimal amount,string account="12345678",bool forge=false){
  var data=new SortedDictionary<string,object>{{"accountNumber",account},{"amount",amount},{"code","00"},{"currency","VND"},{"orderCode",123456789},{"paymentLinkId","link"},{"reference","bank-reference"}};
  var canonical=string.Join("&",data.Select(x=>$"{x.Key}={Convert.ToString(x.Value,CultureInfo.InvariantCulture)}"));
  var signature=Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(Key),Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
  return JsonSerializer.SerializeToElement(new{code="00",success=true,data,signature=forge?new string('0',64):signature});
 }
 [Fact]public async Task SignedCallbackStillMustMatchSupplierBankAccount(){var gateway=Gateway();var valid=await gateway.VerifyAsync(Callback(360000),default);Assert.Equal(360000,valid.Amount);await Assert.ThrowsAsync<DomainException>(()=>gateway.VerifyAsync(Callback(360000,forge:true),default));await Assert.ThrowsAsync<DomainException>(()=>gateway.VerifyAsync(Callback(360000,"another-account"),default));}
 [Fact]public void MissingConfigurationFailsBeforeAnOrderIsCharged(){var gateway=new PayOsPurchasePaymentGateway(new HttpClient(),Options.Create(new PayOsOptions()));Assert.Throws<ConflictException>(gateway.EnsureConfigured);}
}
