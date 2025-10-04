"""
Nutrition router for handling pet nutrition-related endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
import uuid

from ..database import get_db
from ..models.nutrition import (
    NutritionalRequirementsCreate,
    NutritionalRequirementsResponse,
    FoodAnalysisCreate,
    FoodAnalysisResponse,
    NutritionCompatibilityResponse,
    FeedingRecordCreate,
    FeedingRecordResponse,
    DailyNutritionSummaryResponse,
    MultiPetNutritionInsights,
    NutritionAnalysisRequest,
    NutritionRecommendation,
    NutritionGoal,
    NutritionCompatibilityLevel
)
from ..models.pet import PetResponse
from ..models.user import UserResponse
from ..utils.security import get_current_user
from ..utils.error_handling import create_error_response, APIError

router = APIRouter(prefix="/nutrition", tags=["nutrition"])

@router.post("/requirements", response_model=NutritionalRequirementsResponse)
async def create_nutritional_requirements(
    requirements: NutritionalRequirementsCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create or update nutritional requirements for a pet
    
    Args:
        requirements: Nutritional requirements data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Created nutritional requirements
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == requirements.pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Check if requirements already exist
        existing = db.query(NutritionalRequirementsResponse).filter(
            NutritionalRequirementsResponse.pet_id == requirements.pet_id
        ).first()
        
        if existing:
            # Update existing requirements
            for field, value in requirements.dict(exclude_unset=True).items():
                setattr(existing, field, value)
            existing.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(existing)
            return existing
        else:
            # Create new requirements
            db_requirements = NutritionalRequirementsResponse(
                **requirements.dict(),
                id=str(uuid.uuid4()),
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            db.add(db_requirements)
            db.commit()
            db.refresh(db_requirements)
            return db_requirements
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/requirements/{pet_id}", response_model=NutritionalRequirementsResponse)
async def get_nutritional_requirements(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get nutritional requirements for a specific pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Nutritional requirements for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Get requirements
        requirements = db.query(NutritionalRequirementsResponse).filter(
            NutritionalRequirementsResponse.pet_id == pet_id
        ).first()
        
        if not requirements:
            raise HTTPException(status_code=404, detail="Nutritional requirements not found")
        
        return requirements
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.post("/analyze", response_model=FoodAnalysisResponse)
async def analyze_food(
    request: NutritionAnalysisRequest,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Analyze nutritional content of pet food
    
    Args:
        request: Food analysis request
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Food nutritional analysis
        
    Raises:
        HTTPException: If analysis fails or pet not found
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == request.pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Analyze food (simplified - in production, this would use AI/ML)
        analysis_data = await _analyze_food_nutrition(request)
        
        # Create food analysis record
        food_analysis = FoodAnalysisResponse(
            id=str(uuid.uuid4()),
            **analysis_data,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        db.add(food_analysis)
        db.commit()
        db.refresh(food_analysis)
        
        return food_analysis
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/analyses/{pet_id}", response_model=List[FoodAnalysisResponse])
async def get_food_analyses(
    pet_id: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get food analyses for a specific pet
    
    Args:
        pet_id: Pet ID
        limit: Maximum number of results
        offset: Number of results to skip
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of food analyses for the pet
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Get analyses
        analyses = db.query(FoodAnalysisResponse).filter(
            FoodAnalysisResponse.pet_id == pet_id
        ).order_by(FoodAnalysisResponse.analyzed_at.desc()).offset(offset).limit(limit).all()
        
        return analyses
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.post("/compatibility", response_model=NutritionCompatibilityResponse)
async def assess_nutrition_compatibility(
    food_analysis_id: str,
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Assess compatibility between food and pet nutritional requirements
    
    Args:
        food_analysis_id: Food analysis ID
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Nutrition compatibility assessment
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Get food analysis
        food_analysis = db.query(FoodAnalysisResponse).filter(
            FoodAnalysisResponse.id == food_analysis_id
        ).first()
        
        if not food_analysis:
            raise HTTPException(status_code=404, detail="Food analysis not found")
        
        # Get nutritional requirements
        requirements = db.query(NutritionalRequirementsResponse).filter(
            NutritionalRequirementsResponse.pet_id == pet_id
        ).first()
        
        if not requirements:
            raise HTTPException(status_code=404, detail="Nutritional requirements not found")
        
        # Assess compatibility
        compatibility = await _assess_compatibility(food_analysis, requirements)
        
        return compatibility
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.post("/feeding", response_model=FeedingRecordResponse)
async def record_feeding(
    feeding: FeedingRecordCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Record a feeding instance
    
    Args:
        feeding: Feeding record data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Created feeding record
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == feeding.pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Verify food analysis exists
        food_analysis = db.query(FoodAnalysisResponse).filter(
            FoodAnalysisResponse.id == feeding.food_analysis_id
        ).first()
        
        if not food_analysis:
            raise HTTPException(status_code=404, detail="Food analysis not found")
        
        # Create feeding record
        feeding_record = FeedingRecordResponse(
            id=str(uuid.uuid4()),
            **feeding.dict(),
            created_at=datetime.utcnow()
        )
        
        db.add(feeding_record)
        db.commit()
        db.refresh(feeding_record)
        
        # Update daily summary
        await _update_daily_summary(feeding.pet_id, feeding.feeding_time.date(), db)
        
        return feeding_record
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/feeding/{pet_id}", response_model=List[FeedingRecordResponse])
async def get_feeding_records(
    pet_id: str,
    days: int = Query(30, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get feeding records for a specific pet
    
    Args:
        pet_id: Pet ID
        days: Number of days to retrieve
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of feeding records
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Calculate date range
        end_date = datetime.utcnow()
        start_date = end_date - timedelta(days=days)
        
        # Get feeding records
        records = db.query(FeedingRecordResponse).filter(
            FeedingRecordResponse.pet_id == pet_id,
            FeedingRecordResponse.feeding_time >= start_date,
            FeedingRecordResponse.feeding_time <= end_date
        ).order_by(FeedingRecordResponse.feeding_time.desc()).all()
        
        return records
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/summaries/{pet_id}", response_model=List[DailyNutritionSummaryResponse])
async def get_daily_summaries(
    pet_id: str,
    days: int = Query(30, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get daily nutrition summaries for a specific pet
    
    Args:
        pet_id: Pet ID
        days: Number of days to retrieve
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of daily nutrition summaries
    """
    try:
        # Verify pet ownership
        pet = db.query(PetResponse).filter(
            PetResponse.id == pet_id,
            PetResponse.user_id == current_user.id
        ).first()
        
        if not pet:
            raise HTTPException(status_code=404, detail="Pet not found")
        
        # Calculate date range
        end_date = date.today()
        start_date = end_date - timedelta(days=days)
        
        # Get summaries
        summaries = db.query(DailyNutritionSummaryResponse).filter(
            DailyNutritionSummaryResponse.pet_id == pet_id,
            DailyNutritionSummaryResponse.date >= start_date,
            DailyNutritionSummaryResponse.date <= end_date
        ).order_by(DailyNutritionSummaryResponse.date.desc()).all()
        
        return summaries
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@router.get("/insights/multi-pet", response_model=MultiPetNutritionInsights)
async def get_multi_pet_insights(
    pet_ids: List[str] = Query(...),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get nutrition insights for multiple pets (Premium feature)
    
    Args:
        pet_ids: List of pet IDs
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Multi-pet nutrition insights
        
    Raises:
        HTTPException: If user not premium or pets not found
    """
    try:
        # Check if user has premium access
        if current_user.role != "premium":
            raise HTTPException(
                status_code=403, 
                detail="Premium subscription required for multi-pet nutrition insights"
            )
        
        # Verify pet ownership
        pets = db.query(PetResponse).filter(
            PetResponse.id.in_(pet_ids),
            PetResponse.user_id == current_user.id
        ).all()
        
        if len(pets) != len(pet_ids):
            raise HTTPException(status_code=404, detail="Some pets not found")
        
        # Get insights for all pets
        insights = await _generate_multi_pet_insights(pets, db)
        
        return insights
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# Helper functions

async def _analyze_food_nutrition(request: NutritionAnalysisRequest) -> dict:
    """
    Analyze food nutrition (simplified implementation)
    In production, this would use AI/ML models
    """
    # Default nutritional values (would be calculated by AI in production)
    default_nutrition = {
        "calories_per_100g": 350.0,
        "protein_percentage": 25.0,
        "fat_percentage": 12.0,
        "fiber_percentage": 4.0,
        "moisture_percentage": 10.0
    }
    
    # Use provided nutritional info if available
    if request.nutritional_info:
        nutrition = request.nutritional_info.dict(exclude_none=True)
        for key, value in nutrition.items():
            default_nutrition[key] = value
    
    # Analyze ingredients for allergens (simplified)
    allergens = []
    common_allergens = ["chicken", "beef", "soy", "wheat", "corn", "dairy"]
    for ingredient in request.ingredients:
        for allergen in common_allergens:
            if allergen.lower() in ingredient.lower():
                allergens.append(allergen)
    
    return {
        "pet_id": request.pet_id,
        "food_name": request.food_name,
        "brand": request.brand,
        "ingredients": request.ingredients,
        "allergens": allergens,
        "analyzed_at": datetime.utcnow(),
        **default_nutrition
    }

async def _assess_compatibility(
    food_analysis: FoodAnalysisResponse,
    requirements: NutritionalRequirementsResponse
) -> NutritionCompatibilityResponse:
    """
    Assess compatibility between food and requirements
    """
    score = 0.0
    issues = []
    recommendations = []
    
    # Check protein content
    if food_analysis.protein_percentage >= requirements.protein_percentage:
        score += 25
    else:
        issues.append(f"Protein content ({food_analysis.protein_percentage:.1f}%) is below recommended ({requirements.protein_percentage:.1f}%)")
        recommendations.append("Consider adding protein-rich supplements")
    
    # Check fat content
    fat_range_min = requirements.fat_percentage * 0.8
    fat_range_max = requirements.fat_percentage * 1.2
    if fat_range_min <= food_analysis.fat_percentage <= fat_range_max:
        score += 25
    else:
        issues.append(f"Fat content ({food_analysis.fat_percentage:.1f}%) is outside optimal range")
        recommendations.append("Monitor your pet's weight and adjust portions accordingly")
    
    # Check fiber content
    fiber_range_min = requirements.fiber_percentage * 0.5
    fiber_range_max = requirements.fiber_percentage * 2.0
    if fiber_range_min <= food_analysis.fiber_percentage <= fiber_range_max:
        score += 25
    else:
        issues.append(f"Fiber content ({food_analysis.fiber_percentage:.1f}%) is outside optimal range")
        recommendations.append("Consider adjusting fiber intake based on digestive health")
    
    # Check for allergens
    if food_analysis.allergens:
        score -= 20
        issues.append(f"Contains potential allergens: {', '.join(food_analysis.allergens)}")
        recommendations.append("Monitor your pet for allergic reactions")
    else:
        score += 25
    
    # Determine compatibility level
    if score >= 90:
        compatibility = NutritionCompatibilityLevel.EXCELLENT
    elif score >= 70:
        compatibility = NutritionCompatibilityLevel.GOOD
    elif score >= 50:
        compatibility = NutritionCompatibilityLevel.FAIR
    else:
        compatibility = NutritionCompatibilityLevel.POOR
    
    return NutritionCompatibilityResponse(
        food_analysis=food_analysis,
        requirements=requirements,
        compatibility=compatibility,
        score=score,
        issues=issues,
        recommendations=recommendations,
        assessed_at=datetime.utcnow()
    )

async def _update_daily_summary(pet_id: str, date: date, db: Session):
    """
    Update daily nutrition summary for a pet
    """
    # Get feeding records for the day
    start_datetime = datetime.combine(date, datetime.min.time())
    end_datetime = datetime.combine(date, datetime.max.time())
    
    records = db.query(FeedingRecordResponse).filter(
        FeedingRecordResponse.pet_id == pet_id,
        FeedingRecordResponse.feeding_time >= start_datetime,
        FeedingRecordResponse.feeding_time <= end_datetime
    ).all()
    
    # Calculate totals
    total_calories = 0.0
    total_protein = 0.0
    total_fat = 0.0
    total_fiber = 0.0
    compatibility_scores = []
    
    for record in records:
        # Get food analysis
        food_analysis = db.query(FoodAnalysisResponse).filter(
            FoodAnalysisResponse.id == record.food_analysis_id
        ).first()
        
        if food_analysis:
            # Calculate calories consumed
            calories_consumed = (food_analysis.calories_per_100g / 100.0) * record.amount_grams
            total_calories += calories_consumed
            
            # Calculate macronutrients
            total_protein += (food_analysis.protein_percentage / 100.0) * record.amount_grams
            total_fat += (food_analysis.fat_percentage / 100.0) * record.amount_grams
            total_fiber += (food_analysis.fiber_percentage / 100.0) * record.amount_grams
            
            # Get compatibility score if available
            # (This would require storing compatibility assessments)
    
    average_compatibility = sum(compatibility_scores) / len(compatibility_scores) if compatibility_scores else 0.0
    
    # Create or update daily summary
    summary = DailyNutritionSummaryResponse(
        id=str(uuid.uuid4()),
        pet_id=pet_id,
        date=date,
        total_calories=total_calories,
        total_protein=total_protein,
        total_fat=total_fat,
        total_fiber=total_fiber,
        feeding_count=len(records),
        average_compatibility=average_compatibility,
        recommendations=[],
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    
    # Check if summary already exists
    existing = db.query(DailyNutritionSummaryResponse).filter(
        DailyNutritionSummaryResponse.pet_id == pet_id,
        DailyNutritionSummaryResponse.date == date
    ).first()
    
    if existing:
        # Update existing
        for field, value in summary.dict(exclude={'id', 'created_at'}).items():
            setattr(existing, field, value)
        existing.updated_at = datetime.utcnow()
        db.commit()
    else:
        # Create new
        db.add(summary)
        db.commit()

async def _generate_multi_pet_insights(pets: List[PetResponse], db: Session) -> MultiPetNutritionInsights:
    """
    Generate multi-pet nutrition insights
    """
    insights = MultiPetNutritionInsights(
        pets=[pet.dict() for pet in pets],
        generated_at=datetime.utcnow()
    )
    
    # Get requirements for all pets
    for pet in pets:
        requirements = db.query(NutritionalRequirementsResponse).filter(
            NutritionalRequirementsResponse.pet_id == pet.id
        ).first()
        
        if requirements:
            insights.requirements[pet.id] = requirements
    
    # Get recent summaries for all pets
    end_date = date.today()
    start_date = end_date - timedelta(days=7)
    
    for pet in pets:
        summaries = db.query(DailyNutritionSummaryResponse).filter(
            DailyNutritionSummaryResponse.pet_id == pet.id,
            DailyNutritionSummaryResponse.date >= start_date,
            DailyNutritionSummaryResponse.date <= end_date
        ).all()
        
        insights.recent_summaries[pet.id] = summaries
    
    # Generate comparative insights
    insights.comparative_insights = await _generate_comparative_insights(insights)
    
    return insights

async def _generate_comparative_insights(insights: MultiPetNutritionInsights) -> List[dict]:
    """
    Generate comparative insights across multiple pets
    """
    comparative_insights = []
    
    # Compare calorie requirements
    calorie_requirements = [req.daily_calories for req in insights.requirements.values()]
    if calorie_requirements:
        max_calories = max(calorie_requirements)
        min_calories = min(calorie_requirements)
        
        if max_calories > min_calories * 1.5:
            comparative_insights.append({
                "type": "calorie_range",
                "title": "Calorie Requirements Vary Significantly",
                "description": "Your pets have very different calorie needs. Consider feeding schedules accordingly.",
                "severity": "medium"
            })
    
    # Compare recent nutrition trends
    all_summaries = []
    for summaries in insights.recent_summaries.values():
        all_summaries.extend(summaries)
    
    if all_summaries:
        avg_compatibility = sum(s.average_compatibility for s in all_summaries) / len(all_summaries)
        
        if avg_compatibility < 70:
            comparative_insights.append({
                "type": "nutrition_quality",
                "title": "Nutrition Quality Could Improve",
                "description": "Consider reviewing your pets' current food choices for better nutritional balance.",
                "severity": "high"
            })
    
    return comparative_insights
