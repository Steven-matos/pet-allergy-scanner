"""
Extended validation service

This is the SINGLE SOURCE OF TRUTH for:
1. Domain-specific validation logic
2. Pet-specific validations
3. Species-specific validation rules

All domain-specific validations should use this service for consistency.
"""

from typing import Optional
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)


class ValidationService:
    """
    Extended validation service for domain-specific validations
    
    This ensures:
    - Consistent validation logic across the application
    - Centralized domain-specific rules
    - Easier maintenance of validation rules
    """
    
    @staticmethod
    def validate_pet_weight(
        species: str,
        weight_kg: Optional[float],
        raise_exception: bool = True
    ) -> bool:
        """
        Validate pet weight based on species
        
        Validation rules:
        - Cats: weight should not exceed 15 kg
        - Dogs: weight should not exceed 100 kg
        
        Args:
            species: Pet species ("cat" or "dog")
            weight_kg: Weight in kilograms
            raise_exception: Whether to raise HTTPException on validation failure
            
        Returns:
            True if validation passes, False otherwise (if raise_exception=False)
            
        Raises:
            HTTPException: If validation fails and raise_exception=True
        """
        if weight_kg is None:
            return True
        
        if species == "cat" and weight_kg > 15:
            if raise_exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cat weight seems unusually high. Please verify the weight."
                )
            return False
        
        if species == "dog" and weight_kg > 100:
            if raise_exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Dog weight seems unusually high. Please verify the weight."
                )
            return False
        
        return True
    
    @staticmethod
    def validate_positive_number(
        value: Optional[float],
        field_name: str,
        raise_exception: bool = True
    ) -> bool:
        """
        Validate that a number is positive (greater than 0)
        
        Args:
            value: Number to validate
            field_name: Name of the field for error messages
            raise_exception: Whether to raise HTTPException on validation failure
            
        Returns:
            True if validation passes, False otherwise (if raise_exception=False)
            
        Raises:
            HTTPException: If validation fails and raise_exception=True
        """
        if value is None:
            return True
        
        if value <= 0:
            if raise_exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"{field_name} must be greater than 0"
                )
            return False
        
        return True
    
    @staticmethod
    def validate_non_negative_number(
        value: Optional[float],
        field_name: str,
        raise_exception: bool = True
    ) -> bool:
        """
        Validate that a number is non-negative (greater than or equal to 0)
        
        Args:
            value: Number to validate
            field_name: Name of the field for error messages
            raise_exception: Whether to raise HTTPException on validation failure
            
        Returns:
            True if validation passes, False otherwise (if raise_exception=False)
            
        Raises:
            HTTPException: If validation fails and raise_exception=True
        """
        if value is None:
            return True
        
        if value < 0:
            if raise_exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"{field_name} must be greater than or equal to 0"
                )
            return False
        
        return True
    
    @staticmethod
    def validate_range(
        value: Optional[float],
        field_name: str,
        min_value: Optional[float] = None,
        max_value: Optional[float] = None,
        raise_exception: bool = True
    ) -> bool:
        """
        Validate that a number is within a specified range
        
        Args:
            value: Number to validate
            field_name: Name of the field for error messages
            min_value: Minimum allowed value (None for no minimum)
            max_value: Maximum allowed value (None for no maximum)
            raise_exception: Whether to raise HTTPException on validation failure
            
        Returns:
            True if validation passes, False otherwise (if raise_exception=False)
            
        Raises:
            HTTPException: If validation fails and raise_exception=True
        """
        if value is None:
            return True
        
        if min_value is not None and value < min_value:
            if raise_exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"{field_name} must be at least {min_value}"
                )
            return False
        
        if max_value is not None and value > max_value:
            if raise_exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"{field_name} must be at most {max_value}"
                )
            return False
        
        return True

