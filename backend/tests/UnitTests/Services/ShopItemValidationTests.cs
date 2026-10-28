using ChoreWars.Application.DTOs.Supplies;
using ChoreWars.Application.Validations.Supplies;

namespace UnitTests.Services;
public sealed class ShopItemValidationTests
{
    private static CreateShopItemRequest Valid => new(Guid.NewGuid(), "Rice", "kg", 20000, "Shop", "0901234567", "");
    [Fact] public void RequireRealContactAndWholePositiveMoney()
    {
        var validator = new CreateShopItemRequestValidator();
        Assert.True(validator.Validate(Valid).IsValid);
        Assert.True(validator.Validate(Valid with { Phone = "", Email = "shop@example.test" }).IsValid);
        foreach (var request in new[] { Valid with { Phone = "" }, Valid with { Phone = "tel:bad" }, Valid with { Email = "bad" }, Valid with { Price = 0 }, Valid with { Price = 1.5m }, Valid with { Name = " " } })
            Assert.False(validator.Validate(request).IsValid);
    }
}
