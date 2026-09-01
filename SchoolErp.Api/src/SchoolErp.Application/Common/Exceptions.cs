namespace SchoolErp.Application.Common;

/// <summary>Thrown when a requested resource does not exist. Maps to HTTP 404.</summary>
public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }
}

/// <summary>Thrown for business-rule violations. Maps to HTTP 400.</summary>
public class ValidationException : Exception
{
    public ValidationException(string message) : base(message) { }
}

/// <summary>
/// Thrown when the caller is authenticated but their token does not carry the scope the
/// operation needs (e.g. an admin endpoint reached without a school id). Maps to HTTP 403.
/// </summary>
public class ForbiddenException : Exception
{
    public ForbiddenException(string message) : base(message) { }
}
