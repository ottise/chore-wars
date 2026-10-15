using System.Security.Claims;
using ChoreWars.Application.DTOs.Proposal;
using ChoreWars.Application.Interfaces.Services;
using ChoreWars.Domain.Enums;
using ChoreWars.Presentation.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;

namespace IntegrationTests.Controllers;

public class ActionProposalControllerTests
{
    [Fact]
    public async Task PostHouseProposal_Returns201Created()
    {
        var userId = Guid.NewGuid();
        var houseId = Guid.NewGuid();
        var service = new Mock<IActionProposalService>();
        service.Setup(x => x.CreateProposalAsync(houseId, It.IsAny<CreateProposalRequest>(), userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ActionProposalResponse { Id = Guid.NewGuid(), HouseId = houseId, RoomId = Guid.NewGuid() });
        var controller = CreateController(service.Object, userId);

        var result = await controller.Create(houseId, new CreateProposalRequest
        {
            Type = ProposalType.CHORE_SWAP,
            Title = "Swap",
            TargetUserIds = new() { Guid.NewGuid() }
        }, CancellationToken.None);

        var created = Assert.IsType<CreatedAtActionResult>(result);
        Assert.Equal(StatusCodes.Status201Created, created.StatusCode);
        Assert.IsType<ActionProposalResponse>(created.Value);
    }

    [Fact]
    public async Task PostProposalResponse_Returns200OkWithUpdatedProposal()
    {
        var userId = Guid.NewGuid();
        var proposalId = Guid.NewGuid();
        var expected = new ActionProposalResponse { Id = proposalId, Status = ProposalStatus.APPROVED };
        var request = new RespondProposalRequest { Status = ConfirmationStatus.CONFIRMED };
        var service = new Mock<IActionProposalService>();
        service.Setup(x => x.RespondProposalAsync(proposalId, request, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expected);
        var controller = CreateController(service.Object, userId);

        var result = await controller.Respond(proposalId, request, CancellationToken.None);

        var ok = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(StatusCodes.Status200OK, ok.StatusCode);
        Assert.Same(expected, ok.Value);
    }

    private static ActionProposalController CreateController(IActionProposalService service, Guid userId)
    {
        var identity = new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, userId.ToString()) }, "test");
        return new ActionProposalController(service)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(identity) }
            }
        };
    }
}
