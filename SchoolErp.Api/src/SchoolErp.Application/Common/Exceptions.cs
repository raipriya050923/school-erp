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
