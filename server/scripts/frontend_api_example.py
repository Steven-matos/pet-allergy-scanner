#!/usr/bin/env python3
"""
Frontend API Example for Pet Food Data
Shows how to create API endpoints that return consistent, English-only data.
"""

from fastapi import FastAPI, HTTPException, Query
from typing import List, Optional, Dict, Any
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from dotenv import load_dotenv
from frontend_data_parser import FoodItemParser, ParsedFoodItem

# Load environment variables
load_dotenv()

app = FastAPI(title="Pet Food API", version="1.0.0")

class FoodItemAPI:
    """API service for pet food items with consistent frontend formatting."""
    
    def __init__(self):
        self.database_url = os.getenv('DATABASE_URL')
        self.parser = FoodItemParser()
        
        if not self.database_url:
            raise ValueError("DATABASE_URL not found in environment variables")
    
    def get_connection(self):
        """Get database connection."""
        return psycopg2.connect(self.database_url, cursor_factory=RealDictCursor)
    
    async def search_food_items(
        self,
        query: Optional[str] = None,
        species: Optional[str] = None,
        life_stage: Optional[str] = None,
        product_type: Optional[str] = None,
        brand: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> Dict[str, Any]:
        """
        Search pet food items with English-only filtering.
        
        Args:
            query: Search term for product name
            species: Filter by species (dog, cat)
            life_stage: Filter by life stage (puppy, adult, senior)
            product_type: Filter by product type (dry, wet, treat)
            brand: Filter by brand
            limit: Maximum number of results
            offset: Offset for pagination
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        
        try:
            # Build WHERE clause
            where_conditions = ["language = 'en'", "data_completeness >= 0.3"]
            params = []
            
            if query:
                where_conditions.append("(name ILIKE %s OR brand ILIKE %s)")
                search_term = f"%{query}%"
                params.extend([search_term, search_term])
            
            if species:
                where_conditions.append("species = %s")
                params.append(species)
            
            if life_stage:
                where_conditions.append("life_stage = %s")
                params.append(life_stage)
            
            if product_type:
                where_conditions.append("product_type = %s")
                params.append(product_type)
            
            if brand:
                where_conditions.append("brand ILIKE %s")
                params.append(f"%{brand}%")
            
            where_clause = " AND ".join(where_conditions)
            
            # Get total count
            count_query = f"""
                SELECT COUNT(*) as total
                FROM public.food_items 
                WHERE {where_clause}
            """
            cursor.execute(count_query, params)
            total = cursor.fetchone()['total']
            
            # Get results
            search_query = f"""
                SELECT 
                    id, name, brand, barcode, category, species, life_stage, product_type,
                    quantity, country, image_url, ingredients_hierarchy, allergens_hierarchy,
                    nutritional_info, data_completeness, language
                FROM public.food_items 
                WHERE {where_clause}
                ORDER BY data_completeness DESC, name ASC
                LIMIT %s OFFSET %s
            """
            params.extend([limit, offset])
            cursor.execute(search_query, params)
            
            results = []
            for row in cursor.fetchall():
                # Convert to dict
                raw_data = dict(row)
                
                # Parse using our parser
                parsed_item = self.parser.parse_food_item(raw_data)
                if parsed_item:
                    frontend_data = self.parser.to_frontend_format(parsed_item)
                    results.append(frontend_data)
            
            return {
                "data": results,
                "total": total,
                "limit": limit,
                "offset": offset,
                "has_more": (offset + limit) < total
            }
        
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            cursor.close()
            conn.close()
    
    async def get_food_item_by_barcode(self, barcode: str) -> Dict[str, Any]:
        """Get specific food item by barcode."""
        conn = self.get_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute("""
                SELECT 
                    id, name, brand, barcode, category, species, life_stage, product_type,
                    quantity, country, image_url, ingredients_hierarchy, allergens_hierarchy,
                    nutritional_info, data_completeness, language
                FROM public.food_items 
                WHERE barcode = %s AND language = 'en'
            """, (barcode,))
            
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Food item not found")
            
            # Parse using our parser
            raw_data = dict(row)
            parsed_item = self.parser.parse_food_item(raw_data)
            
            if not parsed_item:
                raise HTTPException(status_code=500, detail="Error parsing food item")
            
            return self.parser.to_frontend_format(parsed_item)
        
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            cursor.close()
            conn.close()
    
    async def get_ingredient_analysis(self, ingredients: List[str]) -> Dict[str, Any]:
        """Analyze ingredients for allergens and safety."""
        parsed_ingredients = []
        allergens_found = []
        
        for ingredient in ingredients:
            parsed = self.parser.parse_ingredient(ingredient)
            parsed_ingredients.append({
                "name": parsed.name,
                "percentage": parsed.percentage,
                "is_allergen": parsed.is_allergen
            })
            
            if parsed.is_allergen:
                allergens_found.append(parsed.name)
        
        return {
            "ingredients": parsed_ingredients,
            "allergens_found": allergens_found,
            "total_ingredients": len(parsed_ingredients),
            "allergen_count": len(allergens_found),
            "safety_score": max(0, 1.0 - (len(allergens_found) / len(parsed_ingredients))) if parsed_ingredients else 1.0
        }

# Initialize API service
api_service = FoodItemAPI()

@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "message": "Pet Food API",
        "version": "1.0.0",
        "description": "API for pet food data with English-only filtering and consistent parsing"
    }

@app.get("/food-items/search")
async def search_food_items(
    q: Optional[str] = Query(None, description="Search query for product name or brand"),
    species: Optional[str] = Query(None, description="Filter by species (dog, cat)"),
    life_stage: Optional[str] = Query(None, description="Filter by life stage (puppy, adult, senior)"),
    product_type: Optional[str] = Query(None, description="Filter by product type (dry, wet, treat)"),
    brand: Optional[str] = Query(None, description="Filter by brand"),
    limit: int = Query(50, ge=1, le=100, description="Maximum number of results"),
    offset: int = Query(0, ge=0, description="Offset for pagination")
):
    """Search pet food items with filtering and pagination."""
    return await api_service.search_food_items(
        query=q,
        species=species,
        life_stage=life_stage,
        product_type=product_type,
        brand=brand,
        limit=limit,
        offset=offset
    )

@app.get("/food-items/barcode/{barcode}")
async def get_food_item_by_barcode(barcode: str):
    """Get specific food item by barcode."""
    return await api_service.get_food_item_by_barcode(barcode)

@app.post("/ingredients/analyze")
async def analyze_ingredients(ingredients: List[str]):
    """Analyze ingredients for allergens and safety."""
    return await api_service.get_ingredient_analysis(ingredients)

@app.get("/stats")
async def get_stats():
    """Get database statistics."""
    conn = api_service.get_connection()
    cursor = conn.cursor()
    
    try:
        # Get total counts
        cursor.execute("SELECT COUNT(*) as total FROM public.food_items WHERE language = 'en'")
        total_english = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(*) as total FROM public.food_items WHERE language != 'en'")
        total_non_english = cursor.fetchone()['total']
        
        cursor.execute("""
            SELECT 
                species, 
                COUNT(*) as count 
            FROM public.food_items 
            WHERE language = 'en' 
            GROUP BY species
        """)
        species_distribution = {row['species']: row['count'] for row in cursor.fetchall()}
        
        cursor.execute("""
            SELECT 
                AVG(data_completeness) as avg_quality,
                MIN(data_completeness) as min_quality,
                MAX(data_completeness) as max_quality
            FROM public.food_items 
            WHERE language = 'en'
        """)
        quality_stats = cursor.fetchone()
        
        return {
            "total_english_products": total_english,
            "total_non_english_products": total_non_english,
            "species_distribution": species_distribution,
            "quality_stats": {
                "average": float(quality_stats['avg_quality']) if quality_stats['avg_quality'] else 0,
                "minimum": float(quality_stats['min_quality']) if quality_stats['min_quality'] else 0,
                "maximum": float(quality_stats['max_quality']) if quality_stats['max_quality'] else 0
            }
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
