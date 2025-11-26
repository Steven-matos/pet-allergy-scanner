"""
Centralized data transformation service

This is the SINGLE SOURCE OF TRUTH for:
1. Converting Pydantic models to dictionaries
2. Handling nested object transformations
3. Standardized data serialization

All data transformations should use this service for consistency.
"""

from typing import Dict, Any, Optional, List
from pydantic import BaseModel
import json
import logging

logger = logging.getLogger(__name__)


class DataTransformationService:
    """
    Centralized service for data transformations
    
    This ensures:
    - Consistent model-to-dict conversion
    - Proper handling of nested objects
    - Standardized serialization patterns
    """
    
    @staticmethod
    def model_to_dict(model: BaseModel, exclude_none: bool = False) -> Dict[str, Any]:
        """
        Convert Pydantic model to dictionary with nested object handling
        
        Args:
            model: Pydantic model instance
            exclude_none: Whether to exclude None values from the dictionary
            
        Returns:
            Dictionary representation of the model
        """
        if exclude_none:
            return model.model_dump(exclude_none=True)
        return model.model_dump()
    
    @staticmethod
    def model_to_dict_with_nested(
        model: BaseModel,
        exclude_none: bool = False
    ) -> Dict[str, Any]:
        """
        Convert Pydantic model to dictionary, handling nested Pydantic models
        
        Args:
            model: Pydantic model instance
            exclude_none: Whether to exclude None values from the dictionary
            
        Returns:
            Dictionary representation with nested models converted to dicts
        """
        data = DataTransformationService.model_to_dict(model, exclude_none)
        
        # Convert nested Pydantic models to dicts
        for key, value in data.items():
            if isinstance(value, BaseModel):
                data[key] = DataTransformationService.model_to_dict(value, exclude_none)
            elif isinstance(value, list):
                data[key] = [
                    DataTransformationService.model_to_dict(item, exclude_none)
                    if isinstance(item, BaseModel)
                    else item
                    for item in value
                ]
        
        return data
    
    @staticmethod
    def prepare_for_database(
        data: Dict[str, Any],
        handle_nested: bool = True
    ) -> Dict[str, Any]:
        """
        Prepare data dictionary for database insertion
        
        This handles:
        - Converting Pydantic models to dicts
        - Converting datetime objects to ISO strings
        - Handling nested objects
        
        Args:
            data: Data dictionary to prepare
            handle_nested: Whether to handle nested Pydantic models
            
        Returns:
            Dictionary ready for database insertion
        """
        prepared = {}
        
        for key, value in data.items():
            if isinstance(value, BaseModel):
                if handle_nested:
                    prepared[key] = DataTransformationService.model_to_dict_with_nested(
                        value, exclude_none=True
                    )
                else:
                    prepared[key] = DataTransformationService.model_to_dict(
                        value, exclude_none=True
                    )
            elif isinstance(value, list):
                prepared[key] = [
                    DataTransformationService.model_to_dict(item, exclude_none=True)
                    if isinstance(item, BaseModel)
                    else item
                    for item in value
                ]
            elif value is not None:
                prepared[key] = value
        
        return prepared
    
    @staticmethod
    def json_serialize_nested(obj: Any) -> Any:
        """
        Recursively serialize nested objects to JSON-serializable format
        
        Args:
            obj: Object to serialize
            
        Returns:
            JSON-serializable representation
        """
        if isinstance(obj, BaseModel):
            return obj.model_dump()
        elif isinstance(obj, dict):
            return {
                key: DataTransformationService.json_serialize_nested(value)
                for key, value in obj.items()
            }
        elif isinstance(obj, list):
            return [
                DataTransformationService.json_serialize_nested(item)
                for item in obj
            ]
        elif hasattr(obj, 'isoformat'):  # datetime objects
            return obj.isoformat()
        else:
            return obj

