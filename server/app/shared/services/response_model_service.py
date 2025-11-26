"""
Centralized response model conversion service

This is the SINGLE SOURCE OF TRUTH for:
1. Converting database responses to Pydantic models
2. Consistent model conversion patterns
3. Handling nested model conversions

All model conversions should use this service for consistency.
"""

from typing import Type, TypeVar, List, Dict, Any, Optional
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)

# Type variable for Pydantic models
T = TypeVar('T', bound=BaseModel)


class ResponseModelService:
    """
    Centralized service for converting database responses to Pydantic models
    
    This ensures:
    - Consistent model conversion across the application
    - Single place to handle conversion logic
    - Easier maintenance when models change
    """
    
    @staticmethod
    def convert_to_model(data: Dict[str, Any], model_class: Type[T]) -> T:
        """
        Convert database dict to Pydantic model
        
        Args:
            data: Dictionary from database query
            model_class: Pydantic model class to convert to
            
        Returns:
            Instance of the specified Pydantic model
            
        Raises:
            ValueError: If conversion fails
        """
        try:
            return model_class(**data)
        except Exception as e:
            logger.error(f"Error converting dict to {model_class.__name__}: {e}")
            logger.debug(f"Data: {data}")
            raise ValueError(f"Failed to convert data to {model_class.__name__}: {str(e)}")
    
    @staticmethod
    def convert_list_to_models(data_list: List[Dict[str, Any]], model_class: Type[T]) -> List[T]:
        """
        Convert list of database dicts to Pydantic models
        
        Args:
            data_list: List of dictionaries from database query
            model_class: Pydantic model class to convert to
            
        Returns:
            List of Pydantic model instances
            
        Raises:
            ValueError: If any conversion fails
        """
        try:
            return [model_class(**item) for item in data_list]
        except Exception as e:
            logger.error(f"Error converting list to {model_class.__name__}: {e}")
            raise ValueError(f"Failed to convert data list to {model_class.__name__}: {str(e)}")
    
    @staticmethod
    def safe_convert_to_model(
        data: Dict[str, Any], 
        model_class: Type[T],
        default: Optional[T] = None
    ) -> Optional[T]:
        """
        Safely convert database dict to Pydantic model with fallback
        
        Args:
            data: Dictionary from database query
            model_class: Pydantic model class to convert to
            default: Default value to return if conversion fails (None if not provided)
            
        Returns:
            Instance of the specified Pydantic model or default value if conversion fails
        """
        try:
            return ResponseModelService.convert_to_model(data, model_class)
        except Exception as e:
            logger.warning(f"Failed to convert to {model_class.__name__}, using default: {e}")
            return default
    
    @staticmethod
    def safe_convert_list_to_models(
        data_list: List[Dict[str, Any]], 
        model_class: Type[T],
        filter_errors: bool = True
    ) -> List[T]:
        """
        Safely convert list of database dicts to Pydantic models, filtering out errors
        
        Args:
            data_list: List of dictionaries from database query
            model_class: Pydantic model class to convert to
            filter_errors: If True, filter out items that fail conversion. If False, raise on first error.
            
        Returns:
            List of Pydantic model instances (may be shorter than input if filter_errors=True)
        """
        if not filter_errors:
            return ResponseModelService.convert_list_to_models(data_list, model_class)
        
        results = []
        for item in data_list:
            try:
                results.append(ResponseModelService.convert_to_model(item, model_class))
            except Exception as e:
                logger.warning(f"Skipping item in list conversion to {model_class.__name__}: {e}")
        
        return results

