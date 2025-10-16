"""
Health Event Service

Handles all database operations for health events including CRUD operations,
data validation, and business logic.
"""

from typing import List, Optional
from uuid import UUID
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import and_, desc

from app.models.health_event import (
    HealthEvent,
    HealthEventCreate,
    HealthEventUpdate,
    HealthEventResponse,
    HealthEventListResponse
)
from app.database import get_db


class HealthEventService:
    """Service class for health event operations"""
    
    @staticmethod
    async def create_health_event(
        health_event_create: HealthEventCreate,
        user_id: UUID,
        db: Session
    ) -> HealthEvent:
        """Create a new health event"""
        
        # Create the health event record
        db_health_event = HealthEvent(
            pet_id=health_event_create.pet_id,
            user_id=user_id,
            event_type=health_event_create.event_type,
            event_category=health_event_create.event_category,
            title=health_event_create.title,
            notes=health_event_create.notes,
            severity_level=health_event_create.severity_level,
            event_date=health_event_create.event_date,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        db.add(db_health_event)
        db.commit()
        db.refresh(db_health_event)
        
        return db_health_event
    
    @staticmethod
    async def get_health_event_by_id(
        event_id: UUID,
        user_id: UUID,
        db: Session
    ) -> Optional[HealthEvent]:
        """Get a specific health event by ID"""
        
        return db.query(HealthEvent).filter(
            and_(
                HealthEvent.id == event_id,
                HealthEvent.user_id == user_id
            )
        ).first()
    
    @staticmethod
    async def get_health_events_for_pet(
        pet_id: UUID,
        user_id: UUID,
        db: Session,
        limit: int = 50,
        offset: int = 0
    ) -> List[HealthEvent]:
        """Get all health events for a specific pet"""
        
        return db.query(HealthEvent).filter(
            and_(
                HealthEvent.pet_id == pet_id,
                HealthEvent.user_id == user_id
            )
        ).order_by(desc(HealthEvent.event_date)).limit(limit).offset(offset).all()
    
    @staticmethod
    async def get_health_events_by_category(
        pet_id: UUID,
        category: str,
        user_id: UUID,
        db: Session,
        limit: int = 50,
        offset: int = 0
    ) -> List[HealthEvent]:
        """Get health events for a pet filtered by category"""
        
        return db.query(HealthEvent).filter(
            and_(
                HealthEvent.pet_id == pet_id,
                HealthEvent.user_id == user_id,
                HealthEvent.event_category == category
            )
        ).order_by(desc(HealthEvent.event_date)).limit(limit).offset(offset).all()
    
    @staticmethod
    async def update_health_event(
        event_id: UUID,
        health_event_update: HealthEventUpdate,
        user_id: UUID,
        db: Session
    ) -> Optional[HealthEvent]:
        """Update an existing health event"""
        
        db_health_event = await HealthEventService.get_health_event_by_id(
            event_id, user_id, db
        )
        
        if not db_health_event:
            return None
        
        # Update only provided fields
        update_data = health_event_update.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_health_event, field, value)
        
        db_health_event.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(db_health_event)
        
        return db_health_event
    
    @staticmethod
    async def delete_health_event(
        event_id: UUID,
        user_id: UUID,
        db: Session
    ) -> bool:
        """Delete a health event"""
        
        db_health_event = await HealthEventService.get_health_event_by_id(
            event_id, user_id, db
        )
        
        if not db_health_event:
            return False
        
        db.delete(db_health_event)
        db.commit()
        
        return True
    
    @staticmethod
    async def get_health_events_count_for_pet(
        pet_id: UUID,
        user_id: UUID,
        db: Session
    ) -> int:
        """Get total count of health events for a pet"""
        
        return db.query(HealthEvent).filter(
            and_(
                HealthEvent.pet_id == pet_id,
                HealthEvent.user_id == user_id
            )
        ).count()
    
    @staticmethod
    async def get_recent_health_events(
        user_id: UUID,
        db: Session,
        limit: int = 10
    ) -> List[HealthEvent]:
        """Get recent health events across all user's pets"""
        
        return db.query(HealthEvent).filter(
            HealthEvent.user_id == user_id
        ).order_by(desc(HealthEvent.event_date)).limit(limit).all()
    
    @staticmethod
    async def get_health_events_by_date_range(
        pet_id: UUID,
        user_id: UUID,
        start_date: datetime,
        end_date: datetime,
        db: Session
    ) -> List[HealthEvent]:
        """Get health events within a date range"""
        
        return db.query(HealthEvent).filter(
            and_(
                HealthEvent.pet_id == pet_id,
                HealthEvent.user_id == user_id,
                HealthEvent.event_date >= start_date,
                HealthEvent.event_date <= end_date
            )
        ).order_by(desc(HealthEvent.event_date)).all()
    
    @staticmethod
    async def get_health_events_by_severity(
        pet_id: UUID,
        user_id: UUID,
        min_severity: int,
        db: Session
    ) -> List[HealthEvent]:
        """Get health events with severity level >= min_severity"""
        
        return db.query(HealthEvent).filter(
            and_(
                HealthEvent.pet_id == pet_id,
                HealthEvent.user_id == user_id,
                HealthEvent.severity_level >= min_severity
            )
        ).order_by(desc(HealthEvent.event_date)).all()
