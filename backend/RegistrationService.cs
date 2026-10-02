#nullable enable
using System;
using System.Data;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;

namespace CampusEventManagement.Backend
{
    public interface IRegistrationRepository
    {
        /// <summary>Returns the latest registration status for the email, or null if none exists.</summary>
        Task<string?> GetRegistrationStatusByEmailAsync(string email);

        /// <summary>Returns seats_available for the event, or null if the event does not exist.</summary>
        Task<int?> GetSeatsAvailableAsync(int eventId);
    }

    public sealed class SqlRegistrationRepository : IRegistrationRepository
    {
        private readonly string _connectionString;

        // FIX: The connection string is injected. Load it from user-secrets,
        // an environment variable, or appsettings.json. Never hardcode it.
        public SqlRegistrationRepository(string connectionString)
        {
            if (string.IsNullOrWhiteSpace(connectionString))
                throw new ArgumentException("Connection string is required.", nameof(connectionString));

            _connectionString = connectionString;
        }

        public async Task<string?> GetRegistrationStatusByEmailAsync(string email)
        {
            // FIX: Fixed SQL text. User input never becomes part of the SQL.
            // FIX: JOIN Users because Registrations has no email column.
            // FIX: Select one named column instead of SELECT *.
            const string sql = @"
                SELECT TOP (1) r.status
                FROM dbo.Registrations AS r
                INNER JOIN dbo.Users AS u ON u.user_id = r.user_id
                WHERE u.email = @email
                ORDER BY r.registration_date DESC;";

            // FIX: 'using' closes and disposes each object, even when an
            // exception occurs. This returns the connection to the pool.
            await using var conn = new SqlConnection(_connectionString);
            await using var cmd = new SqlCommand(sql, conn);

            // FIX: Parameterized query with an explicit type and size.
            // The driver sends the value as data, not as SQL.
            cmd.Parameters.Add(new SqlParameter("@email", SqlDbType.NVarChar, 255) { Value = email });

            await conn.OpenAsync();
            object? result = await cmd.ExecuteScalarAsync();

            // FIX: Null-safe. No row returns null instead of throwing.
            return result is null or DBNull ? null : Convert.ToString(result);
        }

        public async Task<int?> GetSeatsAvailableAsync(int eventId)
        {
            const string sql = @"
                SELECT e.capacity - COUNT(r.registration_id)
                FROM dbo.Events AS e
                LEFT JOIN dbo.Registrations AS r
                    ON r.event_id = e.event_id
                    AND r.status IN ('registered', 'attended')
                WHERE e.event_id = @eventId
                GROUP BY e.capacity;";

            await using var conn = new SqlConnection(_connectionString);
            await using var cmd = new SqlCommand(sql, conn);

            cmd.Parameters.Add(new SqlParameter("@eventId", SqlDbType.Int) { Value = eventId });

            await conn.OpenAsync();
            object? result = await cmd.ExecuteScalarAsync();

            return result is null or DBNull ? null : Convert.ToInt32(result);
        }
    }

    public sealed class RegistrationService
    {
        // Strict allow-list: safe characters, then exactly @univ.edu.ph.
        // \z (not $) rejects a trailing newline.
        private static readonly Regex StudentEmailPattern = new(
            @"^[A-Za-z0-9._%+\-]+@univ\.edu\.ph\z",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant,
            TimeSpan.FromMilliseconds(100));

        private readonly IRegistrationRepository _repository;

        public RegistrationService(IRegistrationRepository repository)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        }

        /// <summary>Returns the registration status, or null if the email is invalid or not found.</summary>
        public async Task<string?> GetUserRegistrationAsync(string inputEmail)
        {
            // FIX: Reject bad input before it reaches the database.
            // This is defense in depth. The parameterized query is the main fix.
            if (!IsValidStudentEmail(inputEmail))
                return null;

            return await _repository.GetRegistrationStatusByEmailAsync(inputEmail);
        }

        public bool IsValidStudentEmail(string? email)
        {
            if (string.IsNullOrWhiteSpace(email))
                return false;

            return StudentEmailPattern.IsMatch(email);
        }

        public async Task<bool> HasSeatsAvailableAsync(int eventId)
        {
            int? seats = await _repository.GetSeatsAvailableAsync(eventId);
            return seats.HasValue && seats.Value > 0;
        }
    }
}