#nullable enable
using System;
using System.Threading.Tasks;
using CampusEventManagement.Backend;
using Moq;
using Xunit;

namespace CampusEventManagement.Tests
{
    public class RegistrationServiceTests
    {
        private static (RegistrationService Service, Mock<IRegistrationRepository> Repo) CreateSut()
        {
            // Strict mock: any call without a setup fails the test.
            var repo = new Mock<IRegistrationRepository>(MockBehavior.Strict);
            return (new RegistrationService(repo.Object), repo);
        }

        // ---------- Constructor ----------

        [Fact]
        public void Constructor_NullRepository_ThrowsArgumentNullException()
        {
            Assert.Throws<ArgumentNullException>(() => new RegistrationService(null!));
        }

        // ---------- Email validation ----------

        [Theory]
        [InlineData("alex.johnson@univ.edu.ph")]
        [InlineData("maria_santos+lab@univ.edu.ph")]
        public void IsValidStudentEmail_ValidUnivDomain_ReturnsTrue(string email)
        {
            // Arrange
            var (service, _) = CreateSut();

            // Act
            bool result = service.IsValidStudentEmail(email);

            // Assert
            Assert.True(result);
        }

        [Theory]
        [InlineData("Alex.Johnson@UNIV.EDU.PH")]
        [InlineData("liam@Univ.Edu.Ph")]
        public void IsValidStudentEmail_MixedCaseDomain_ReturnsTrue(string email)
        {
            var (service, _) = CreateSut();

            bool result = service.IsValidStudentEmail(email);

            Assert.True(result);
        }

        [Theory]
        [InlineData("alex@gmail.com")]
        [InlineData("alex@univ.edu")]
        [InlineData("alex@fakeuniv.edu.ph")]
        [InlineData("alex.univ.edu.ph")]
        [InlineData("@univ.edu.ph")]
        [InlineData("admin@campus.edu")]
        public void IsValidStudentEmail_WrongDomainOrFormat_ReturnsFalse(string email)
        {
            var (service, _) = CreateSut();

            bool result = service.IsValidStudentEmail(email);

            Assert.False(result);
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("   ")]
        [InlineData("\t\n")]
        public void IsValidStudentEmail_NullEmptyOrWhitespace_ReturnsFalse(string? email)
        {
            var (service, _) = CreateSut();

            bool result = service.IsValidStudentEmail(email);

            Assert.False(result);
        }

        [Theory]
        [InlineData("name@univ.edu.ph.evil.com")]
        [InlineData("name@univ.edu.ph.")]
        [InlineData("name@univ.edu.ph\n")]
        [InlineData("name@univ.edu.ph evil")]
        public void IsValidStudentEmail_LookalikeDomain_ReturnsFalse(string email)
        {
            var (service, _) = CreateSut();

            bool result = service.IsValidStudentEmail(email);

            Assert.False(result);
        }

        [Theory]
        [InlineData("' OR '1'='1")]
        [InlineData("a@univ.edu.ph' OR '1'='1")]
        [InlineData("x'; DROP TABLE Registrations;--@univ.edu.ph")]
        public void IsValidStudentEmail_SqlInjectionString_ReturnsFalse(string email)
        {
            var (service, _) = CreateSut();

            bool result = service.IsValidStudentEmail(email);

            Assert.False(result);
        }

        // ---------- Seat availability ----------

        [Theory]
        [InlineData(1)]
        [InlineData(50)]
        public async Task HasSeatsAvailableAsync_SeatsGreaterThanZero_ReturnsTrue(int seats)
        {
            // Arrange
            var (service, repo) = CreateSut();
            repo.Setup(r => r.GetSeatsAvailableAsync(10)).ReturnsAsync(seats);

            // Act
            bool result = await service.HasSeatsAvailableAsync(10);

            // Assert
            Assert.True(result);
            repo.Verify(r => r.GetSeatsAvailableAsync(10), Times.Once);
        }

        [Fact]
        public async Task HasSeatsAvailableAsync_ZeroSeats_ReturnsFalse()
        {
            var (service, repo) = CreateSut();
            repo.Setup(r => r.GetSeatsAvailableAsync(10)).ReturnsAsync(0);

            bool result = await service.HasSeatsAvailableAsync(10);

            Assert.False(result);
        }

        [Fact]
        public async Task HasSeatsAvailableAsync_EventNotFound_ReturnsFalse()
        {
            var (service, repo) = CreateSut();
            repo.Setup(r => r.GetSeatsAvailableAsync(999)).ReturnsAsync((int?)null);

            bool result = await service.HasSeatsAvailableAsync(999);

            Assert.False(result);
        }

        [Theory]
        [InlineData(-1)]
        [InlineData(-100)]
        public async Task HasSeatsAvailableAsync_NegativeSeats_ReturnsFalse(int seats)
        {
            var (service, repo) = CreateSut();
            repo.Setup(r => r.GetSeatsAvailableAsync(10)).ReturnsAsync(seats);

            bool result = await service.HasSeatsAvailableAsync(10);

            Assert.False(result);
        }

        // ---------- GetUserRegistrationAsync ----------

        [Fact]
        public async Task GetUserRegistrationAsync_RegistrationExists_ReturnsStatus()
        {
            // Arrange
            const string email = "alex.johnson@univ.edu.ph";
            var (service, repo) = CreateSut();
            repo.Setup(r => r.GetRegistrationStatusByEmailAsync(email)).ReturnsAsync("registered");

            // Act
            string? result = await service.GetUserRegistrationAsync(email);

            // Assert
            Assert.Equal("registered", result);
        }

        [Fact]
        public async Task GetUserRegistrationAsync_NotFound_ReturnsNull()
        {
            const string email = "nobody@univ.edu.ph";
            var (service, repo) = CreateSut();
            repo.Setup(r => r.GetRegistrationStatusByEmailAsync(email)).ReturnsAsync((string?)null);

            string? result = await service.GetUserRegistrationAsync(email);

            Assert.Null(result);
        }

        [Fact]
        public async Task GetUserRegistrationAsync_ValidEmail_CallsRepositoryOnceWithExactEmail()
        {
            const string email = "alex.johnson@univ.edu.ph";
            var (service, repo) = CreateSut();
            repo.Setup(r => r.GetRegistrationStatusByEmailAsync(It.IsAny<string>())).ReturnsAsync("registered");

            await service.GetUserRegistrationAsync(email);

            repo.Verify(r => r.GetRegistrationStatusByEmailAsync(email), Times.Once);
            repo.VerifyNoOtherCalls();
        }

        [Theory]
        [InlineData("' OR '1'='1")]
        [InlineData("alex@gmail.com")]
        [InlineData("")]
        [InlineData(null)]
        public async Task GetUserRegistrationAsync_InvalidEmail_ReturnsNullAndNeverCallsRepository(string? email)
        {
            var (service, repo) = CreateSut();

            string? result = await service.GetUserRegistrationAsync(email!);

            Assert.Null(result);
            repo.Verify(r => r.GetRegistrationStatusByEmailAsync(It.IsAny<string>()), Times.Never);
        }
    }
}