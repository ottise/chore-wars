using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddCloudinaryFiles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CloudinaryFiles",
                columns: table => new
                {
                    StorageKey = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    CloudName = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    AssetId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    PublicId = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    ResourceType = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CloudinaryFiles", x => x.StorageKey);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CloudinaryFiles");
        }
    }
}
