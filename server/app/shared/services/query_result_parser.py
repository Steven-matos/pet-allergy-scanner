"""
Centralized query result parser

This is the SINGLE SOURCE OF TRUTH for:
1. Parsing query results with JSON field handling
2. Handling edge cases in query results
3. Standardized result parsing patterns

All query result parsing should use this service for consistency.
"""

from typing import List, Dict, Any, Optional
import json
import logging

logger = logging.getLogger(__name__)


class QueryResultParser:
    """
    Centralized service for parsing query results
    
    This ensures:
    - Consistent JSON field parsing
    - Standardized edge case handling
    - Easier maintenance of parsing logic
    """
    
    @staticmethod
    def parse_json_field(
        data: Dict[str, Any],
        field_name: str,
        default: Any = None
    ) -> Any:
        """
        Parse JSON field from database result
        
        Handles cases where:
        - Field is already a dict/list (parsed)
        - Field is a JSON string (needs parsing)
        - Field is None or missing
        
        Args:
            data: Dictionary from database query
            field_name: Name of the JSON field to parse
            default: Default value if field is missing or parsing fails
            
        Returns:
            Parsed JSON value or default
        """
        if field_name not in data:
            return default
        
        value = data.get(field_name)
        
        # If already parsed (dict/list), return as-is
        if isinstance(value, (dict, list)):
            return value
        
        # If None, return default
        if value is None:
            return default
        
        # If string, try to parse as JSON
        if isinstance(value, str):
            try:
                return json.loads(value)
            except (json.JSONDecodeError, TypeError) as e:
                logger.warning(
                    f"Failed to parse JSON field '{field_name}': {e}. "
                    f"Using default value."
                )
                return default
        
        # Otherwise return as-is
        return value
    
    @staticmethod
    def parse_json_fields(
        data: Dict[str, Any],
        field_names: List[str],
        defaults: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Parse multiple JSON fields from database result
        
        Args:
            data: Dictionary from database query
            field_names: List of JSON field names to parse
            defaults: Dictionary mapping field names to default values
            
        Returns:
            Dictionary with parsed JSON fields
        """
        if defaults is None:
            defaults = {}
        
        result = data.copy()
        
        for field_name in field_names:
            default = defaults.get(field_name)
            result[field_name] = QueryResultParser.parse_json_field(
                data, field_name, default
            )
        
        return result
    
    @staticmethod
    def parse_list_json_fields(
        data_list: List[Dict[str, Any]],
        field_names: List[str],
        defaults: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """
        Parse JSON fields for a list of database results
        
        Args:
            data_list: List of dictionaries from database query
            field_names: List of JSON field names to parse
            defaults: Dictionary mapping field names to default values
            
        Returns:
            List of dictionaries with parsed JSON fields
        """
        return [
            QueryResultParser.parse_json_fields(item, field_names, defaults)
            for item in data_list
        ]
    
    @staticmethod
    def safe_parse_json_field(
        data: Dict[str, Any],
        field_name: str,
        expected_type: type = dict,
        default: Any = None
    ) -> Any:
        """
        Safely parse JSON field with type validation
        
        Args:
            data: Dictionary from database query
            field_name: Name of the JSON field to parse
            expected_type: Expected type after parsing (dict or list)
            default: Default value if field is missing, parsing fails, or type is wrong
            
        Returns:
            Parsed JSON value of expected type or default
        """
        parsed = QueryResultParser.parse_json_field(data, field_name, default)
        
        # Validate type
        if parsed is not None and not isinstance(parsed, expected_type):
            logger.warning(
                f"JSON field '{field_name}' has unexpected type "
                f"{type(parsed).__name__}, expected {expected_type.__name__}. "
                f"Using default value."
            )
            return default
        
        return parsed

