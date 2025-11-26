"""
Shared services package

Centralized services for common operations across the application.
This package provides the single source of truth for:
- Database operations
- Data transformations
- Query building
- Response model conversion
- Validation
- ID generation
- Pagination
- Error handling utilities
"""

# Database operations
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.datetime_service import DateTimeService

# Query building and data access
from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.query_result_parser import QueryResultParser

# Data transformation and model conversion
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.response_utils import (
    handle_empty_response,
    handle_empty_query_response
)

# Validation and utilities
from app.shared.services.validation_service import ValidationService
from app.shared.services.id_generation_service import IDGenerationService
from app.shared.services.pagination_service import (
    PaginationService,
    PaginationResponse
)

__all__ = [
    # Database operations
    'DatabaseOperationService',
    'DateTimeService',
    
    # Query building and data access
    'QueryBuilderService',
    'QueryResultParser',
    
    # Data transformation and model conversion
    'DataTransformationService',
    'ResponseModelService',
    'handle_empty_response',
    'handle_empty_query_response',
    
    # Validation and utilities
    'ValidationService',
    'IDGenerationService',
    'PaginationService',
    'PaginationResponse',
]
