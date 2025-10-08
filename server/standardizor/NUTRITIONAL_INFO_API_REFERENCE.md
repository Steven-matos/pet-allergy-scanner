# Nutritional Info API Reference

## Overview

This document provides a complete reference for the `nutritional_info` JSONB field structure in the `food_items` table. After running the standardization script, **every record** will have this exact structure with appropriate default values.

## 📊 Data Structure

### Complete Field List

Every `nutritional_info` object contains exactly **22 properties** with the following structure:

```typescript
interface NutritionalInfo {
  // Nutritional Values (numbers or null)
  calories_per_100g: number | null;
  protein_percentage: number | null;
  fat_percentage: number | null;
  fiber_percentage: number | null;
  moisture_percentage: number | null;
  ash_percentage: number | null;
  carbohydrates_percentage: number | null;
  sugars_percentage: number | null;
  saturated_fat_percentage: number | null;
  sodium_percentage: number | null;
  
  // Arrays (empty arrays if missing)
  ingredients: string[];
  allergens: string[];
  additives: string[];
  vitamins: string[];
  minerals: string[];
  
  // Strings (empty strings if missing)
  source: string;
  external_id: string;
  data_quality_score: number;
  last_updated: string;
  
  // Objects (empty objects if missing)
  nutrient_levels: Record<string, any>;
  packaging_info: Record<string, any>;
  manufacturing_info: Record<string, any>;
}
```

## 🔍 Field Descriptions

### Nutritional Values
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `calories_per_100g` | `number \| null` | Calories per 100g of product | `350.5` |
| `protein_percentage` | `number \| null` | Protein content as percentage | `25.0` |
| `fat_percentage` | `number \| null` | Fat content as percentage | `12.5` |
| `fiber_percentage` | `number \| null` | Fiber content as percentage | `4.0` |
| `moisture_percentage` | `number \| null` | Moisture content as percentage | `10.0` |
| `ash_percentage` | `number \| null` | Ash content as percentage | `8.0` |
| `carbohydrates_percentage` | `number \| null` | Carbohydrates as percentage | `40.5` |
| `sugars_percentage` | `number \| null` | Sugars as percentage | `2.0` |
| `saturated_fat_percentage` | `number \| null` | Saturated fat as percentage | `3.5` |
| `sodium_percentage` | `number \| null` | Sodium content as percentage | `0.8` |

### Arrays
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `ingredients` | `string[]` | List of ingredients | `["Chicken", "Rice", "Corn"]` |
| `allergens` | `string[]` | List of allergens | `["Chicken", "Corn"]` |
| `additives` | `string[]` | List of food additives | `["Vitamin A", "Vitamin D"]` |
| `vitamins` | `string[]` | List of vitamins | `["Vitamin A", "Vitamin D", "Vitamin E"]` |
| `minerals` | `string[]` | List of minerals | `["Calcium", "Phosphorus", "Iron"]` |

### Metadata
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `source` | `string` | Data source identifier | `"openpetfoodfacts"` |
| `external_id` | `string` | External system ID | `"1234567890"` |
| `data_quality_score` | `number` | Data completeness score (0-1) | `0.85` |
| `last_updated` | `string` | Last update timestamp | `"2025-01-07"` |

### Objects
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `nutrient_levels` | `object` | Nutrient level classifications | `{"fat": "low", "salt": "low"}` |
| `packaging_info` | `object` | Packaging details | `{"material": "plastic", "recyclable": true}` |
| `manufacturing_info` | `object` | Manufacturing details | `{"country": "USA", "brand": "Hill's"}` |

## 🎯 Default Values

### Missing Data Handling
- **Numbers**: `null` when data is missing
- **Arrays**: `[]` (empty array) when data is missing
- **Strings**: `""` (empty string) when data is missing
- **Objects**: `{}` (empty object) when data is missing

### Example with Missing Data
```json
{
  "calories_per_100g": null,
  "protein_percentage": null,
  "fat_percentage": null,
  "fiber_percentage": null,
  "moisture_percentage": null,
  "ash_percentage": null,
  "carbohydrates_percentage": null,
  "sugars_percentage": null,
  "saturated_fat_percentage": null,
  "sodium_percentage": null,
  "ingredients": [],
  "allergens": [],
  "additives": [],
  "vitamins": [],
  "minerals": [],
  "source": "",
  "external_id": "",
  "data_quality_score": 0.0,
  "last_updated": "",
  "nutrient_levels": {},
  "packaging_info": {},
  "manufacturing_info": {}
}
```

## 📝 Frontend Usage Examples

### React/TypeScript Example
```typescript
interface FoodItem {
  id: string;
  name: string;
  brand: string;
  nutritional_info: NutritionalInfo;
}

const FoodItemCard: React.FC<{ item: FoodItem }> = ({ item }) => {
  const { nutritional_info } = item;
  
  return (
    <div className="food-item">
      <h3>{item.name}</h3>
      <p>Brand: {item.brand}</p>
      
      {/* Safe access - no null reference errors */}
      <div className="nutrition">
        <p>Calories: {nutritional_info.calories_per_100g || 'N/A'} kcal/100g</p>
        <p>Protein: {nutritional_info.protein_percentage || 'N/A'}%</p>
        <p>Fat: {nutritional_info.fat_percentage || 'N/A'}%</p>
      </div>
      
      {/* Safe array access */}
      <div className="ingredients">
        <h4>Ingredients:</h4>
        <ul>
          {nutritional_info.ingredients.map((ingredient, index) => (
            <li key={index}>{ingredient}</li>
          ))}
        </ul>
      </div>
      
      {/* Safe object access */}
      <div className="allergens">
        <h4>Allergens:</h4>
        {nutritional_info.allergens.length > 0 ? (
          <ul>
            {nutritional_info.allergens.map((allergen, index) => (
              <li key={index}>{allergen}</li>
            ))}
          </ul>
        ) : (
          <p>No allergens listed</p>
        )}
      </div>
    </div>
  );
};
```

### JavaScript Example
```javascript
// Safe data access patterns
function displayNutritionalInfo(nutritionalInfo) {
  // Numbers - use nullish coalescing
  const calories = nutritionalInfo.calories_per_100g ?? 'N/A';
  const protein = nutritionalInfo.protein_percentage ?? 'N/A';
  
  // Arrays - always safe to iterate
  const ingredients = nutritionalInfo.ingredients || [];
  const allergens = nutritionalInfo.allergens || [];
  
  // Objects - safe to access properties
  const packaging = nutritionalInfo.packaging_info || {};
  const manufacturing = nutritionalInfo.manufacturing_info || {};
  
  return {
    calories,
    protein,
    ingredients,
    allergens,
    packaging,
    manufacturing
  };
}
```

### API Query Examples
```sql
-- Get all products with calories
SELECT name, brand, nutritional_info->>'calories_per_100g' as calories
FROM food_items 
WHERE nutritional_info->>'calories_per_100g' IS NOT NULL;

-- Get products with specific allergens
SELECT name, nutritional_info->'allergens' as allergens
FROM food_items 
WHERE jsonb_array_length(nutritional_info->'allergens') > 0;

-- Get products with high protein
SELECT name, nutritional_info->>'protein_percentage' as protein
FROM food_items 
WHERE (nutritional_info->>'protein_percentage')::float > 25.0;
```

## 🚀 Benefits

### For Frontend Development
- ✅ **No Null Reference Errors** - Every property exists
- ✅ **Consistent Structure** - Same schema across all records
- ✅ **Predictable Data** - Always know what fields are available
- ✅ **Safe Iteration** - Arrays are always arrays, never null
- ✅ **Type Safety** - Clear TypeScript interfaces

### For Database Queries
- ✅ **Reliable Queries** - Properties always exist
- ✅ **Consistent Filtering** - Same field names across all records
- ✅ **Easy Aggregation** - Predictable data structure
- ✅ **Index-Friendly** - Consistent JSONB structure

## 🔧 Data Quality

### Completeness Metrics
- **Total Records**: 11,467
- **Records with Calories**: ~1,500
- **Records with Ingredients**: ~2,500
- **Records with Allergens**: ~800
- **Standardized Structure**: 100% (all records)

### Quality Scores
- `data_quality_score`: 0.0 to 1.0
- Higher scores indicate more complete data
- Based on available nutritional information

## 📚 Related Documentation

- [Database Schema](../database_schemas/01_complete_database_schema.sql)
- [API Endpoints](../routers/)
- [Data Processing Scripts](./README.md)

---

**Last Updated**: January 2025  
**Version**: 1.0  
**Standardized Records**: 11,467
