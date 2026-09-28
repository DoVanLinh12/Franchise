class BusinessError(Exception):
    """Base exception for expected business failures."""


class ValidationError(BusinessError):
    """Raised when a command is invalid before accessing the database."""


class AuthenticationError(BusinessError):
    """Raised when credentials or an authentication token are invalid."""


class AuthorizationError(BusinessError):
    """Raised when an authenticated user lacks the required permission."""


class TokenError(AuthenticationError):
    """Raised when a JWT cannot be trusted or has expired."""


class NotFoundError(BusinessError):
    """Raised when a requested record does not exist."""


class ConflictError(BusinessError):
    """Raised when a command conflicts with current state."""
