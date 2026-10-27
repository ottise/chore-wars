using System.Text.Json;
using ChoreWars.Domain.Entities;
using ChoreWars.Domain.Exceptions;
namespace ChoreWars.Application.Services.Supplies;
public static class SupplyAIContract
{
 public static void Validate(JsonElement result,HashSet<string> members,IReadOnlyDictionary<Guid,SupplyProduct> products){
  if(!result.TryGetProperty("intent",out var intent)||intent.GetString() is not ("supply_purchase" or "supply_reminder"))return;
  if(!result.TryGetProperty("supply",out var candidate)||candidate.ValueKind==JsonValueKind.Null)return;
  if(candidate.ValueKind!=JsonValueKind.Object)throw new ConflictException("The assistant returned an invalid supply suggestion.");
  if(candidate.TryGetProperty("payer_id",out var payer)&&payer.ValueKind!=JsonValueKind.Null&&(!payer.TryGetGuid(out var payerId)||!members.Contains(payerId.ToString())))throw new ConflictException("The suggested payer is not an active household member.");
  if(candidate.TryGetProperty("participant_ids",out var participants)){
   if(participants.ValueKind!=JsonValueKind.Array||participants.GetArrayLength()>100)throw new ConflictException("Invalid purchase participants.");
   foreach(var user in participants.EnumerateArray())if(!user.TryGetGuid(out var id)||!members.Contains(id.ToString()))throw new ConflictException("The suggested participant is not an active household member.");
  }
  if(candidate.TryGetProperty("lines",out var lines)){
   if(lines.ValueKind!=JsonValueKind.Array||lines.GetArrayLength()>30)throw new ConflictException("Invalid supply selection.");
   foreach(var line in lines.EnumerateArray()){
    if(!line.TryGetProperty("product_id",out var value)||!value.TryGetGuid(out var productId)||!products.TryGetValue(productId,out var product))throw new ConflictException("The suggested product is not available in the catalog.");
    if(!candidate.TryGetProperty("supplier_id",out var supplier)||!supplier.TryGetGuid(out var supplierId)||supplierId!=product.SupplierId)throw new ConflictException("The supplier does not match the suggested product.");
    if(!line.TryGetProperty("quantity",out var quantity)||!quantity.TryGetInt32(out var amount)||amount is <1 or >1000)throw new ConflictException("Invalid suggested purchase quantity.");
   }
  }
 }
}
